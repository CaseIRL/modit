--- @module core.utils
--- @file src/framework/core/utils.lua
--- @description Shared utility helpers used throughout framework

--- @section Imports

local _ffi = require("ffi")
local _filesystem = require("src.framework.core.filesystem")

--- @section Initialisation

local m = {}

--- @section Colours

m.colour = _ffi.typeof("Color")
m.color = m.colour

--- Resolves input into a raylib Color cdata.
--- @param r_or_tbl number|table|userdata Red value, RGBA table, or existing Color
--- @param g number|nil Green value
--- @param b number|nil Blue value
--- @param a number|nil Alpha value
--- @return userdata Color cdata
function m.resolve_colour(r_or_tbl, g, b, a)
    if type(r_or_tbl) == "table" then
        local c = r_or_tbl
        return m.colour(c[1] or 0, c[2] or 0, c[3] or 0, g or c[4] or 255)
    elseif type(r_or_tbl) == "userdata" or type(r_or_tbl) == "cdata" then
        return r_or_tbl
    else
        return m.colour(r_or_tbl or 255, g or 255, b or 255, a or 255)
    end
end
m.resolve_color = resolve_colour

--- @section Safe Call

--- Calls fn with a traceback on failure.
--- @param name string Label shown in the error
--- @param fn function Function to execute
--- @vararg any Arguments passed to fn
--- @return any ... Whatever fn returns
function m.safe_call(name, fn, ...)
    local function finish(ok, ...)
        if not ok then
            error(("[%s] %s"):format(name, tostring((...))), 0)
        end
        return ...
    end
    return finish(xpcall(fn, debug.traceback, ...))
end

--- @section File Functions

--- Resolves a file path against a search directory.
--- @param path string File path to resolve
--- @param dir string Directory to search within
--- @return string|nil Resolved file path or nil if not found
function m.resolve_path(path, dir)
    if not path then
        return nil
    end

    if _filesystem.file_exists(path) then
        return path
    end

    local cleaned = path:gsub("\\", "/"):gsub("^%./", "")
    local resolved = dir .. "/" .. cleaned

    return _filesystem.file_exists(resolved) and resolved or nil
end

--- @section Tables

--- Prints a table recursively to console.
--- @param t table Table to print
--- @param indent string|nil Current indentation spacing
function m.print_table(t, indent)
    indent = indent or ""
    for k, v in pairs(t) do
        if type(v) == "table" then
            print(indent .. tostring(k) .. ":")
            m.print(v, indent .. "  ")
        else
            print(indent .. tostring(k) .. ": " .. tostring(v))
        end
    end
end

--- Checks if a table contains a specific value recursively.
--- @param tbl table Table to search
--- @param val any Value to look for
--- @return boolean True if found
function m.table_contains(tbl, val)
    for _, v in pairs(tbl) do
        if v == val then
            return true
        elseif type(v) == "table" and m.table_contains(v, val) then
            return true
        end
    end
    return false
end

--- Creates a deep copy of a table.
--- @param orig table Table to copy
--- @return table Deep copy of the table
function m.table_deepcopy(orig)
    if type(orig) ~= "table" then
        return orig
    end
    local copy = {}
    for k, v in pairs(orig) do
        copy[m.table_deepcopy(k)] = m.table_deepcopy(v)
    end
    return setmetatable(copy, m.table_deepcopy(getmetatable(orig)))
end

--- Creates a shallow copy of a table, skipping specified keys.
--- @param src table Source table
--- @param skip table|nil Keys to skip dictionary
--- @return table Shallow copy
function m.shallow_copy(src, skip)
    local out = {}
    for k, v in pairs(src) do
        if not (skip and skip[k]) then 
            out[k] = v 
        end
    end
    return out
end

--- Recursively compares two tables for equality.
--- @param t1 table First table
--- @param t2 table Second table
--- @return boolean True if tables match
function m.compare_tables(t1, t2)
    if t1 == t2 then
        return true
    end
    if type(t1) ~= "table" or type(t2) ~= "table" then
        return false
    end
    for k, v in pairs(t1) do
        if not m.compare_tables(v, t2[k]) then
            return false
        end
    end
    for k in pairs(t2) do
        if t1[k] == nil then
            return false
        end
    end
    return true
end

--- @section Strings

--- Converts a table to a string representation up to a max depth.
--- @param t table Table to convert
--- @param max_depth number|nil Maximum recursion depth
--- @param depth number|nil Current recursion depth
--- @param seen table|nil Cycle detection cache
--- @return string Formatted string
function m.table_to_string(t, max_depth, depth, seen)
    max_depth = max_depth or 3
    depth = depth or 0
    if depth > max_depth then
        return "{...}"
    end

    seen = seen or {}
    if seen[t] then
        return "{cycle}"
    end
    seen[t] = true

    local entries = {}
    for k, v in pairs(t) do
        local value
        if type(v) == "table" then
            value = m.table_to_string(v, max_depth, depth + 1, seen)
        elseif type(v) == "string" then
            value = ('"%s"'):format(v)
        else
            value = tostring(v)
        end
        entries[#entries + 1] = tostring(k) .. "=" .. value
    end

    seen[t] = nil
    return "{" .. table.concat(entries, ", ") .. "}"
end

--- Converts any value or table to a string.
--- @param value any Value to convert
--- @param max_depth number|nil Maximum depth if table
--- @return string String representation
function m.to_string(value, max_depth)
    if type(value) == "table" then
        return m.table_to_string(value, max_depth)
    end
    return tostring(value)
end

return m