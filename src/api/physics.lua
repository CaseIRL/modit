--- @module api.physics
--- @file src/api/physics.lua
--- @description Rigid body physics: worlds, bodies, shapes, joints, queries and explosions, all created from config tables.
--- @default_access game
--- @default_realm shared

--- @section Initialisation

local _body = require("src.framework.physics.physics_body")
local Joint = require("src.framework.physics.physics_joint")
local m = {}

--- Helper to get the global physics registry.
local function get_registry()
    if not _G.physics_registry then
        log("warn", "PhysicsRegistry not initialized")
        return nil
    end
    return _G.physics_registry
end

--- @section Worlds

--- Creates a physics world owned by the active scene. It steps itself every frame and is destroyed when the scene unloads.
--- Bodies, queries, joints and explosions are methods on the returned world: world:new_body, world:new_spherical_joint, etc.
--- @param config table|nil { gravity = {x,y,z} (default 0, -9.81, 0), fixed_dt = 1/60, substeps = 4, max_steps = 5 }
--- @return table|nil World
function m.new_world(config)
    local registry = get_registry()
    if not registry then return nil end
    return registry:add(config)
end

--- Destroys every world owned by the active scene. Their bodies and shapes become invalid.
function m.cleanup_worlds()
    local registry = get_registry()
    if registry then registry:cleanup_worlds() end
end

--- @section Rotation

--- Builds a quaternion from euler angles in degrees (Y up, applied yaw, then pitch, then roll).
--- @param pitch number Degrees around X
--- @param yaw number Degrees around Y
--- @param roll number Degrees around Z
--- @return number x, number y, number z, number w
function m.from_euler(pitch, yaw, roll)
    return _body.from_euler(pitch, yaw, roll)
end

--- Converts a quaternion to euler angles in degrees, the inverse of from_euler.
--- @param x number Quaternion X
--- @param y number Quaternion Y
--- @param z number Quaternion Z
--- @param w number Quaternion W
--- @return number pitch, number yaw, number roll
function m.to_euler(x, y, z, w)
    return _body.to_euler(x, y, z, w)
end

return m