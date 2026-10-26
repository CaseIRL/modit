--- @file src/main.lua
--- @description Main modit entry file. Parses the mode and boots the engine.

--- @section Initialisation

package.path = "./?.lua;./?/init.lua;" .. package.path

require("src.core.globals")

local MODES = {
    ["--project"] = true,
    ["--headless"] = true
}

local mode = arg[1]
local project_path = arg[2]

if not MODES[mode] then
    log("error", "Unrecognised mode. Usage: --project <path> | --headless")
    return
end

--- @section Headless

if mode == "--headless" then
    log("info", "Stub headless runner not setup yet")
    return
end

--- @section Project

if mode == "--project" then
    if not project_path then
        log("error", "--project requires a project path")
        return
    end

    local sandbox = require("src.core.sandbox")
    local Window = require("src.renderer.window")

    log("info", "Launching project from: " .. project_path)

    local config, err = sandbox.load_project(project_path)
    if not config then
        log("fatal", "Failed to load project", { path = project_path, error = tostring(err) })
        return
    end

    Window.new(config):run()
end