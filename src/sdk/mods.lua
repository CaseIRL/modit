--- @module sdk.mods
--- @file src/sdk/mods.lua
--- @description Mod registry and cross-mod exports.
--- @default_realm shared

--- @section Initialisation

local mods = {}
local public_registry = {}
local export_registry = {}

--- @section Helpers

local function pass(provider, name, ok, ...)
    if not ok then
        error(("export '%s.%s' failed: %s"):format(provider, name, tostring((...))), 0)
    end
    return ...
end

--- @section Exports

--- Registers an export function for a mod provider.
--- @access game
--- @param owner string
--- @param name string
--- @param fn function
function mods.set_export(owner, name, fn)
    if type(owner) ~= "string" or owner == "" then
        error("export owner must be a string", 3)
    end

    if type(name) ~= "string" or name == "" then
        error("export name must be a string", 3)
    end

    if type(fn) ~= "function" then
        error("export '" .. name .. "' must be a function", 3)
    end

    export_registry[owner] = export_registry[owner] or {}
    export_registry[owner][name] = fn
end

--- Calls an exported function from a target mod provider.
--- @access mod
--- @param provider string
--- @param name string
--- @param ... any
--- @return any
function mods.call_export(provider, name, ...)
    local provider_exports = export_registry[provider]
    local fn = provider_exports and provider_exports[name]
    if not fn then
        error(("mod '%s' has no export '%s' (not running, or not exported)"):format(tostring(provider), tostring(name)), 0)
    end
    return pass(provider, name, pcall(fn, ...))
end

--- Builds the exports API table proxy for a mod owner.
--- @access game
--- @param owner string
--- @return table
function mods.build_exports_api(owner)
    local function view_of(provider)
        return setmetatable({}, {
            __index = function(_, name)
                return function(...) return mods.call_export(provider, name, ...) end
            end,
        })
    end

    return setmetatable({}, {
        __call = function(_, name, fn) mods.set_export(owner, name, fn) end,
        __index = function(_, provider) return view_of(provider) end,
    })
end

--- Creates a scoped mod environment API table.
--- @access engine
--- @param owner string
--- @return table
function mods.scoped(owner)
    if type(owner) ~= "string" or owner == "" then error("mods.scoped: owner required", 2) end
    return {
        export = function(name, fn) return mods.set_export(owner, name, fn) end,
        exports = mods.build_exports_api(owner),
    }
end

--- @section Mod Registry

--- Sets the global public mod registry table.
--- @access engine
--- @param reg table
function mods.set_registry(reg)
    public_registry = reg
end

--- Returns a sorted list of all registered mods.
--- @access mod
--- @return table
function mods.list()
    local list = {}
    for name, data in pairs(public_registry) do
        list[#list + 1] = {
            name = name,
            version = data.version,
            author = data.author,
            realm = data.realm,
            state = data.state
        }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

--- Checks if a specific mod is currently loaded and started.
--- @access mod
--- @param name string
--- @return boolean
function mods.is_loaded(name)
    local mod = public_registry[name]
    return mod ~= nil and mod.state == "started"
end

--- Removes all exports belonging to a specific mod owner.
--- @access engine
--- @param owner string
function mods.remove_owner(owner)
    export_registry[owner] = nil
end

return mods