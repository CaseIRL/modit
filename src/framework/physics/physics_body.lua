--- @class PhysicsBody
--- @file src/framework/physics/physics_body.lua
--- @description Rigid body and shape objects. Bodies are created from config tables by a world, keep a cached
--- transform for cheap reads, and provide interpolated render transforms between fixed physics steps.

--- @section Imports

local _body = require("src.framework.physics.body")
local _shape = require("src.framework.physics.shape")
local validate = require("src.framework.physics.validate")

local fail = validate.fail

--- @section Constants

local BODY_TYPES = { static = true, kinematic = true, dynamic = true }
local SHAPE_TYPES = { box = true, sphere = true, capsule = true }
local RAD_PER_DEG = math.pi / 180
local DEG_PER_RAD = 180 / math.pi

--- @section Initialisation

-- Module table: internal functions used by the world, plus the rotation helpers. Not exposed to mods.
local m = {}

-- Object classes. The metatable is locked so scripts cannot reach or edit the class tables.
local Body = {}
Body.__index = Body
Body.__metatable = "locked"

local Shape = {}
Shape.__index = Shape
Shape.__metatable = "locked"

-- Private records. Scripts only ever hold the objects, never the native ids.
local body_records = {}
local shape_records = {}

--- @section Rotation

--- Builds a quaternion from euler angles in degrees (Y up, applied yaw, then pitch, then roll)
--- @param pitch number Rotation around X in degrees
--- @param yaw number Rotation around Y in degrees
--- @param roll number Rotation around Z in degrees
--- @return number x
--- @return number y
--- @return number z
--- @return number w
function m.from_euler(pitch, yaw, roll)
    validate.number(pitch, "pitch")
    validate.number(yaw, "yaw")
    validate.number(roll, "roll")

    local cx, sx = math.cos(pitch * RAD_PER_DEG * 0.5), math.sin(pitch * RAD_PER_DEG * 0.5)
    local cy, sy = math.cos(yaw * RAD_PER_DEG * 0.5), math.sin(yaw * RAD_PER_DEG * 0.5)
    local cz, sz = math.cos(roll * RAD_PER_DEG * 0.5), math.sin(roll * RAD_PER_DEG * 0.5)

    return sx * cy * cz + cx * sy * sz,
        cx * sy * cz - sx * cy * sz,
        cx * cy * sz - sx * sy * cz,
        cx * cy * cz + sx * sy * sz
end

--- Converts a quaternion to euler angles in degrees, the inverse of from_euler
--- @param x number
--- @param y number
--- @param z number
--- @param w number
--- @return number pitch Degrees
--- @return number yaw Degrees
--- @return number roll Degrees
function m.to_euler(x, y, z, w)
    validate.number(x, "x")
    validate.number(y, "y")
    validate.number(z, "z")
    validate.number(w, "w")

    local sin_pitch = math.max(-1, math.min(1, -2 * (y * z - w * x)))

    return math.asin(sin_pitch) * DEG_PER_RAD,
        math.atan2(2 * (x * z + w * y), 1 - 2 * (x * x + y * y)) * DEG_PER_RAD,
        math.atan2(2 * (x * y + w * z), 1 - 2 * (x * x + z * z)) * DEG_PER_RAD
end

--- Returns the native body id (internal use only)
--- @param body table Body object
--- @return cdata id Native body id
function m.get_native_id(body)
    local r = body_records[body]
    if not r then fail("body is no longer valid (destroyed)") end
    return r.id
end

--- @section Helpers

--- Returns the private record of a body or errors when it was destroyed
--- @param self table Body
--- @return table record
local function body_record(self)
    local record = body_records[self]
    if not record then fail("body is no longer valid (destroyed)") end
    return record
end

--- Returns the private record of a shape or errors when it was destroyed
--- @param self table Shape
--- @return table record
local function shape_record(self)
    local record = shape_records[self]
    if not record then fail("shape is no longer valid (destroyed)") end
    return record
end

--- Reads the live transform from Box3D into the record's cache
--- @param r table Body record
local function read_transform(r)
    r.x, r.y, r.z, r.qx, r.qy, r.qz, r.qw = _body.get_transform(r.id)
end

--- Copies the cached transform into the previous-step slots (no interpolation until the next step)
--- @param r table Body record
local function copy_previous(r)
    r.px, r.py, r.pz, r.pqx, r.pqy, r.pqz, r.pqw = r.x, r.y, r.z, r.qx, r.qy, r.qz, r.qw
end

