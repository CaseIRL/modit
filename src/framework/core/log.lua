--- @module log
--- @file src/framework/core/log.lua
--- @description Color-coded logging subsystem with ANSI formatting.

--- @section Constants & State

local LOG_LEVELS = { "debug", "info", "success", "warn", "error", "fatal" }
local LEVEL_INDEX = {}
for i, level in ipairs(LOG_LEVELS) do
    LEVEL_INDEX[level] = i
end

local HISTORY_BUFFER = {}
local HISTORY_MAX_CAPACITY = 100

--- @section Initialization

local m = { sink = nil }

local min_level_index = LEVEL_INDEX.debug
local enable_color = true
local cached_palette = nil

--- @section Helpers

--- Retrieves or initializes the ANSI color palette.
--- @return table Palette mapping log levels to ANSI escape codes
local function get_palette()
    if cached_palette then
        return cached_palette
    end

    if enable_color then
        cached_palette = {
            debug = "\27[35m",
            info = "\27[36m",
            success = "\27[32m",
            warn = "\27[33m",
            error = "\27[31m",
            fatal = "\27[1;31m",
            reset = "\27[0m",
        }
    else
        cached_palette = setmetatable({}, {
            __index = function()
                return ""
            end,
        })
    end

    return cached_palette
end

--- Recursively converts a table to a string representation.
--- @param t table Table to serialize
--- @param depth number|nil Current recursion depth
--- @param seen table|nil Cycle detection table
--- @return string Formatted string representation
local function table_to_string(t, depth, seen)
    depth = depth or 0
    if depth > 3 then
        return "{…}"
    end

    seen = seen or {}
    if seen[t] then
        return "{cycle}"
    end
    seen[t] = true

    local entries = {}
    for k, v in pairs(t) do
        local formatted_val
        if type(v) == "table" then
            formatted_val = table_to_string(v, depth + 1, seen)
        else
            formatted_val = type(v) == "string" and ('"' .. v .. '"') or tostring(v)
        end
        entries[#entries + 1] = tostring(k) .. "=" .. formatted_val
    end

    return "{" .. table.concat(entries, ", ") .. "}"
end

--- Serializes any value into a string.
--- @param value any Value to serialize
--- @return string Serialized string
local function serialize(value)
    return type(value) == "table" and table_to_string(value) or tostring(value)
end

--- Internal function to format and print a log message.
--- @param level string Log level name
--- @param msg string Main message
--- @param data any|nil Optional data object/table
--- @return boolean True if logged successfully
local function print_log(level, msg, data)
    local level_idx = LEVEL_INDEX[level]
    if not level_idx then
        level, level_idx = "info", LEVEL_INDEX.info
    end

    if level_idx < min_level_index then
        return false
    end

    local text = tostring(msg)
    if data ~= nil then
        text = text .. " " .. serialize(data)
    end

    local line = ("[%s] [%s]: %s"):format(os.date("%H:%M:%S"), level:upper(), text)

    local palette = get_palette()
    io.write(palette[level], line, palette.reset, "\n")

    HISTORY_BUFFER[#HISTORY_BUFFER + 1] = { level = level, text = text, line = line }
    if #HISTORY_BUFFER > HISTORY_MAX_CAPACITY then
        table.remove(HISTORY_BUFFER, 1)
    end

    if m.sink then
        m.sink(level, text, line)
    end

    if level == "fatal" then
        os.exit(1)
    end

    return true
end

--- @section Functions

--- Retrieves the log history buffer.
--- @return table Array of recent log entries
function m.log_history()
    return HISTORY_BUFFER
end

--- Logs a message with a given level.
--- @param level string Log level (debug, info, success, warn, error, fatal)
--- @param msg string Message to log
--- @param data any|nil Optional extra data or table
--- @return boolean True if logged successfully
function m.print(level, msg, data)
    return print_log(level, msg, data)
end

--- Returns a logger that prefixes every message with a scope name.
--- @param scope string
--- @return table Logger with one function per level (debug, info, success, warn, error, fatal)
function m.scoped(scope)
    local prefix = "[" .. scope .. "] "
    local logger = {}

    for _, level in ipairs(LOG_LEVELS) do
        logger[level] = function(msg, data)
            return print_log(level, prefix .. tostring(msg), data)
        end
    end

    return logger
end

return m