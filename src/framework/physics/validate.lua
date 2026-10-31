--- @module validate
--- @file src/framework/physics/validate.lua
--- @description Argument checks for the physics API. Everything that reaches native code passes through here.

--- @section Constants

local MAX_COORD = 1e5

--- @section Initialisation

local m = {}

--- @section Helpers

--- Raises a physics error. Level 0 keeps the message clean, the argument name says what was wrong.
--- @param message string
local function fail(message)
    error("physics: " .. message, 0)
end

--- True for real, finite numbers (rejects nan, inf and non-numbers)
--- @param value any
--- @return boolean
local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

m.fail = fail

--- @section Scalars

--- Errors unless the value is a finite number
--- @param value any
--- @param name string Argument name for the message
--- @return number value
function m.number(value, name)
    if not finite(value) then fail(name .. " must be a finite number") end
    return value
end

--- Errors unless the value is a finite number inside the supported world range
--- @param value any
--- @param name string
--- @return number value
function m.coord(value, name)
    if not finite(value) then fail(name .. " must be a finite number") end
    if value > MAX_COORD or value < -MAX_COORD then
        fail(name .. " is outside the supported range of +-" .. MAX_COORD)
    end
    return value
end

--- Errors unless the value is a finite number above zero
--- @param value any
--- @param name string
--- @return number value
function m.positive(value, name)
    if not finite(value) or value <= 0 then fail(name .. " must be a number above 0") end
    return value
end

--- Like number, but nil passes through
--- @param value any
--- @param name string
--- @return number|nil value
function m.optional_number(value, name)
    if value == nil then return nil end
    return m.number(value, name)
end

--- @section Tables

--- Returns the config table, an empty one when omitted, and errors on anything else
--- @param value any
--- @param name string
--- @return table config
function m.config(value, name)
    if value == nil then return {} end
    if type(value) ~= "table" then fail(name .. " must be a table") end
    return value
end

--- Reads x, y, z from a table with named or array fields. Missing fields are 0, nil gives 0, 0, 0
--- @param source table|nil { x, y, z } or { x, y, z } as an array
--- @param name string
--- @return number x
--- @return number y
--- @return number z
function m.vec(source, name)
    if source == nil then return 0, 0, 0 end
    if type(source) ~= "table" then fail(name .. " must be a table with x, y, z") end

    return m.coord(source.x or source[1] or 0, name .. ".x"),
        m.coord(source.y or source[2] or 0, name .. ".y"),
        m.coord(source.z or source[3] or 0, name .. ".z")
end

--- Reads a position from a config: `position = {x,y,z}` or plain x, y, z fields
--- @param config table
--- @return number x
--- @return number y
--- @return number z
function m.position(config)
    if config.position ~= nil then return m.vec(config.position, "position") end
    return m.coord(config.x or 0, "x"), m.coord(config.y or 0, "y"), m.coord(config.z or 0, "z")
end

--- Reads a size: a number (uniform) or a table, every component above zero
--- @param source number|table|nil
--- @param name string
--- @param default number Used when omitted
--- @return number x
--- @return number y
--- @return number z
function m.size(source, name, default)
    if source == nil then return default, default, default end

    if type(source) == "number" then
        m.positive(source, name)
        return source, source, source
    end

    if type(source) ~= "table" then fail(name .. " must be a number or a table with x, y, z") end

    return m.positive(source.x or source[1] or default, name .. ".x"),
        m.positive(source.y or source[2] or default, name .. ".y"),
        m.positive(source.z or source[3] or default, name .. ".z")
end

--- Reads euler angles in degrees from { pitch, yaw, roll } (named or array)
--- @param source table
--- @param name string
--- @return number pitch
--- @return number yaw
--- @return number roll
function m.euler(source, name)
    if type(source) ~= "table" then fail(name .. " must be a table { pitch, yaw, roll } in degrees") end

    return m.number(source.pitch or source[1] or 0, name .. ".pitch"), m.number(source.yaw or source[2] or 0, name .. ".yaw"), m.number(source.roll or source[3] or 0, name .. ".roll")
end

--- Reads and normalises a quaternion { x, y, z, w } (named or array)
--- @param source table
--- @param name string
--- @return number x
--- @return number y
--- @return number z
--- @return number w
function m.quat(source, name)
    if type(source) ~= "table" then fail(name .. " must be a table with x, y, z, w") end

    local x = m.number(source.x or source[1] or 0, name .. ".x")
    local y = m.number(source.y or source[2] or 0, name .. ".y")
    local z = m.number(source.z or source[3] or 0, name .. ".z")
    local w = m.number(source.w or source[4] or 1, name .. ".w")

    local length = math.sqrt(x * x + y * y + z * z + w * w)
    if length < 1e-6 then fail(name .. " must not be zero") end
    return x / length, y / length, z / length, w / length
end

return m