--- Validates a shape config and turns it into a descriptor, without touching native code
--- @param config table Shape config
--- @return table descriptor
local function prepare_shape(config)
    if type(config) ~= "table" then fail("shape config must be a table") end

    local kind = config.type
    if not SHAPE_TYPES[kind] then fail("shape type must be \"box\", \"sphere\" or \"capsule\"") end

    local opts = {}
    if config.density ~= nil then opts.density = validate.positive(config.density, "density") end
    if config.friction ~= nil then opts.friction = validate.number(config.friction, "friction") end
    if config.restitution ~= nil then opts.restitution = validate.number(config.restitution, "restitution") end
    if config.category ~= nil then opts.category = validate.number(config.category, "category") end
    if config.mask ~= nil then opts.mask = validate.number(config.mask, "mask") end
    opts.sensor = config.sensor and true or nil
    opts.events = config.events and true or nil

    if config.offset ~= nil then
        opts.ox, opts.oy, opts.oz = validate.vec(config.offset, "offset")
    end

    local descriptor = { kind = kind, opts = opts }

    if kind == "box" then
        local sx, sy, sz = validate.size(config.size, "size", 1)
        descriptor.a, descriptor.b, descriptor.c = sx / 2, sy / 2, sz / 2
    elseif kind == "sphere" then
        descriptor.a = validate.positive(config.radius or 0.5, "radius")
    else
        descriptor.a = validate.positive(config.radius or 0.5, "radius")
        descriptor.b = validate.positive(config.height or 1, "height") / 2
    end

    return descriptor
end

--- Creates the native shape for a prepared descriptor and registers it
--- @param self table Body
--- @param r table Body record
--- @param descriptor table From prepare_shape
--- @return table shape
local function create_shape(self, r, descriptor)
    local wrec = r.wrec
    wrec.next_uid = wrec.next_uid + 1
    local uid = wrec.next_uid
    descriptor.opts.user_id = uid

    local shape_id
    if descriptor.kind == "box" then
        shape_id = _shape.create_box(r.id, descriptor.a, descriptor.b, descriptor.c, descriptor.opts)
    elseif descriptor.kind == "sphere" then
        shape_id = _shape.create_sphere(r.id, descriptor.a, descriptor.opts)
    else
        shape_id = _shape.create_capsule(r.id, descriptor.a, descriptor.b, descriptor.opts)
    end

    local shape = setmetatable({}, Shape)
    shape_records[shape] = { id = shape_id, uid = uid, body = self, brec = r, wrec = wrec }
    r.shapes[shape] = true
    wrec.shapes[uid] = shape
    return shape
end

--- Destroys a body's native data and every registry entry that points at it
--- @param self table Body
--- @param r table Body record
local function destroy_record(self, r)
    for shape in pairs(r.shapes) do
        local s = shape_records[shape]
        if s then r.wrec.shapes[s.uid] = nil end
        shape_records[shape] = nil
    end

    r.wrec.bodies[r.uid] = nil
    r.wrec.movers[r] = nil
    _body.destroy(r.id)
    body_records[self] = nil
end

--- @section Internal (used by the world)

--- Creates a body in a world from a config table
--- @param world table World object
--- @param wrec table The world's private record
--- @param config table|nil Body config, see World:new_body
--- @return table body
function m.new(world, wrec, config)
    config = validate.config(config, "body config")

    local body_type = config.type or "static"
    if not BODY_TYPES[body_type] then fail("invalid body type: " .. tostring(body_type)) end

    local x, y, z = validate.position(config)

    local qx, qy, qz, qw = 0, 0, 0, 1
    if config.quat ~= nil then
        qx, qy, qz, qw = validate.quat(config.quat, "quat")
    elseif config.rotation ~= nil then
        qx, qy, qz, qw = m.from_euler(validate.euler(config.rotation, "rotation"))
    end

    local def = { type = body_type, x = x, y = y, z = z, qx = qx, qy = qy, qz = qz, qw = qw }
    for _, key in ipairs({ "linear_damping", "angular_damping", "gravity_scale" }) do
        if config[key] ~= nil then def[key] = validate.number(config[key], key) end
    end
    def.bullet = config.bullet and true or nil
    def.fixed_rotation = config.fixed_rotation and true or nil
    if config.awake == false then def.awake = false end

    local has_velocity = config.velocity ~= nil
    local vx, vy, vz = validate.vec(config.velocity, "velocity")
    local has_spin = config.angular_velocity ~= nil
    local wx, wy, wz = validate.vec(config.angular_velocity, "angular_velocity")

    if config.shape ~= nil and config.shapes ~= nil then fail("use either shape or shapes, not both") end
    local shape_configs = config.shapes
    if config.shape ~= nil then shape_configs = { config.shape } end
    if shape_configs ~= nil and type(shape_configs) ~= "table" then fail("shapes must be a list of shape configs") end

    -- validate every shape before anything native exists, so a bad config never leaks a body
    local descriptors = {}
    for i = 1, #(shape_configs or {}) do
        descriptors[i] = prepare_shape(shape_configs[i])
    end

    wrec.next_uid = wrec.next_uid + 1
    local uid = wrec.next_uid
    def.user_id = uid

    local self = setmetatable({ data = config.data or {} }, Body)
    local r = {
        id = _body.create(wrec.id, def),
        uid = uid,
        world = world,
        wrec = wrec,
        type = body_type,
        shapes = {},
        awake = def.awake ~= false,
    }
    body_records[self] = r
    wrec.bodies[uid] = self

    read_transform(r)
    copy_previous(r)
    if body_type ~= "static" then wrec.movers[r] = true end

    if has_velocity then _body.set_linear_velocity(r.id, vx, vy, vz) end
    if has_spin then _body.set_angular_velocity(r.id, wx, wy, wz) end

    for i = 1, #descriptors do
        create_shape(self, r, descriptors[i])
    end

    return self
