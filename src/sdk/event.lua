--- @module sdk.event
--- @file src/sdk/event.lua
--- @description Public event api.
--- @default_realm shared
--- @default_access game

--- @section Imports

local _log = require("src.core.log")
local _utils = require("src.core.utils")

--- @section Initialisation

local event = {}

local registered = {}
local available = {}
local registrants = {}
local firing = 0
local needs_compact = false

--- @section Helpers

local function compact_list(list)
    local write = 0
    for read = 1, #list do
        local entry = list[read]
        if not entry.dead then
            write = write + 1
            list[write] = entry
        end
    end
    for index = #list, write + 1, -1 do
        list[index] = nil
    end
end

local function compact_all()
    for _, list in pairs(registered) do
        compact_list(list)
    end
    needs_compact = false
end

--- @section Functions

--- Registers a new available event type.
--- @param name string Event identifier
--- @param description string|nil Optional description
--- @param owner string|nil Owner namespace
function event.register(name, description, owner)
    if type(name) ~= "string" then error("event name must be a string", 2) end
    available[name] = description or ""
    registered[name] = registered[name] or {}
    if owner ~= nil then
        registrants[name] = owner
    end
    _log.debug("[event] registered: " + name)
end

--- Subscribes a callback function to an event.
--- @param name string Event identifier
--- @param callback function Callback handler
--- @param owner string|nil Optional owner namespace
--- @return function Callback handler
function event.listen(name, callback, owner)
    if type(name) ~= "string" then error("event name must be a string", 2) end
    if type(callback) ~= "function" then error("event callback must be a function", 2) end

    local list = registered[name]
    if not list then
        list = {}
        registered[name] = list
    end
    list[#list + 1] = { fn = callback, owner = owner }
    _log.debug(("[event] listener added: %s%s"):format(name, owner and (" (" .. owner .. ")") or ""))
    return callback
end

--- Fires an event, invoking all registered listener callbacks.
--- @param name string Event identifier
--- @param ... any Arguments passed to listeners
function event.fire(name, ...)
    local list = registered[name]
    if not list then return end

    firing = firing + 1
    for index = 1, #list do
        local entry = list[index]
        if not entry.dead then
            local ok, err = xpcall(entry.fn, debug.traceback, ...)
            if not ok then
                entry.dead = true
                needs_compact = true
                _log.print("error", ("[event] '%s' listener%s removed after error:\n%s"):format(name, entry.owner and (" from " .. entry.owner) or "", tostring(err)))
            end
        end
    end
    firing = firing - 1

    if firing == 0 and needs_compact then
        compact_all()
    end
end

--- Unsubscribes a callback function from an event.
--- @param name string Event identifier
--- @param callback function Callback handler
--- @param owner string|nil Optional owner namespace
function event.unlisten(name, callback, owner)
    local list = registered[name]
    if not list then return end

    for _, entry in ipairs(list) do
        if entry.fn == callback and not entry.dead and (owner == nil or entry.owner == owner) then
            entry.dead = true
            if firing == 0 then compact_list(list) else needs_compact = true end
            _log.debug("[event] listener removed: " + name)
            return
        end
    end
end

--- Removes all listeners registered by a specific owner.
--- @param owner string Owner namespace
function event.remove_owner(owner)
    for _, list in pairs(registered) do
        for _, entry in ipairs(list) do
            if entry.owner == owner then entry.dead = true end
        end
    end
    if firing == 0 then compact_all() else needs_compact = true end
end

--- Clears all listeners for a specific event.
--- @param name string Event identifier
function event.clear(name)
    local list = registered[name]
    if not list then return end
    for _, entry in ipairs(list) do entry.dead = true end
    if firing == 0 then compact_list(list) else needs_compact = true end
end

--- Lists all available registered event names.
--- @return table Array of event names
function event.list()
    local names = {}
    for name in pairs(available) do names[#names + 1] = name end
    table.sort(names)
    return names
end

--- @section Scoped

--- Creates a namespaced event API bound to a specific owner.
--- @param owner string Owner namespace
--- @return table Scoped event API
function event.scoped(owner)
    if type(owner) ~= "string" or owner == "" then
        error("event.scoped: owner must be a non-empty string", 2)
    end
    if owner:find(".", 1, true) then
        error("event.scoped: owner must not contain '.'", 2)
    end

    local prefix = owner .. "."
    local api = {}

    function api.register(name, description)
        if type(name) ~= "string" or name:sub(1, #prefix) ~= prefix then
            error(("event '%s' must be namespaced '%s<name>'"):format(tostring(name), prefix), 2)
        end
        return event.register(name, description, owner)
    end

    function api.listen(name, callback)
        return event.listen(name, callback, owner)
    end

    function api.unlisten(name, callback)
        return event.unlisten(name, callback, owner)
    end

    function api.fire(name, ...)
        if registrants[name] ~= owner then
            error(("'%s' can only fire events it registered ('%s')"):format(owner, tostring(name)), 2)
        end
        return event.fire(name, ...)
    end

    api.list = event.list

    return api
end

return event