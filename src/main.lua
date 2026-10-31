--- @file src/main.lua
--- @description Main modit entry file. Parses the mode and boots the engine.

--- @section Initialisation

package.path = "./?.lua;./?/init.lua;" .. package.path

require("src.framework.core.globals_shared")

local MODES = {
    ["--project"] = true,
    ["--headless"] = true
}

local mode = arg[1]
local project_path = arg[2]

if not MODES[mode] then
    log("error", "Unrecognised mode. Usage: --project <path> | --headless <path>")
    return
end

--- @section Headless

if mode == "--headless" then
    if not project_path then
        log("error", "--headless requires a project path")
        return
    end

    local sandbox = require("src.framework.core.sandbox")
    local ServerHost = require("src.framework.network.server_host")
    local command = require("src.framework.core.command")

    log("info", "Launching headless server from: " .. project_path)

    local config, server_require = sandbox.load_server(project_path)
    if not config then
        log("fatal", "Failed to load server", { path = project_path, error = tostring(server_require) })
        return
    end

    local network = type(config.network) == "table" and config.network or {}
    local console
    if network.console ~= false then
        local ok, result = pcall(require, "src.framework.network.server_console")
        if ok then
            console = result
            console.init(nil, config.title or "Modit Server")

            local _log = require("src.framework.core.log")

            for _, entry in ipairs(_log.log_history()) do
                console.print(entry.line, entry.level)
            end

            _log.sink = function(level, _, line)
                console.print(line, level)
            end
        else
            log("warn", "Server console unavailable, using terminal output: " .. tostring(result))
        end
    end

    local host = ServerHost.new({
        require = server_require,
        tick_rate = network.tick_rate,
        crash_log = project_path .. "/server_crash.log",
    })

    --- @section Commands

    command.register_builtins("server", { help = true })

    local function quit()
        log("info", "Shutting down...")
        host:stop()
    end

    command.register_engine({ name = "quit", help = "Stop the server", handler = quit })
    command.register_engine({ name = "exit", help = "Stop the server", handler = quit })

    local started_at = os.time()
    command.register_engine({
        name = "status",
        help = "Show server uptime and tick rate",
        handler = function()
            local up = os.difftime(os.time(), started_at)
            return ("up %dh %dm %ds, %d ticks/s, port %s"):format(
                math.floor(up / 3600), math.floor(up / 60) % 60, up % 60,
                host.tick_rate, tostring(network.port or "?")
            )
        end,
    })

    --- @section Run

    if host:load() then
        host:run({
            should_stop = function()
                if not console then return false end

                local line = console.poll()
                if line then command.run(line) end

                return console.is_closed()
            end,
        })
    end

    host:quit()

    if console then
        require("src.framework.core.log").sink = nil
        console.close()
    end
    os.exit(host.crashed and 1 or 0)
end

--- @section Project

if mode == "--project" then
    if not project_path then
        log("error", "--project requires a project path")
        return
    end

    require("src.framework.core.globals_client")

    local sandbox = require("src.framework.core.sandbox")
    local Window = require("src.framework.renderer.window")
    local command = require("src.framework.core.command")

    log("info", "Launching project from: " .. project_path)

    local config, err = sandbox.load_project(project_path)
    if not config then
        log("fatal", "Failed to load project", { path = project_path, error = tostring(err) })
        return
    end

    local window = Window.new(config)

    local modding = type(config.modding) == "table" and config.modding.enabled == true

    command.register_builtins("client", { help = true, mods = modding })

    local previous_close

    if modding then
        local mods = require("src.framework.core.mods")
        mods.init(config)
        mods.scan()

        local started = false
        window.on_frame = function()
            if not started then
                started = true
                mods.start_all("client")
            end
            mods.poll()
        end

        previous_close = function()
            mods.stop_all()
        end
    end

    window.on_close = function()
        if previous_close then previous_close() end
        if _G.network_registry then _G.network_registry:cleanup() end
    end

    if _G.console then
        _G.console.enabled = config.console and config.console.enabled == true
        _G.console.font = config.console and config.console.font
    end

    window:run()
end