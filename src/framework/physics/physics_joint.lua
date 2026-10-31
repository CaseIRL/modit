--- @class PhysicsJoint
--- @file src/framework/physics/physics_joint.lua
--- @description Rigid body joint objects (spherical and revolute). Created from worlds, providing safe handles and queries.

--- @section Imports

local _joint = require("src.framework.physics.joint")
local Body = require("src.framework.physics.physics_body")
local validate = require("src.framework.physics.validate")

local fail = validate.fail

--- @section Initialisation

local m = {}

local Joint = {}
Joint.__index = Joint
Joint.__metatable = "locked"

local joint_records = {}

--- @section Helpers

--- Returns the private record of a joint or errors when it was destroyed
--- @param self table Joint
--- @return table record
local function joint_record(self)
    local record = joint_records[self]
    if not record then fail("joint is no longer valid (destroyed)") end
    return record
end

--- Validates and prepares joint options
--- @param config table|nil
--- @return table opts
local function prepare_opts(config)
    config = validate.config(config, "joint config")
    local opts = {}

    if config.anchor_a ~= nil then
        opts.ax, opts.ay, opts.az = validate.vec(config.anchor_a, "anchor_a")
    end
    if config.anchor_b ~= nil then
        opts.bx, opts.by, opts.bz = validate.vec(config.anchor_b, "anchor_b")
    end

    if config.frame_a ~= nil then opts.frame_a = config.frame_a end
    if config.frame_b ~= nil then opts.frame_b = config.frame_b end

    opts.collide_connected = config.collide_connected and true or nil

    if config.cone_angle ~= nil then
        opts.cone_angle = validate.number(config.cone_angle, "cone_angle")
    end
    if config.twist_lower ~= nil then
        opts.twist_lower = validate.number(config.twist_lower, "twist_lower")
        opts.twist_upper = validate.number(config.twist_upper, "twist_upper")
    end
    if config.lower ~= nil then
        opts.lower = validate.number(config.lower, "lower")
        opts.upper = validate.number(config.upper, "upper")
    end
    if config.spring_hertz ~= nil then
        opts.spring_hertz = validate.positive(config.spring_hertz, "spring_hertz")
        opts.spring_damping = validate.number(config.spring_damping or 0, "spring_damping")
    end

    return opts
end

--- Destroys the native joint data and registry entry
--- @param self table Joint
--- @param r table Joint record
local function destroy_record(self, r)
    r.wrec.joints[r.uid] = nil
    _joint.destroy(r.id)
    joint_records[self] = nil
end

--- @section Internal (used by the world)

function m.new_spherical(world, wrec, body_a, body_b, config)
    if type(body_a) ~= "table" or type(body_b) ~= "table" then
        fail("spherical joint requires two valid body objects")
    end

    local id_a = Body.get_native_id(body_a)
    local id_b = Body.get_native_id(body_b)
    local opts = prepare_opts(config)

    wrec.next_uid = wrec.next_uid + 1
    local uid = wrec.next_uid
    opts.user_id = uid

    local joint_id = _joint.create_spherical(wrec.id, id_a, id_b, opts)
    if not joint_id then fail("could not create spherical joint") end

    local self = setmetatable({ data = config.data or {} }, Joint)
    local r = {
        id = joint_id,
        uid = uid,
        world = world,
        wrec = wrec,
        body_a = body_a,
        body_b = body_b,
        type = "spherical",
    }
    joint_records[self] = r
    wrec.joints[uid] = self

    return self
end

function m.new_revolute(world, wrec, body_a, body_b, config)
    if type(body_a) ~= "table" or type(body_b) ~= "table" then
        fail("revolute joint requires two valid body objects")
    end

    local id_a = Body.get_native_id(body_a)
    local id_b = Body.get_native_id(body_b)
    local opts = prepare_opts(config)

    wrec.next_uid = wrec.next_uid + 1
    local uid = wrec.next_uid
    opts.user_id = uid

    local joint_id = _joint.create_revolute(wrec.id, id_a, id_b, opts)
    if not joint_id then fail("could not create revolute joint") end

    local self = setmetatable({ data = config.data or {} }, Joint)
    local r = {
        id = joint_id,
        uid = uid,
        world = world,
        wrec = wrec,
        body_a = body_a,
        body_b = body_b,
        type = "revolute",
    }
    joint_records[self] = r
    wrec.joints[uid] = self

    return self
end

--- Invalidates a joint without touching native data (world destroys it)
--- @param joint table Joint object
function m.release(joint)
    joint_records[joint] = nil
end

--- @section Lifecycle

function Joint:destroy()
    destroy_record(self, joint_record(self))
end

function Joint:is_valid()
    return joint_records[self] ~= nil
end

function Joint:get_world()
    return joint_record(self).world
end

function Joint:get_type()
    return joint_record(self).type
end

function Joint:get_bodies()
    local r = joint_record(self)
    return r.body_a, r.body_b
end

--- @section Properties

function Joint:get_constraint_force()
    local r = joint_record(self)
    return _joint.get_constraint_force(r.id)
end

function Joint:get_angle()
    local r = joint_record(self)
    if r.type == "revolute" then
        return _joint.get_revolute_angle(r.id)
    elseif r.type == "spherical" then
        return _joint.get_twist_angle(r.id)
    end
    return 0
end

return m