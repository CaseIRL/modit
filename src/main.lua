--- @file src/main.lua
--- @description Main modit entry file.

--- @section Initialisation

package.path = "./?.lua;./?/init.lua;" .. package.path

require("src.engine.core.globals")

local MODES = {
    ["--editor"] = true,
    ["--game"] = true,
    ["--headless"] = true
}

local mode = arg[1] or "--editor"
local project_path = arg[2] or "."

if not MODES[mode] then
    log("error", "Unrecognised mode. Allowed: [editor | game | headless]")
    return
end

--- @section Editor

if mode == "--editor" then
    local engine = require("src.engine")
    local config = require("src.editor.config")
    config.root = config.root or "."
    engine.run("editor", config)
    return
end

--- @section Headless

if mode == "--headless" then
    log("info", "Stub headless runner not setup yet")
    return
end

--- @section Game

if mode == "--game" then
    local engine = require("src.engine")

    local config_file = project_path .. "/config.lua"
    
    local chunk, err = loadfile(config_file)
    if not chunk then
        log("error", "Failed to load game config from '" .. config_file .. "': " .. tostring(err))
        return
    end

    local ok, config = pcall(chunk)
    if not ok or type(config) ~= "table" then
        log("error", "Game config at '" .. config_file .. "' must return a valid table. Error: " .. tostring(config))
        return
    end

    config.root = project_path

    log("info", "Launching game project from: " .. project_path)
    engine.run("game", config)
    return
end