end

--- Saves the current transform as the previous one. Called before every physics step
--- @param r table Body record
function m.snapshot(r)
    copy_previous(r)
end

--- Reads the new transform after a physics step. Sleeping bodies are skipped, except on the step they fell asleep
--- @param r table Body record
function m.refresh(r)
    local awake = _body.is_awake(r.id)
    if awake or r.awake then read_transform(r) end
    r.awake = awake
end

--- Invalidates a body without touching native data (the world destroys it)
--- @param body table Body object
function m.release(body)
    local r = body_records[body]
    if not r then return end
    for shape in pairs(r.shapes) do shape_records[shape] = nil end
    body_records[body] = nil
end

--- @section Lifecycle

--- Destroys the body and all of its shapes. The object is invalid afterwards
function Body:destroy()
    destroy_record(self, body_record(self))
end

--- Checks whether the body still exists
--- @return boolean valid
function Body:is_valid()
    return body_records[self] ~= nil
end

--- Returns the world this body lives in
--- @return table world
function Body:get_world()
    return body_record(self).world
end

--- Returns "static", "kinematic" or "dynamic"
--- @return string type
function Body:get_type()
    return body_record(self).type
end

--- @section Shapes

--- Attaches another shape to the body
--- @param config table { type = "box" | "sphere" | "capsule", size, radius, height, offset, density, friction, restitution, sensor, events, category, mask }
--- @return table shape
function Body:add_shape(config)
    local r = body_record(self)
    return create_shape(self, r, prepare_shape(config))
end

--- @section Transform

--- Returns the position as of the last physics step
--- @return number x
--- @return number y
--- @return number z
function Body:get_position()
    local r = body_record(self)
    return r.x, r.y, r.z
end

--- Returns the rotation as a quaternion as of the last physics step
--- @return number x
--- @return number y
--- @return number z
--- @return number w
function Body:get_quat()
    local r = body_record(self)
    return r.qx, r.qy, r.qz, r.qw
end

--- Returns the rotation as euler degrees { pitch, yaw, roll }
--- @return number pitch
--- @return number yaw
--- @return number roll
function Body:get_rotation()
    local r = body_record(self)
    return m.to_euler(r.qx, r.qy, r.qz, r.qw)
end

--- Returns position and quaternion as of the last physics step
--- @return number x
--- @return number y
--- @return number z
--- @return number qx
--- @return number qy
--- @return number qz
--- @return number qw
function Body:get_transform()
    local r = body_record(self)
    return r.x, r.y, r.z, r.qx, r.qy, r.qz, r.qw
end

--- Returns the transform blended between the last two physics steps. Draw bodies with this.
--- It removes the stepping judder that appears when rendering faster than the physics rate.
--- @return number x
--- @return number y
--- @return number z
--- @return number qx
--- @return number qy
--- @return number qz
--- @return number qw
function Body:get_render_transform()
    local r = body_record(self)
    local t = r.wrec.alpha

    local x = r.px + (r.x - r.px) * t
    local y = r.py + (r.y - r.py) * t
    local z = r.pz + (r.z - r.pz) * t

    -- normalised lerp, flipped to the short way round
    local dot = r.pqx * r.qx + r.pqy * r.qy + r.pqz * r.qz + r.pqw * r.qw
    local sign = dot < 0 and -1 or 1
    local qx = r.pqx + (sign * r.qx - r.pqx) * t
    local qy = r.pqy + (sign * r.qy - r.pqy) * t
    local qz = r.pqz + (sign * r.qz - r.pqz) * t
    local qw = r.pqw + (sign * r.qw - r.pqw) * t

    local length = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
    if length > 1e-9 then
        qx, qy, qz, qw = qx / length, qy / length, qz / length, qw / length
    else
        qx, qy, qz, qw = r.qx, r.qy, r.qz, r.qw
    end

    return x, y, z, qx, qy, qz, qw
