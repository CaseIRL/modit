--- @module body
--- @file src/framework/physics/body.lua
--- @description Box3D rigid body creation, transforms, velocities, forces and impulses. Returns plain numbers, never structs.

--- @section Imports

local _box3d = require("src.framework.bindings.box3d")
local _ffi = _box3d.ffi
local _lib = _box3d.lib

--- @section Constants

local TYPES = {
    static = _lib.b3_staticBody,
    kinematic = _lib.b3_kinematicBody,
    dynamic = _lib.b3_dynamicBody,
}

--- @section Initialisation

local m = {}
local scratch_vec = _ffi.new("b3Vec3")
local scratch_point = _ffi.new("b3Vec3")
local scratch_quat = _ffi.new("b3Quat")

--- @section Helpers

--- Fills the scratch vector
local function vec(x, y, z)
    scratch_vec.x, scratch_vec.y, scratch_vec.z = x, y, z
    return scratch_vec
end

--- Fills the scratch point
local function point(x, y, z)
    scratch_point.x, scratch_point.y, scratch_point.z = x, y, z
    return scratch_point
end

--- @section Lifecycle

--- Creates a body
--- @param world_id cdata World id
--- @param opts table Fields: type ("static"|"kinematic"|"dynamic"), x, y, z, qx, qy, qz, qw, linear_damping, angular_damping, gravity_scale, bullet, fixed_rotation, awake, user_id
--- @return cdata body_id Body id
function m.create(world_id, opts)
    local def = _lib.b3DefaultBodyDef()
    def.type = TYPES[opts.type or "static"]
    def.position.x, def.position.y, def.position.z = opts.x or 0, opts.y or 0, opts.z or 0

    if opts.qw then
        def.rotation.v.x, def.rotation.v.y, def.rotation.v.z = opts.qx, opts.qy, opts.qz
        def.rotation.s = opts.qw
    end

    if opts.linear_damping then def.linearDamping = opts.linear_damping end
    if opts.angular_damping then def.angularDamping = opts.angular_damping end
    if opts.gravity_scale then def.gravityScale = opts.gravity_scale end
    if opts.bullet then def.isBullet = true end
    if opts.awake == false then def.isAwake = false end

    if opts.fixed_rotation then
        def.motionLocks.angularX = true
        def.motionLocks.angularY = true
        def.motionLocks.angularZ = true
    end

    def.userData = _ffi.cast("void*", opts.user_id or 0)

    return _lib.b3CreateBody(world_id, def)
end

--- Destroys a body and all of its shapes
--- @param body_id cdata Body id
function m.destroy(body_id)
    _lib.b3DestroyBody(body_id)
end

--- Checks whether a body id is still valid
--- @param body_id cdata Body id
--- @return boolean valid True if the body exists
function m.is_valid(body_id)
    return _lib.b3Body_IsValid(body_id)
end

--- Returns the user id stored on a body
--- @param body_id cdata Body id
--- @return number user_id Stored id, 0 when unset
function m.get_user_id(body_id)
    return tonumber(_ffi.cast("intptr_t", _lib.b3Body_GetUserData(body_id)))
end

--- Stores a user id on a body
--- @param body_id cdata Body id
--- @param user_id number Id to store
function m.set_user_id(body_id, user_id)
    _lib.b3Body_SetUserData(body_id, _ffi.cast("void*", user_id))
end

--- @section Transform

--- Returns the body position
--- @param body_id cdata Body id
--- @return number x World X
--- @return number y World Y
--- @return number z World Z
function m.get_position(body_id)
    local p = _lib.b3Body_GetPosition(body_id)
    return p.x, p.y, p.z
end

--- Returns the body rotation as a quaternion
--- @param body_id cdata Body id
--- @return number x Quaternion X
--- @return number y Quaternion Y
--- @return number z Quaternion Z
--- @return number w Quaternion W
function m.get_rotation(body_id)
    local q = _lib.b3Body_GetRotation(body_id)
    return q.v.x, q.v.y, q.v.z, q.s
end

--- Returns position and rotation in one call
--- @param body_id cdata Body id
--- @return number x World X
--- @return number y World Y
--- @return number z World Z
--- @return number qx Quaternion X
--- @return number qy Quaternion Y
--- @return number qz Quaternion Z
--- @return number qw Quaternion W
function m.get_transform(body_id)
    local t = _lib.b3Body_GetTransform(body_id)
    return t.p.x, t.p.y, t.p.z, t.q.v.x, t.q.v.y, t.q.v.z, t.q.s
end

--- Teleports a body
--- @param body_id cdata Body id
--- @param x number World X
--- @param y number World Y
--- @param z number World Z
--- @param qx number Quaternion X
--- @param qy number Quaternion Y
--- @param qz number Quaternion Z
--- @param qw number Quaternion W
function m.set_transform(body_id, x, y, z, qx, qy, qz, qw)
    scratch_quat.v.x, scratch_quat.v.y, scratch_quat.v.z, scratch_quat.s = qx, qy, qz, qw
    _lib.b3Body_SetTransform(body_id, vec(x, y, z), scratch_quat)
end

--- Converts a local point to world space
--- @param body_id cdata Body id
--- @param x number Local X
--- @param y number Local Y
--- @param z number Local Z
--- @return number x World X
--- @return number y World Y
--- @return number z World Z
function m.get_world_point(body_id, x, y, z)
    local p = _lib.b3Body_GetWorldPoint(body_id, vec(x, y, z))
    return p.x, p.y, p.z
end

