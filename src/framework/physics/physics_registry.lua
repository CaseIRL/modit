--- @class PhysicsRegistry
--- @file src/framework/physics/physics_registry.lua
--- @description Owns physics worlds per scene, steps the active scene's worlds every frame and destroys them when
--- the scene unloads. Same role as the model, text and shapes registries.

--- @section Imports

local World = require("src.framework.physics.physics_world")

--- @section Constants

local GLOBAL_SCENE = "_global"

--- @section Initialisation

local PhysicsRegistry = {}
PhysicsRegistry.__index = PhysicsRegistry

--- @section Helpers

--- Returns the world list of a scene, creating it when needed
--- @param self table PhysicsRegistry
--- @param scene string Scene name
--- @return table pool
local function pool_for(self, scene)
    local pool = self.scenes[scene]
    if not pool then
        pool = {}
        self.scenes[scene] = pool
    end
    return pool
end

--- Steps every valid world in a pool and drops the ones that were destroyed
--- @param pool table|nil World list
--- @param dt number Frame time in seconds
local function update_pool(pool, dt)
    if not pool then return end

    local count = #pool
    local write = 1
    for read = 1, count do
        local world = pool[read]
        if world:is_valid() then
            world:update(dt)
            pool[write] = world
            write = write + 1
        end
    end
    for i = write, count do pool[i] = nil end
end

--- Destroys every world in a pool
--- @param pool table|nil World list
local function destroy_pool(pool)
    if not pool then return end
    for i = 1, #pool do
        if pool[i]:is_valid() then pool[i]:destroy() end
    end
end

--- @section Constructor

--- Creates the registry
--- @return table PhysicsRegistry
function PhysicsRegistry.new()
    return setmetatable({ scenes = {}, active_scene = nil }, PhysicsRegistry)
end

--- @section Worlds

--- Creates a world owned by the active scene. It is destroyed when that scene unloads
--- @param config table|nil World config, see World.new
--- @return table world
function PhysicsRegistry:add(config)
    local world = World.new(config)
    local pool = pool_for(self, self.active_scene or GLOBAL_SCENE)
    pool[#pool + 1] = world
    return world
end

--- Destroys every world owned by the active scene
function PhysicsRegistry:cleanup_worlds()
    local scene = self.active_scene or GLOBAL_SCENE
    destroy_pool(self.scenes[scene])
    self.scenes[scene] = nil
end

--- @section Frame

--- Steps the worlds of the active scene. Call once per frame, before scenes update
--- @param dt number Frame time in seconds
function PhysicsRegistry:update(dt)
    update_pool(self.scenes[GLOBAL_SCENE], dt)
    if self.active_scene then update_pool(self.scenes[self.active_scene], dt) end
end

--- @section Scene Lifecycle

--- Marks which scene newly created worlds belong to. Call when a scene becomes active
--- @param name string|nil Scene name
function PhysicsRegistry:set_active_scene(name)
    self.active_scene = name
end

--- Destroys every world a scene owns. Call when a scene unloads
--- @param name string Scene name
function PhysicsRegistry:clear_scene(name)
    destroy_pool(self.scenes[name])
    self.scenes[name] = nil
end

--- Destroys everything. Call on shutdown
function PhysicsRegistry:free()
    for _, pool in pairs(self.scenes) do destroy_pool(pool) end
    self.scenes = {}
    self.active_scene = nil
end

return PhysicsRegistry