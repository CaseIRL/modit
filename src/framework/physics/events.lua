--- @module events
--- @file src/framework/physics/events.lua
--- @description Collects Box3D contact, hit and sensor events after a step as plain Lua tables using user ids.

--- @section Imports

local _box3d = require("src.framework.bindings.box3d")
local _ffi = _box3d.ffi
local _lib = _box3d.lib

--- @section Initialisation

local m = {}

--- @section Helpers

--- Returns the shape and body user ids of a shape, or 0 when it no longer exists
--- @param shape_id cdata Shape id
--- @return number shape_uid Shape user id
--- @return number body_uid Body user id
local function ids_of(shape_id)
    if not _lib.b3Shape_IsValid(shape_id) then return 0, 0 end

    local shape_uid = tonumber(_ffi.cast("intptr_t", _lib.b3Shape_GetUserData(shape_id)))
    local body_id = _lib.b3Shape_GetBody(shape_id)
    local body_uid = tonumber(_ffi.cast("intptr_t", _lib.b3Body_GetUserData(body_id)))
    return shape_uid, body_uid
end

--- Builds a pair event from two shapes
--- @param shape_a cdata First shape id
--- @param shape_b cdata Second shape id
--- @return table event Fields: shape_a, shape_b, body_a, body_b
local function pair_event(shape_a, shape_b)
    local sa, ba = ids_of(shape_a)
    local sb, bb = ids_of(shape_b)
    return { shape_a = sa, shape_b = sb, body_a = ba, body_b = bb }
end

--- @section Collection

--- Appends the events of the last step to an output table
--- @param world_id cdata World id
--- @param out table Lists touch_begin, touch_end, hit, sensor_begin, sensor_end
function m.collect(world_id, out)
    local contacts = _lib.b3World_GetContactEvents(world_id)

    for i = 0, contacts.beginCount - 1 do
        local e = contacts.beginEvents[i]
        out.touch_begin[#out.touch_begin + 1] = pair_event(e.shapeIdA, e.shapeIdB)
    end

    for i = 0, contacts.endCount - 1 do
        local e = contacts.endEvents[i]
        out.touch_end[#out.touch_end + 1] = pair_event(e.shapeIdA, e.shapeIdB)
    end

    for i = 0, contacts.hitCount - 1 do
        local e = contacts.hitEvents[i]
        local event = pair_event(e.shapeIdA, e.shapeIdB)
        event.x, event.y, event.z = e.point.x, e.point.y, e.point.z
        event.nx, event.ny, event.nz = e.normal.x, e.normal.y, e.normal.z
        event.speed = e.approachSpeed
        out.hit[#out.hit + 1] = event
    end

    local sensors = _lib.b3World_GetSensorEvents(world_id)

    for i = 0, sensors.beginCount - 1 do
        local e = sensors.beginEvents[i]
        out.sensor_begin[#out.sensor_begin + 1] = pair_event(e.sensorShapeId, e.visitorShapeId)
    end

    for i = 0, sensors.endCount - 1 do
        local e = sensors.endEvents[i]
        out.sensor_end[#out.sensor_end + 1] = pair_event(e.sensorShapeId, e.visitorShapeId)
    end
end

return m