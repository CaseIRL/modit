--- @module command
--- @file src/sdk/shared/command.lua
--- @description Console command registry with engine, game, and mod layers, pure options-table support, and built-ins.

--- @section Initialisation

local m = {}
local registry = {} -- name -> { fn, help, args, layer, owner }

--- @section Helpers

local function describe(command)
    if command.layer == "mod" then return "mod " .. command.owner end
    return command.layer
end

local function add(layer, owner, opts)
    if type(opts) ~= "table" then error("command configuration must be a table", 3) end
    local name = opts.name
    local handler = opts.handler or opts.fn

    -- Allow letters, numbers, underscores, hyphens, and colons (e.g., rig:kill)
    if type(name) ~= "string" or not name:match("^[%w_%-%:]+$") then error("invalid command name", 3) end
    if type(handler) ~= "function" then error("command handler must be a function", 3) end
    name = name:lower()

    local existing = registry[name]
    if existing and (existing.layer ~= layer or existing.owner ~= owner) then
        error(("command '%s' already exists (%s)"):format(name, describe(existing)), 3)
    end

    registry[name] = { 
        fn = handler, 
        help = opts.help or "", 
        args = opts.args or {}, 
        layer = layer, 
        owner = owner 
    }
end

--- @section Functions

--- Registers an engine builtin using an options table. Only engine code should call this
--- @param opts table Command configuration table { name, handler, help, args }
function m.register_engine(opts)
    add("engine", nil, opts)
end

--- Registers a game command (no owner) or a mod command (owner = mod name) using an options table
--- @param opts table Command configuration table { name, handler, help, args }
--- @param owner string|nil Mod name. Leave nil for game command
function m.register(opts, owner)
    add(owner and "mod" or "game", owner, opts)
end

--- Removes every command registered by a mod. Engine and game command are never touched
--- @param owner string Mod name
function m.remove_owner(owner)
    if owner == nil then return end
    for name, command in pairs(registry) do
        if command.layer == "mod" and command.owner == owner then registry[name] = nil end
    end
end

--- Parses and runs one line of input
--- @param line string Raw text, for example "restart default_world"
function m.run(line)
    local args = {}
    for word in line:gmatch("%S+") do args[#args + 1] = word end
    if #args == 0 then return end

    local name = table.remove(args, 1):lower()
    local command = registry[name]
    if not command then
        log("warn", "unknown command '" .. name .. "' (try 'help')")
        return
    end

    local ok, result = pcall(command.fn, args)
    if not ok then
        log("error", "command '" .. name .. "' failed: " .. tostring(result))
    elseif result ~= nil then
        log("info", tostring(result))
    end
end

--- Returns list of registered command
--- @return table list Sorted array of { name, help, args, layer, owner }
function m.list()
    local list = {}
    for name, command in pairs(registry) do
        list[#list + 1] = { 
            name = name, 
            help = command.help, 
            args = command.args, 
            layer = command.layer, 
            owner = command.owner 
        }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

--- @section Built-ins Registration

local function print_section(title, items)
    if #items == 0 then return end
    log("info", title)
    for _, command in ipairs(items) do
        local usage = command.name
        if command.args and #command.args > 0 then
            for _, p in ipairs(command.args) do
                usage = usage .. " [" .. p.name .. "]"
            end
        end
        log("info", ("  %-20s %s"):format(usage, command.help))
    end
end

--- Registers built-in command conditionally based on configuration
--- @param realm string "client" or "server"
--- @param opts table|nil { help = true, mods = true } configuration flags
function m.register_builtins(realm, opts)
    opts = opts or {}
    
    -- Standard help command (enabled by default)
    if opts.help ~= false then
        m.register_engine({
            name = "help",
            help = "List command",
            handler = function()
                local engine, game, by_mod, mod_names = {}, {}, {}, {}

                for _, command in ipairs(m.list()) do
                    if command.layer == "engine" then
                        engine[#engine + 1] = command
                    elseif command.layer == "game" then
                        game[#game + 1] = command
                    else
                        if not by_mod[command.owner] then
                            by_mod[command.owner] = {}
                            mod_names[#mod_names + 1] = command.owner
                        end
                        local items = by_mod[command.owner]
                        items[#items + 1] = command
                    end
                end

                table.sort(mod_names)

                print_section("Engine", engine)
                print_section("Game", game)
                for _, name in ipairs(mod_names) do print_section("Mod: " .. name, by_mod[name]) end
            end
        })
    end

    -- Mod management engine command (opt-in if modding is supported)
    if opts.mods == true then
        local _mods = require("src.framework.core.mods")
        local _public = require("src.sdk.mods")

        m.register_engine({
            name = "mods",
            help = "List mods",
            handler = function()
                for _, info in ipairs(_public.list()) do
                    log("info", ("%-16s %-8s %s"):format(info.name, info.state, info.version or ""))
                end
            end
        })

        m.register_engine({
            name = "refresh",
            help = "Rescan the mods folder",
            handler = function()
                _mods.scan()
            end
        })

        m.register_engine({
            name = "start",
            help = "Start a mod",
            args = { { name = "mod", help = "Mod name" } },
            handler = function(args)
                if not args[1] then return "usage: start <mod>" end
                local ok, err = _mods.start(args[1], realm)
                if not ok then return err end
            end
        })

        m.register_engine({
            name = "stop",
            help = "Stop a mod",
            args = { { name = "mod", help = "Mod name" } },
            handler = function(args)
                if not args[1] then return "usage: stop <mod>" end
                _mods.stop(args[1])
            end
        })

        m.register_engine({
            name = "restart",
            help = "Restart a mod",
            args = { { name = "mod", help = "Mod name" } },
            handler = function(args)
                if not args[1] then return "usage: restart <mod>" end
                local ok, err = _mods.restart(args[1])
                if not ok then return err end
            end
        })
    end
end

return m