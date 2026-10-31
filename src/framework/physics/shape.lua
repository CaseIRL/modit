--- @module shape
--- @file src/framework/physics/shape.lua
--- @description Box3D collision shapes (box, sphere, capsule) attached to bodies, plus material and filter setters.

--- @section Imports

local _box3d = require("src.framework.bindings.box3d")
local _ffi = _box3d.ffi
local _lib = _box3d.lib

--- @section Initialisation

local m = {}
local scratch_offset = _ffi.new("b3Vec3")
local scratch_sphere = _ffi.new("b3Sphere")
local scratch_capsule = _ffi.new("b3Capsule")

--- @section Helpers

--- Builds a shape definition from options
--- @param opts table|nil Fields: density, friction, restitution, sensor, events, category, mask, user_id
--- @return cdata def b3ShapeDef
local function make_def(opts)
    local def = _lib.b3DefaultShapeDef()

    def.updateBodyMass = true

    if not opts then return def end

    if opts.density then def.density = opts.density end
    if opts.friction then def.baseMaterial.friction = opts.friction end
    if opts.restitution then def.baseMaterial.restitution = opts.restitution end
    if opts.category then def.filter.categoryBits = opts.category end
    if opts.mask then def.filter.maskBits = opts.mask end
    if opts.user_id then def.userData = _ffi.cast("void*", opts.user_id) end

    if opts.sensor then
        def.isSensor = true
        def.enableSensorEvents = true
    end

    if opts.events then
        def.enableContactEvents = true
        def.enableSensorEvents = true
        def.enableHitEvents = true
    end

    return def
end

--- @section Creation

--- Attaches a box shape
--- @param body_id cdata Body id
--- @param half_x number Half extent X
--- @param half_y number Half extent Y
--- @param half_z number Half extent Z
--- @param opts table|nil Shape options plus ox, oy, oz local offset
--- @return cdata shape_id Shape id
function m.create_box(body_id, half_x, half_y, half_z, opts)
    scratch_offset.x = opts and opts.ox or 0
    scratch_offset.y = opts and opts.oy or 0
    scratch_offset.z = opts and opts.oz or 0

    local hull = _lib.b3MakeOffsetBoxHull(half_x, half_y, half_z, scratch_offset)
    return _lib.b3CreateHullShape(body_id, make_def(opts), hull.base)
end

--- Attaches a sphere shape
--- @param body_id cdata Body id
--- @param radius number Sphere radius
--- @param opts table|nil Shape options plus ox, oy, oz local offset
--- @return cdata shape_id Shape id
function m.create_sphere(body_id, radius, opts)
    scratch_sphere.center.x = opts and opts.ox or 0
    scratch_sphere.center.y = opts and opts.oy or 0
    scratch_sphere.center.z = opts and opts.oz or 0
    scratch_sphere.radius = radius

    return _lib.b3CreateSphereShape(body_id, make_def(opts), scratch_sphere)
end

--- Attaches a capsule shape standing along the Y axis
--- @param body_id cdata Body id
--- @param radius number Capsule radius
--- @param half_height number Half length of the center segment
--- @param opts table|nil Shape options plus ox, oy, oz local offset
--- @return cdata shape_id Shape id
function m.create_capsule(body_id, radius, half_height, opts)
    local ox, oy, oz = opts and opts.ox or 0, opts and opts.oy or 0, opts and opts.oz or 0

    scratch_capsule.center1.x, scratch_capsule.center1.y, scratch_capsule.center1.z = ox, oy - half_height, oz
    scratch_capsule.center2.x, scratch_capsule.center2.y, scratch_capsule.center2.z = ox, oy + half_height, oz
    scratch_capsule.radius = radius

    return _lib.b3CreateCapsuleShape(body_id, make_def(opts), scratch_capsule)
end

--- Destroys a shape and updates the body mass
--- @param shape_id cdata Shape id
function m.destroy(shape_id)
    _lib.b3DestroyShape(shape_id, true)
end

--- @section Properties

--- Checks whether a shape id is still valid
--- @param shape_id cdata Shape id
--- @return boolean valid True if the shape exists
function m.is_valid(shape_id)
    return _lib.b3Shape_IsValid(shape_id)
end

--- Returns the user id stored on a shape
--- @param shape_id cdata Shape id
--- @return number user_id Stored id, 0 when unset
function m.get_user_id(shape_id)
    return tonumber(_ffi.cast("intptr_t", _lib.b3Shape_GetUserData(shape_id)))
end

--- Returns the user id of the body a shape belongs to
--- @param shape_id cdata Shape id
--- @return number user_id Stored body id, 0 when unset
function m.get_body_user_id(shape_id)
    local body_id = _lib.b3Shape_GetBody(shape_id)
    return tonumber(_ffi.cast("intptr_t", _lib.b3Body_GetUserData(body_id)))
end

--- Sets surface friction
--- @param shape_id cdata Shape id
--- @param friction number Friction coefficient
function m.set_friction(shape_id, friction)
    _lib.b3Shape_SetFriction(shape_id, friction)
end

--- Sets surface restitution
--- @param shape_id cdata Shape id
--- @param restitution number Bounciness
function m.set_restitution(shape_id, restitution)
    _lib.b3Shape_SetRestitution(shape_id, restitution)
end

--- Sets collision category and mask bits
--- @param shape_id cdata Shape id
--- @param category number Category bits
--- @param mask number Mask bits
function m.set_filter(shape_id, category, mask)
    local filter = _lib.b3Shape_GetFilter(shape_id)
    filter.categoryBits = category
    filter.maskBits = mask
    _lib.b3Shape_SetFilter(shape_id, filter, true)
end

return m