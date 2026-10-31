--- @module serializer
--- @file src/framework/network/serializer.lua
--- @description Small safe binary serializer for network messages. Never executes Lua code.

--- @section Imports

local _ffi = require("ffi")
local _bit = require("bit")

--- @section Constants

local MAX_SIZE = 1024 * 1024 -- 1 MB
local MAX_DEPTH = 16
local MAX_ITEMS = 4096

local TYPE_NIL = 0
local TYPE_BOOL = 1
local TYPE_NUMBER = 2
local TYPE_STRING = 3
local TYPE_TABLE = 4

--- @section Initialisation

local m = {}

--- @section Helpers

local function u32(n)
    return string.char(
        _bit.band(n, 0xFF),
        _bit.band(_bit.rshift(n, 8), 0xFF),
        _bit.band(_bit.rshift(n, 16), 0xFF),
        _bit.band(_bit.rshift(n, 24), 0xFF)
    )
end

local function read_u32(data, pos)
    if pos + 3 > #data then
        return nil, "unexpected end of data"
    end

    local a, b, c, d = data:byte(pos, pos + 3)

    return a + b * 256 + c * 65536 + d * 16777216, pos + 4
end

local function encode_number(value)
    local box = _ffi.new("double[1]", value)
    return _ffi.string(_ffi.cast("char*", box), 8)
end

local function decode_number(data, pos)
    if pos + 7 > #data then
        return nil, nil, "unexpected end of number"
    end

    local box = _ffi.new("double[1]")
    _ffi.copy(box, data:sub(pos, pos + 7), 8)

    return box[0], pos + 8
end

local function encode_value(value, depth, output)
    if depth > MAX_DEPTH then
        return nil, "maximum table depth exceeded"
    end

    local value_type = type(value)

    if value == nil then
        output[#output + 1] = string.char(TYPE_NIL)
        return true
    end

    if value_type == "boolean" then
        output[#output + 1] = string.char(TYPE_BOOL, value and 1 or 0)
        return true
    end

    if value_type == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return nil, "invalid number"
        end

        output[#output + 1] = string.char(TYPE_NUMBER)
        output[#output + 1] = encode_number(value)
        return true
    end

    if value_type == "string" then
        if #value > MAX_SIZE then
            return nil, "string exceeds maximum size"
        end

        output[#output + 1] = string.char(TYPE_STRING)
        output[#output + 1] = u32(#value)
        output[#output + 1] = value
        return true
    end

    if value_type == "table" then
        local count = 0

        for _ in pairs(value) do
            count = count + 1

            if count > MAX_ITEMS then
                return nil, "table exceeds maximum item count"
            end
        end

        output[#output + 1] = string.char(TYPE_TABLE)
        output[#output + 1] = u32(count)

        for key, item in pairs(value) do
            if (type(key) ~= "string" and type(key) ~= "number") or key ~= key then
                return nil, "invalid table key"
            end

            local ok, err = encode_value(key, depth + 1, output)
            if not ok then return nil, err end

            ok, err = encode_value(item, depth + 1, output)
            if not ok then return nil, err end
        end

        return true
    end

    return nil, "unsupported value type: " .. value_type
end

local function decode_value(data, pos, depth)
    if depth > MAX_DEPTH then
        return nil, nil, "maximum table depth exceeded"
    end

    if pos > #data then
        return nil, nil, "unexpected end of data"
    end

    local value_type = data:byte(pos)
    pos = pos + 1

    if value_type == TYPE_NIL then
        return nil, pos
    end

    if value_type == TYPE_BOOL then
        if pos > #data then
            return nil, nil, "unexpected end of boolean"
        end

        local value = data:byte(pos)
        if value ~= 0 and value ~= 1 then
            return nil, nil, "invalid boolean"
        end

        return value == 1, pos + 1
    end

    if value_type == TYPE_NUMBER then
        return decode_number(data, pos)
    end

    if value_type == TYPE_STRING then
        local length, next_pos = read_u32(data, pos)
        if not length then
            return nil, nil, next_pos
        end

        if length > MAX_SIZE then
            return nil, nil, "string exceeds maximum size"
        end

        if next_pos + length - 1 > #data then
            return nil, nil, "unexpected end of string"
        end

        return data:sub(next_pos, next_pos + length - 1), next_pos + length
    end

    if value_type == TYPE_TABLE then
        local count, next_pos = read_u32(data, pos)
        if not count then
            return nil, nil, next_pos
        end

        if count > MAX_ITEMS then
            return nil, nil, "table exceeds maximum item count"
        end

        local result = {}

        for _ = 1, count do
            local key, after_key, err = decode_value(data, next_pos, depth + 1)
            if err then return nil, nil, err end

            if (type(key) ~= "string" and type(key) ~= "number") or key ~= key then
                return nil, nil, "invalid table key"
            end

            local value, after_value
            value, after_value, err = decode_value(data, after_key, depth + 1)
            if err then return nil, nil, err end

            result[key] = value
            next_pos = after_value
        end

        return result, next_pos
    end

    return nil, nil, "unknown value type: " .. tostring(value_type)
end

--- @section Functions

--- Serializes a Lua value
--- @param value any Value to serialize
--- @return string|nil data Encoded bytes, or nil on failure
--- @return string|nil error Reason for failure
function m.encode(value)
    local output = {}

    local ok, err = encode_value(value, 0, output)
    if not ok then
        return nil, err
    end

    local data = table.concat(output)

    if #data > MAX_SIZE then
        return nil, "encoded value exceeds maximum size"
    end

    return data
end

--- Deserializes a Lua value
--- @param data string Encoded bytes
--- @return any|nil value Decoded value, or nil on failure
--- @return string|nil error Reason for failure
function m.decode(data)
    if type(data) ~= "string" then
        return nil, "data must be a string"
    end

    if #data > MAX_SIZE then
        return nil, "data exceeds maximum size"
    end

    local value, pos, err = decode_value(data, 1, 0)

    if err then
        return nil, err
    end

    if pos ~= #data + 1 then
        return nil, "trailing data"
    end

    return value
end

return m