--- @module scenes
--- @file src/engine/scenes.lua
--- @description Handles adding/removing and switching scenes.
--- @class Scenes

--- @section Initialisation

local _utils = require("src.engine.core.utils")

local Scenes = {}
Scenes.__index = Scenes

--- @section Factory

--- Creates a new scene manager.
--- @param window table|nil The window that owns it, scenes can reach it as self.manager.window
--- @return table
function Scenes.new(window)
    local self = setmetatable({}, Scenes)

    self.window = window
    self.list = {}
    self.current = nil
    self.current_name = nil

    return self
end

--- @section Methods

--- Adds a scene by module path or direct table instance.
--- @param name string Unique name for the scene
--- @param scene_or_path string|table Path to require or scene table
function Scenes:add(name, scene_or_path)
    local scene = scene_or_path

    if type(scene_or_path) == "string" then
        local loaded_module = nil
        _utils.safe_call("Scene:Load:" .. name, function()
            loaded_module = require(scene_or_path)
        end)
        scene = loaded_module
    end

    if type(scene) ~= "table" then
        error("scene '" .. tostring(name) .. "' must be a table, got " .. type(scene) .. " (does its file return it?)", 2)
    end

    self.list[name] = scene
end

--- Unloads the current scene and loads a new one.
--- @param target string|table Scene name, or a scene table
--- @param data table|nil Passed to the new scene's load function
function Scenes:switch(target, data)
    local scene = target

    if type(target) == "string" then
        scene = self.list[target]
        if not scene then
            error("scene '" .. target .. "' not found", 2)
        end
    end

    self:unload()

    scene.manager = self
    self.current = scene
    self.current_name = type(target) == "string" and target or "unnamed"

    log("debug", "Scene loaded", { name = self.current_name })

    if scene.load then
        scene:load(data)
    end
end

--- Unloads the current scene and leaves none running.
function Scenes:unload()
    local scene = self.current
    if not scene then
        return
    end

    self.current = nil
    log("debug", "Scene unloaded", { name = self.current_name })
    self.current_name = nil

    if scene.unload then
        scene:unload()
    end
end

--- Updates the current scene.
--- @param dt number Seconds since the last frame
function Scenes:update(dt)
    local scene = self.current
    if scene and scene.update then
        scene:update(dt)
    end
end

--- Draws the current scene.
function Scenes:draw()
    local scene = self.current
    if scene and scene.draw then
        scene:draw()
    end
end

return Scenes