--- @module query
--- @file src/framework/physics/query.lua
--- @description Box3D spatial queries: closest raycast and AABB overlap.

--- @section Imports

local _box3d = require("src.framework.bindings.box3d")
local _ffi = _box3d.ffi
local _lib = _box3d.lib

--- @section Initialisation

local m = {}
local scratch_origin = _ffi.new("b3Vec3")
local scratch_translation = _ffi.new("b3Vec3")
local scratch_aabb = _ffi.new("b3AABB")
local shape_bits = _ffi.new("uint64_t[1]")
local shape_view = _ffi.cast("b3ShapeId*", shape_bits)

--- @section Helpers

--- Builds a query filter, defaulting to everything
--- @param category number|nil Category bits
--- @param mask number|nil Mask bits
--- @return cdata filter b3QueryFilter
local function make_filter(category, mask)
    local filter = _lib.b3DefaultQueryFilter()
    if category then filter.categoryBits = category end
    if mask then filter.maskBits = mask end
    return filter
end

--- @section Queries

--- Casts a ray and returns the closest hit
--- @param world_id cdata World id
--- @param ox number Origin X
--- @param oy number Origin Y
--- @param oz number Origin Z
--- @param tx number Translation X (direction times length)
--- @param ty number Translation Y
--- @param tz number Translation Z
--- @param category number|nil Query category bits
--- @param mask number|nil Query mask bits
--- @return cdata|nil shape_id Hit shape id, nil on a miss
--- @return number px Hit point X
--- @return number py Hit point Y
--- @return number pz Hit point Z
--- @return number nx Hit normal X
--- @return number ny Hit normal Y
--- @return number nz Hit normal Z
--- @return number fraction Hit position along the translation, 0 to 1
function m.raycast_closest(world_id, ox, oy, oz, tx, ty, tz, category, mask)
    scratch_origin.x, scratch_origin.y, scratch_origin.z = ox, oy, oz
    scratch_translation.x, scratch_translation.y, scratch_translation.z = tx, ty, tz

    local result = _lib.b3World_CastRayClosest(world_id, scratch_origin, scratch_translation, make_filter(category, mask))
    if not result.hit then return nil end

    return result.shapeId, result.point.x, result.point.y, result.point.z,
        result.normal.x, result.normal.y, result.normal.z, result.fraction
end

--- Calls a function for every shape whose bounds overlap a box
--- @param world_id cdata World id
--- @param min_x number Lower bound X
--- @param min_y number Lower bound Y
--- @param min_z number Lower bound Z
--- @param max_x number Upper bound X
--- @param max_y number Upper bound Y
--- @param max_z number Upper bound Z
--- @param category number|nil Query category bits
--- @param mask number|nil Query mask bits
--- @param callback function Receives each shape id, return false to stop
function m.overlap_aabb(world_id, min_x, min_y, min_z, max_x, max_y, max_z, category, mask, callback)
    scratch_aabb.lowerBound.x, scratch_aabb.lowerBound.y, scratch_aabb.lowerBound.z = min_x, min_y, min_z
    scratch_aabb.upperBound.x, scratch_aabb.upperBound.y, scratch_aabb.upperBound.z = max_x, max_y, max_z

    local failure

    local native = _ffi.cast("bool (*)(uint64_t, void*)", function(bits)
        shape_bits[0] = bits
        local ok, result = pcall(callback, shape_view[0])
        if not ok then
            failure = result
            return false
        end
        return result ~= false
    end)

    _lib.b3World_OverlapAABB(world_id, scratch_aabb, make_filter(category, mask), _ffi.cast("b3OverlapResultFcn*", native), nil)
    native:free()

    if failure then error(failure, 0) end
end

return m