--- Converts a world point to local space
--- @param body_id cdata Body id
--- @param x number World X
--- @param y number World Y
--- @param z number World Z
--- @return number x Local X
--- @return number y Local Y
--- @return number z Local Z
function m.get_local_point(body_id, x, y, z)
    local p = _lib.b3Body_GetLocalPoint(body_id, vec(x, y, z))
    return p.x, p.y, p.z
end

--- Rotates a local direction into world space
--- @param body_id cdata Body id
--- @param x number Local X
--- @param y number Local Y
--- @param z number Local Z
--- @return number x World X
--- @return number y World Y
--- @return number z World Z
function m.get_world_vector(body_id, x, y, z)
    local v = _lib.b3Body_GetWorldVector(body_id, vec(x, y, z))
    return v.x, v.y, v.z
end

--- @section Velocity

--- Returns linear velocity
--- @param body_id cdata Body id
--- @return number x Velocity X
--- @return number y Velocity Y
--- @return number z Velocity Z
function m.get_linear_velocity(body_id)
    local v = _lib.b3Body_GetLinearVelocity(body_id)
    return v.x, v.y, v.z
end

--- Sets linear velocity
--- @param body_id cdata Body id
--- @param x number Velocity X
--- @param y number Velocity Y
--- @param z number Velocity Z
function m.set_linear_velocity(body_id, x, y, z)
    _lib.b3Body_SetLinearVelocity(body_id, vec(x, y, z))
end

--- Returns angular velocity in radians per second
--- @param body_id cdata Body id
--- @return number x Angular velocity X
--- @return number y Angular velocity Y
--- @return number z Angular velocity Z
function m.get_angular_velocity(body_id)
    local v = _lib.b3Body_GetAngularVelocity(body_id)
    return v.x, v.y, v.z
end

--- Sets angular velocity in radians per second
--- @param body_id cdata Body id
--- @param x number Angular velocity X
--- @param y number Angular velocity Y
--- @param z number Angular velocity Z
function m.set_angular_velocity(body_id, x, y, z)
    _lib.b3Body_SetAngularVelocity(body_id, vec(x, y, z))
end

--- @section Forces

--- Applies a force at the center of mass
--- @param body_id cdata Body id
--- @param x number Force X
--- @param y number Force Y
--- @param z number Force Z
function m.apply_force(body_id, x, y, z)
    _lib.b3Body_ApplyForceToCenter(body_id, vec(x, y, z), true)
end

--- Applies a force at a world point
--- @param body_id cdata Body id
--- @param x number Force X
--- @param y number Force Y
--- @param z number Force Z
--- @param px number Point X
--- @param py number Point Y
--- @param pz number Point Z
function m.apply_force_at(body_id, x, y, z, px, py, pz)
    _lib.b3Body_ApplyForce(body_id, vec(x, y, z), point(px, py, pz), true)
end

--- Applies an impulse at the center of mass
--- @param body_id cdata Body id
--- @param x number Impulse X
--- @param y number Impulse Y
--- @param z number Impulse Z
function m.apply_impulse(body_id, x, y, z)
    _lib.b3Body_ApplyLinearImpulseToCenter(body_id, vec(x, y, z), true)
end

--- Applies an impulse at a world point
--- @param body_id cdata Body id
--- @param x number Impulse X
--- @param y number Impulse Y
--- @param z number Impulse Z
--- @param px number Point X
--- @param py number Point Y
--- @param pz number Point Z
function m.apply_impulse_at(body_id, x, y, z, px, py, pz)
    _lib.b3Body_ApplyLinearImpulse(body_id, vec(x, y, z), point(px, py, pz), true)
end

--- Applies a torque
--- @param body_id cdata Body id
--- @param x number Torque X
--- @param y number Torque Y
--- @param z number Torque Z
function m.apply_torque(body_id, x, y, z)
    _lib.b3Body_ApplyTorque(body_id, vec(x, y, z), true)
end

--- Applies an angular impulse
--- @param body_id cdata Body id
--- @param x number Impulse X
--- @param y number Impulse Y
--- @param z number Impulse Z
function m.apply_angular_impulse(body_id, x, y, z)
    _lib.b3Body_ApplyAngularImpulse(body_id, vec(x, y, z), true)
end

--- @section Properties

--- Returns the body mass
--- @param body_id cdata Body id
--- @return number mass Mass in kg
function m.get_mass(body_id)
    return _lib.b3Body_GetMass(body_id)
end

--- Sets the gravity scale
--- @param body_id cdata Body id
--- @param scale number Gravity multiplier
function m.set_gravity_scale(body_id, scale)
    _lib.b3Body_SetGravityScale(body_id, scale)
end

--- Sets linear and angular damping
--- @param body_id cdata Body id
--- @param linear number Linear damping
--- @param angular number Angular damping
function m.set_damping(body_id, linear, angular)
    _lib.b3Body_SetLinearDamping(body_id, linear)
    _lib.b3Body_SetAngularDamping(body_id, angular)
end

--- Checks whether a body is awake
--- @param body_id cdata Body id
--- @return boolean awake True if awake
function m.is_awake(body_id)
    return _lib.b3Body_IsAwake(body_id)
end

--- Wakes or sleeps a body
--- @param body_id cdata Body id
--- @param awake boolean Target state
function m.set_awake(body_id, awake)
    _lib.b3Body_SetAwake(body_id, awake)
end

--- Enables or disables a body in the simulation
--- @param body_id cdata Body id
--- @param enabled boolean Target state
function m.set_enabled(body_id, enabled)
    if enabled then
        _lib.b3Body_Enable(body_id)
    else
        _lib.b3Body_Disable(body_id)
    end
end

return m