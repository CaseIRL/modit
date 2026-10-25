--- @module engine
--- @file src/engine/init.lua
--- @description Main engine initialisation file.

--- @section Initalisation

local m = {}

--- @section Helpers

--- Sandboxes and pre-loads project scenes.
--- @param config table Engine configuration table containing scene mappings and root path
--- @return boolean True if sandboxing and scene loading succeeded
local function sandbox_scenes(config)
    local sandbox = require("src.engine.core.sandbox")

    local env, err = sandbox.create_env("client", "game", config, { root = config.root })
    if not env then
        log("fatal", "Failed to create game sandbox", { error = tostring(err) })
        return false
    end

    for name, path in pairs(config.scenes or {}) do
        if type(path) == "string" then
            local ok, scene = pcall(env.require, path)
            if not ok then
                log("fatal", "Failed to load scene", { scene = name, path = path, error = tostring(scene) })
                return false
            end
            config.scenes[name] = scene
        end
    end
    return true
end

--- @section Runner

--- Boots the engine loop with the specified mode and configuration.
--- @param mode string Execution mode ("editor", "game", "headless")
--- @param window table Window and engine configuration table
function m.run(mode, window)
    local Window = require("src.engine.render.window")

    log("info", "Starting engine", { mode = mode })

    if mode == "game" and not sandbox_scenes(window) then
        return
    end

    Window.new(window):run()
end

return m