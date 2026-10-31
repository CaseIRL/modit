--- @class Scenes
--- @file src/framework/core/scenes.lua
--- @description Handles scene creation, switching loading etc.

--- @section Imports

local _utils = require("src.framework.core.utils")

--- @section Constructor

local Scenes = {}
Scenes.__index = Scenes

--- Creates a new scene manager.
--- @param window table|nil The window that owns it, scenes can reach it as self.manager.window
--- @return table Scenes instance
function Scenes.new(window)
    local self = setmetatable({}, Scenes)

    self.window = window
    self.list = {}
    self.current = nil
    self.current_name = nil

    log("debug", "Scene manager initialized")
    return self
end

--- @section Methods

--- Adds a scene by module path or direct table instance.
--- @param name string Unique name for the scene
--- @param scene_or_path string|table Path to require or scene table
function Scenes:add(name, scene_or_path)
    local scene = scene_or_path

    if type(scene_or_path) == "string" then
        log("debug", "Requiring scene module from path", { name = name, path = scene_or_path })
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
    log("info", "Scene registered successfully", { name = name })
end

--- Unloads the current scene and loads a new one.
--- @param target string|table Scene name, or a scene table
--- @param data table|nil Passed to the new scene's load function
function Scenes:switch(target, data)
    local target_name = type(target) == "string" and target or "unnamed_instance"
    log("info", "Initiating scene switch", { target = target_name })

    local scene = target

    if type(target) == "string" then
        scene = self.list[target]
        if not scene then
            error("scene '" .. target .. "' not found", 2)
        end
    end

    self:unload()

    self.current = scene
    self.current_name = target_name
    scene.manager = self

    if _G.render_list then _G.render_list:set_active_scene(self.current_name) end
    if _G.shapes_registry then _G.shapes_registry:set_active_scene(self.current_name) end
    if _G.text_registry then _G.text_registry:set_active_scene(self.current_name) end
    if _G.image_registry then _G.image_registry:set_active_scene(self.current_name) end
    if _G.model_registry then _G.model_registry:set_active_scene(self.current_name) end
    if _G.physics_registry then _G.physics_registry:set_active_scene(self.current_name) end

    log("debug", "Scene context loaded", { name = self.current_name })

    if scene.load then
        log("debug", "Executing scene load hook", { name = self.current_name })
        scene:load(data)
    end
end

--- Unloads the current scene.
function Scenes:unload()
    local scene = self.current
    if not scene then
        return
    end

    log("info", "Unloading active scene", { name = self.current_name })

    if scene.unload then
        log("debug", "Executing scene unload hook", { name = self.current_name })
        scene:unload()
    end

    if self.current_name and _G.text_registry then _G.text_registry:clear_scene(self.current_name) end
    if self.current_name and _G.shapes_registry then _G.shapes_registry:clear_scene(self.current_name) end
    if self.current_name and _G.image_registry then _G.image_registry:clear_scene(self.current_name) end
    if self.current_name and _G.model_registry then _G.model_registry:clear_scene(self.current_name) end
    if self.current_name and _G.physics_registry then _G.physics_registry:clear_scene(self.current_name) end -- <-- ADDED
    if self.current_name and _G.render_list then _G.render_list:clear(self.current_name) end

    if _G.environment then
        _G.environment:reset()
    end

    self.current = nil
    log("debug", "Scene fully unloaded", { previous_name = self.current_name })
    self.current_name = nil
end

--- Updates the current scene.
--- @param dt number Seconds since the last frame
function Scenes:update(dt)
    local scene = self.current
    if scene then
        if _G.physics_registry then
            _G.physics_registry:update(dt) -- <-- ADDED: Step the physics simulation every frame!
        end

        if self.current_name and _G.shapes_registry then
            _G.shapes_registry:update(dt, self.current_name)
        end

        if self.current_name and _G.image_registry then
            _G.image_registry:update(dt, self.current_name)
        end

        if self.current_name and _G.model_registry then
            _G.model_registry:update(dt, self.current_name)
        end

        if scene.update then
            scene:update(dt)
        end
    end
end

--- Draws the current scene.
function Scenes:frame()
    local scene = self.current
    if scene then
        if scene.frame then
            scene:frame()
        end
        
        if self.current_name and _G.render_list then
            _G.render_list:draw(self.current_name)
        end
    end
end

return Scenes