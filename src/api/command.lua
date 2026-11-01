--- @module api.command
--- @file src/api/command.lua
--- @description Console commands. Games register their own, mods register scoped to their name.
--- @default_access engine
--- @default_realm shared

--- @section Initialisation

local _command = require("src.framework.core.command")
local m = {}

--- @section Registration

--- Registers a game command using an options table. Mods get their own scoped version of this automatically.
--- @access game
--- @param opts table Command options table { name, handler, help, args }
function m.register(opts)
    _command.register(opts)
end

--- Builds the version of register a mod sees, with its name filled in.
--- @access engine
--- @param owner string Mod name
--- @return table
function m.scoped(owner)
    return {
        register = function(opts)
            _command.register(opts, owner)
        end,
    }
end

--- @section Ownership

--- Removes every command a mod registered.
--- @access engine
--- @param owner string Mod name
function m.remove_owner(owner)
    _command.remove_owner(owner)
end

return m