end

--- Writes the interpolated render transform straight into a bulk instance (or any table), no allocation.
--- Sets x, y, z, qx, qy, qz, qw. Bulk instances use the quaternion when qw is present, which skips the
--- quaternion to Euler round trip that get_rotation does.
--- @param target table Instance table to fill
--- @return table target
function Body:write_render_transform(target)
    target.x, target.y, target.z, target.qx, target.qy, target.qz, target.qw = self:get_render_transform()
    return target
end

--- Teleports the body. Skips interpolation, so it will not smear across the jump
--- @param x number
--- @param y number
--- @param z number
--- @param qx number Quaternion X
--- @param qy number Quaternion Y
--- @param qz number Quaternion Z
--- @param qw number Quaternion W
function Body:set_transform(x, y, z, qx, qy, qz, qw)
    local r = body_record(self)
    validate.coord(x, "x")
    validate.coord(y, "y")
    validate.coord(z, "z")
    qx, qy, qz, qw = validate.quat({ x = qx, y = qy, z = qz, w = qw }, "quaternion")

    _body.set_transform(r.id, x, y, z, qx, qy, qz, qw)
    read_transform(r)
    copy_previous(r)
end

--- Teleports the body, keeping its rotation
--- @param x number
--- @param y number
--- @param z number
function Body:set_position(x, y, z)
    local r = body_record(self)
    validate.coord(x, "x")
    validate.coord(y, "y")
    validate.coord(z, "z")

    _body.set_transform(r.id, x, y, z, r.qx, r.qy, r.qz, r.qw)
    read_transform(r)
    copy_previous(r)
end

--- Rotates the body in place from euler degrees
--- @param pitch number Degrees around X
--- @param yaw number Degrees around Y
--- @param roll number Degrees around Z
function Body:set_rotation(pitch, yaw, roll)
    local r = body_record(self)
    local qx, qy, qz, qw = m.from_euler(pitch, yaw, roll)

    _body.set_transform(r.id, r.x, r.y, r.z, qx, qy, qz, qw)
    read_transform(r)
    copy_previous(r)
end

--- Converts a local point to world space
--- @param x number Local X
--- @param y number Local Y
--- @param z number Local Z
--- @return number x
--- @return number y
--- @return number z
function Body:get_world_point(x, y, z)
    local r = body_record(self)
    validate.number(x, "x")
    validate.number(y, "y")
    validate.number(z, "z")
    return _body.get_world_point(r.id, x, y, z)
end

--- Converts a world point to local space
--- @param x number World X
--- @param y number World Y
--- @param z number World Z
--- @return number x
--- @return number y
--- @return number z
function Body:get_local_point(x, y, z)
    local r = body_record(self)
    validate.number(x, "x")
    validate.number(y, "y")
    validate.number(z, "z")
    return _body.get_local_point(r.id, x, y, z)
end

--- Rotates a local direction into world space
--- @param x number Local X
--- @param y number Local Y
--- @param z number Local Z
--- @return number x
--- @return number y
--- @return number z
function Body:get_world_vector(x, y, z)
    local r = body_record(self)
    validate.number(x, "x")
    validate.number(y, "y")
    validate.number(z, "z")
    return _body.get_world_vector(r.id, x, y, z)
end

--- @section Velocity

--- Returns linear velocity in meters per second
--- @return number x
--- @return number y
--- @return number z
function Body:get_velocity()
    return _body.get_linear_velocity(body_record(self).id)
end

--- Sets linear velocity in meters per second
--- @param x number
--- @param y number
--- @param z number
function Body:set_velocity(x, y, z)
    local r = body_record(self)
    validate.number(x, "x")
    validate.number(y, "y")
    validate.number(z, "z")
    _body.set_linear_velocity(r.id, x, y, z)
end

--- Returns angular velocity in radians per second
--- @return number x
--- @return number y
--- @return number z
function Body:get_angular_velocity()
    return _body.get_angular_velocity(body_record(self).id)
end

--- Sets angular velocity in radians per second
--- @param x number
--- @param y number
--- @param z number
function Body:set_angular_velocity(x, y, z)
    local r = body_record(self)
    validate.number(x, "x")
    validate.number(y, "y")
    validate.number(z, "z")
    _body.set_angular_velocity(r.id, x, y, z)
