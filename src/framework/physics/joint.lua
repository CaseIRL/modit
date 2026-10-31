--- @module joint
--- @file src/framework/physics/joint.lua
--- @description Box3D joints (spherical and revolute) between two bodies. Returns plain numbers, never structs.

--- @section Imports

local _box3d = require("src.framework.bindings.box3d")
local _ffi = _box3d.ffi
local _lib = _box3d.lib

--- @section Initialisation

local m = {}

--- @section Helpers

--- Writes an anchor and optional rotation into a joint local frame
--- @param frame cdata b3Transform to fill
--- @param x number|nil Anchor X in the body's local space
--- @param y number|nil Anchor Y
--- @param z number|nil Anchor Z
--- @param q table|nil Rotation {x,y,z,w}, keeps the default (identity) when nil
local function set_frame(frame, x, y, z, q)
    frame.p.x, frame.p.y, frame.p.z = x or 0, y or 0, z or 0

    if q then
        frame.q.v.x, frame.q.v.y, frame.q.v.z = q.x, q.y, q.z
        frame.q.s = q.w
    end
end

--- Fills the shared part of every joint definition
--- @param base cdata b3JointDef to fill
--- @param body_a cdata First body id
--- @param body_b cdata Second body id
--- @param opts table Fields: ax, ay, az, bx, by, bz, frame_a, frame_b, collide_connected, user_id
local function fill_base(base, body_a, body_b, opts)
    base.bodyIdA = body_a
    base.bodyIdB = body_b

    set_frame(base.localFrameA, opts.ax, opts.ay, opts.az, opts.frame_a)
    set_frame(base.localFrameB, opts.bx, opts.by, opts.bz, opts.frame_b)

    base.collideConnected = opts.collide_connected and true or false
    base.userData = _ffi.cast("void*", opts.user_id or 0)
end

--- @section Creation

--- Creates a spherical (ball and socket) joint with optional cone and twist limits
--- @param world_id cdata World id
--- @param body_a cdata First body id
--- @param body_b cdata Second body id
--- @param opts table Base fields plus cone_angle, twist_lower, twist_upper (radians), spring_hertz, spring_damping
--- @return cdata joint_id Joint id
function m.create_spherical(world_id, body_a, body_b, opts)
    local def = _lib.b3DefaultSphericalJointDef()
    fill_base(def.base, body_a, body_b, opts)

    if opts.cone_angle then
        def.enableConeLimit = true
        def.coneAngle = opts.cone_angle
    end

    if opts.twist_lower then
        def.enableTwistLimit = true
        def.lowerTwistAngle = opts.twist_lower
        def.upperTwistAngle = opts.twist_upper
    end

    if opts.spring_hertz then
        def.enableSpring = true
        def.hertz = opts.spring_hertz
        def.dampingRatio = opts.spring_damping or 0
    end

    return _lib.b3CreateSphericalJoint(world_id, def)
end

--- Creates a revolute (hinge) joint with optional angle limits
--- @param world_id cdata World id
--- @param body_a cdata First body id
--- @param body_b cdata Second body id
--- @param opts table Base fields plus lower, upper (radians), spring_hertz, spring_damping
--- @return cdata joint_id Joint id
function m.create_revolute(world_id, body_a, body_b, opts)
    local def = _lib.b3DefaultRevoluteJointDef()
    fill_base(def.base, body_a, body_b, opts)

    if opts.lower then
        def.enableLimit = true
        def.lowerAngle = opts.lower
        def.upperAngle = opts.upper
    end

    if opts.spring_hertz then
        def.enableSpring = true
        def.hertz = opts.spring_hertz
        def.dampingRatio = opts.spring_damping or 0
    end

    return _lib.b3CreateRevoluteJoint(world_id, def)
end

--- Destroys a joint
--- @param joint_id cdata Joint id
function m.destroy(joint_id)
    _lib.b3DestroyJoint(joint_id, true)
end

--- @section Properties

--- Checks whether a joint id is still valid
--- @param joint_id cdata Joint id
--- @return boolean valid True if the joint exists
function m.is_valid(joint_id)
    return _lib.b3Joint_IsValid(joint_id)
end

--- Returns the force the joint is currently applying to hold its bodies together
--- @param joint_id cdata Joint id
--- @return number x Force X
--- @return number y Force Y
--- @return number z Force Z
function m.get_constraint_force(joint_id)
    local f = _lib.b3Joint_GetConstraintForce(joint_id)
    return f.x, f.y, f.z
end

--- Returns the current angle of a revolute joint
--- @param joint_id cdata Joint id
--- @return number angle Angle in radians
function m.get_revolute_angle(joint_id)
    return _lib.b3RevoluteJoint_GetAngle(joint_id)
end

--- Returns the current twist angle of a spherical joint
--- @param joint_id cdata Joint id
--- @return number angle Twist in radians
function m.get_twist_angle(joint_id)
    return _lib.b3SphericalJoint_GetTwistAngle(joint_id)
end

return m