end

--- @section Forces

--- Applies a force for the next step. Applied at the center of mass, or at a world point when px, py, pz are given
--- @param x number Force X
--- @param y number Force Y
--- @param z number Force Z
--- @param px number|nil Point X
--- @param py number|nil Point Y
--- @param pz number|nil Point Z
function Body:apply_force(x, y, z, px, py, pz)
    local r = body_record(self)
    validate.number(x, "x")
    validate.number(y, "y")
    validate.number(z, "z")

    if px == nil then
        _body.apply_force(r.id, x, y, z)
    else
        validate.coord(px, "px")
        validate.coord(py, "py")
        validate.coord(pz, "pz")
        _body.apply_force_at(r.id, x, y, z, px, py, pz)
    end
end

--- Applies an instant impulse. Applied at the center of mass, or at a world point when px, py, pz are given
--- @param x number Impulse X
--- @param y number Impulse Y
--- @param z number Impulse Z
--- @param px number|nil Point X
--- @param py number|nil Point Y
--- @param pz number|nil Point Z
function Body:apply_impulse(x, y, z, px, py, pz)
    local r = body_record(self)
    validate.number(x, "x")
    validate.number(y, "y")
    validate.number(z, "z")

    if px == nil then
        _body.apply_impulse(r.id, x, y, z)
    else
        validate.coord(px, "px")
        validate.coord(py, "py")
        validate.coord(pz, "pz")
        _body.apply_impulse_at(r.id, x, y, z, px, py, pz)
    end
end

--- Applies a torque for the next step
--- @param x number
--- @param y number
--- @param z number
function Body:apply_torque(x, y, z)
    local r = body_record(self)
    validate.number(x, "x")
    validate.number(y, "y")
    validate.number(z, "z")
    _body.apply_torque(r.id, x, y, z)
end

--- Applies an instant angular impulse
--- @param x number
--- @param y number
--- @param z number
function Body:apply_angular_impulse(x, y, z)
    local r = body_record(self)
    validate.number(x, "x")
    validate.number(y, "y")
    validate.number(z, "z")
    _body.apply_angular_impulse(r.id, x, y, z)
end

--- @section Properties

--- Returns the body mass in kg
--- @return number mass
function Body:get_mass()
    return _body.get_mass(body_record(self).id)
end

--- Sets the gravity multiplier
--- @param scale number
function Body:set_gravity_scale(scale)
    local r = body_record(self)
    validate.number(scale, "scale")
    _body.set_gravity_scale(r.id, scale)
end

--- Sets linear and angular damping
--- @param linear number
--- @param angular number
function Body:set_damping(linear, angular)
    local r = body_record(self)
    validate.number(linear, "linear")
    validate.number(angular, "angular")
    _body.set_damping(r.id, linear, angular)
end

--- Checks whether the body is awake
--- @return boolean awake
function Body:is_awake()
    return _body.is_awake(body_record(self).id)
end

--- Wakes or sleeps the body
--- @param awake boolean
function Body:set_awake(awake)
    _body.set_awake(body_record(self).id, awake and true or false)
end

--- Enables or disables the body in the simulation
--- @param enabled boolean
function Body:set_enabled(enabled)
    _body.set_enabled(body_record(self).id, enabled and true or false)
end

--- @section Shape Methods

--- Destroys the shape and updates the body mass
function Shape:destroy()
    local s = shape_record(self)
    s.brec.shapes[self] = nil
    s.wrec.shapes[s.uid] = nil
    shape_records[self] = nil
    _shape.destroy(s.id)
end

--- Checks whether the shape still exists
--- @return boolean valid
function Shape:is_valid()
    return shape_records[self] ~= nil
end

--- Returns the body the shape is attached to
--- @return table body
function Shape:get_body()
    return shape_record(self).body
end

--- Sets surface friction
--- @param friction number
function Shape:set_friction(friction)
    local s = shape_record(self)
    validate.number(friction, "friction")
    _shape.set_friction(s.id, friction)
end

--- Sets surface restitution (bounciness)
--- @param restitution number
function Shape:set_restitution(restitution)
    local s = shape_record(self)
    validate.number(restitution, "restitution")
    _shape.set_restitution(s.id, restitution)
end

--- Sets collision category and mask bits
--- @param category number
--- @param mask number
function Shape:set_filter(category, mask)
    local s = shape_record(self)
    validate.number(category, "category")
    validate.number(mask, "mask")
    _shape.set_filter(s.id, category, mask)
end

return m