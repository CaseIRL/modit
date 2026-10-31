--- @class PhysicsWorld
--- @file src/framework/physics/physics_world.lua
--- @description A physics world: creates bodies from config tables, steps itself at a fixed rate,
--- resolves events to objects and answers queries. No renderer dependency, so a dedicated server can load it.

--- @section Imports

local _world = require("src.framework.physics.world")
local _query = require("src.framework.physics.query")
local _events = require("src.framework.physics.events")
local _shape = require("src.framework.physics.shape")
local Body = require("src.framework.physics.physics_body")
local Joint = require("src.framework.physics.physics_joint")
local validate = require("src.framework.physics.validate")

local fail = validate.fail

--- @section Constants

local DEFAULT_GRAVITY_Y = -9.81
local DEFAULT_FIXED_DT = 1 / 60
local DEFAULT_SUBSTEPS = 4
local DEFAULT_MAX_STEPS = 5
local DEFAULT_RAY_DISTANCE = 1000

--- @section Initialisation

local m = {}

-- Locked so scripts cannot reach or edit the class table
local World = {}
World.__index = World
World.__metatable = "locked"

-- Private records, keyed by world object
local records = {}

--- @section Helpers

--- Returns a fresh set of event lists
--- @return table events
local function new_events()
    return { touch_begin = {}, touch_end = {}, hit = {}, sensor_begin = {}, sensor_end = {} }
end

--- Returns the private record of a world or errors when it was destroyed
--- @param self table World
--- @return table record
local function live(self)
    local w = records[self]
    if not w then fail("world is no longer valid (destroyed)") end
    return w
end

--- Turns a raw backend event (user ids) into one holding objects
--- @param w table World record
--- @param e table Raw event
--- @return table event Fields: body_a, body_b, shape_a, shape_b (+ x, y, z, nx, ny, nz, speed for hits)
local function resolve(w, e)
    local out = {
        body_a = w.bodies[e.body_a],
        body_b = w.bodies[e.body_b],
        shape_a = w.shapes[e.shape_a],
        shape_b = w.shapes[e.shape_b],
    }
    if e.speed then
        out.x, out.y, out.z = e.x, e.y, e.z
        out.nx, out.ny, out.nz = e.nx, e.ny, e.nz
        out.speed = e.speed
    end
    return out
end

--- Moves the raw events of the last step into the resolved event lists, then empties the raw lists
--- @param w table World record
local function collect_events(w)
    _events.collect(w.id, w.raw)

    for name, list in pairs(w.raw) do
        if #list > 0 then
            local target = w.events[name]
            for i = 1, #list do
                target[#target + 1] = resolve(w, list[i])
            end
            w.raw[name] = {}
        end
    end
end

--- Runs one fixed step: snapshot transforms, step, read transforms back, collect events
--- @param w table World record
local function step_once(w)
    for r in pairs(w.movers) do Body.snapshot(r) end
    _world.step(w.id, w.fixed_dt, w.substeps)
    for r in pairs(w.movers) do Body.refresh(r) end
    collect_events(w)
end

--- @section Constructor

--- Creates a world
--- @param config table|nil { gravity = {x,y,z}, fixed_dt = 1/60, substeps = 4, max_steps = 5 }
--- @return table world
function m.new(config)
    config = validate.config(config, "world config")

    local gx, gy, gz = 0, DEFAULT_GRAVITY_Y, 0
    if config.gravity ~= nil then gx, gy, gz = validate.vec(config.gravity, "gravity") end

    local fixed_dt = validate.positive(config.fixed_dt or DEFAULT_FIXED_DT, "fixed_dt")
    local substeps = validate.number(config.substeps or DEFAULT_SUBSTEPS, "substeps")
    local max_steps = validate.number(config.max_steps or DEFAULT_MAX_STEPS, "max_steps")
    if substeps < 1 or max_steps < 1 then fail("substeps and max_steps must be at least 1") end

    local id = _world.create(gx, gy, gz)
    if not id then fail("could not create world") end

    local self = setmetatable({}, World)
    records[self] = {
        id = id,
        bodies = {},   -- uid -> Body
        shapes = {},   -- uid -> Shape
        joints = {},   -- uid -> Joint 
        movers = {},   -- set of body records that can move (dynamic and kinematic)
        next_uid = 0,
        fixed_dt = fixed_dt,
        substeps = math.floor(substeps),
        max_steps = math.floor(max_steps),
        accumulator = 0,
        alpha = 0,
        events = new_events(),
        raw = new_events(),
    }
    return self
end

--- @section Lifecycle

--- Destroys the world. Every body and shape in it becomes invalid
function World:destroy()
    local w = live(self)
    for _, joint in pairs(w.joints) do Joint.release(joint) end
    for _, body in pairs(w.bodies) do Body.release(body) end
    w.bodies, w.shapes, w.joints, w.movers = {}, {}, {}, {}
    _world.destroy(w.id)
    records[self] = nil
end

--- Checks whether the world still exists
--- @return boolean valid
function World:is_valid()
    return records[self] ~= nil
end

--- Destroys every body but keeps the world, for restarting a level
function World:clear()
    local w = live(self)
    local all_joints = {}
    for _, joint in pairs(w.joints) do all_joints[#all_joints + 1] = joint end
    for i = 1, #all_joints do all_joints[i]:destroy() end

    local all_bodies = {}
    for _, body in pairs(w.bodies) do all_bodies[#all_bodies + 1] = body end
    for i = 1, #all_bodies do all_bodies[i]:destroy() end
end

--- @section Bodies

--- Creates a body from a config table
--- @param config table|nil {
---   type = "static" | "kinematic" | "dynamic" (default "static"),
---   x, y, z | position = {x,y,z},
---   rotation = {pitch, yaw, roll} in degrees | quat = {x,y,z,w},
---   velocity = {x,y,z}, angular_velocity = {x,y,z} (radians per second),
---   linear_damping, angular_damping, gravity_scale, bullet, fixed_rotation, awake,
---   shape = {...} | shapes = { {...}, {...} } (see Body:add_shape),
---   data = any table for your own use }
--- @return table body
function World:new_body(config)
    local w = live(self)
    return Body.new(self, w, config)
end

--- Creates a spherical joint between two bodies
--- @param body_a table First body
--- @param body_b table Second body
--- @param config table|nil Joint config
--- @return table joint
function World:new_spherical_joint(body_a, body_b, config)
    local w = live(self)
    return Joint.new_spherical(self, w, body_a, body_b, config)
end

--- Creates a revolute joint between two bodies
--- @param body_a table First body
--- @param body_b table Second body
--- @param config table|nil Joint config
--- @return table joint
function World:new_revolute_joint(body_a, body_b, config)
    local w = live(self)
    return Joint.new_revolute(self, w, body_a, body_b, config)
end

--- Returns how many bodies exist in the world
--- @return number count
function World:get_body_count()
    local w = live(self)
    local count = 0
    for _ in pairs(w.bodies) do count = count + 1 end
    return count
end

--- Returns how many bodies are currently awake
--- @return number count
function World:get_awake_count()
    return _world.get_awake_count(live(self).id)
end

--- @section Simulation

--- Advances the simulation in fixed steps. The registry calls this every frame for the active scene's worlds
--- @param dt number Frame time in seconds
--- @return number steps Fixed steps taken this call
function World:update(dt)
    local w = live(self)
    validate.number(dt, "dt")
    if dt < 0 then fail("dt must not be negative") end

    w.events = new_events()
    w.accumulator = w.accumulator + dt

    local steps = 0
    while w.accumulator >= w.fixed_dt and steps < w.max_steps do
        step_once(w)
        w.accumulator = w.accumulator - w.fixed_dt
        steps = steps + 1
    end

    -- drop time we could not simulate instead of spiralling
    if steps == w.max_steps and w.accumulator >= w.fixed_dt then w.accumulator = 0 end

    w.alpha = w.accumulator / w.fixed_dt
    return steps
end

--- Returns how far between the last two steps the world is, 0 to 1. Bodies use this for render transforms
--- @return number alpha
function World:get_alpha()
    return live(self).alpha
end

--- Returns the events collected by the last update. Bodies and shapes may have been destroyed since, check is_valid
--- @return table events Lists touch_begin, touch_end, hit, sensor_begin, sensor_end. Each entry has body_a, body_b, shape_a, shape_b. Hits also have x, y, z, nx, ny, nz, speed
function World:get_events()
    return live(self).events
end

--- @section Gravity

--- Sets world gravity
--- @param x number
--- @param y number
--- @param z number
function World:set_gravity(x, y, z)
    local w = live(self)
    validate.number(x, "x")
    validate.number(y, "y")
    validate.number(z, "z")
    _world.set_gravity(w.id, x, y, z)
end

--- Returns world gravity
--- @return number x
--- @return number y
--- @return number z
function World:get_gravity()
    return _world.get_gravity(live(self).id)
end

--- @section Explosions

--- Pushes every body inside a radius away from a point. Bodies with more exposed surface area receive a larger impulse
--- @param config table { x, y, z | position = {x,y,z}, radius, impulse (per unit of exposed surface area), falloff = extra fade distance beyond the radius (default 0), mask = category mask of bodies to affect }
function World:explode(config)
    local w = live(self)
    config = validate.config(config, "explode config")

    local x, y, z = validate.position(config)
    local radius = validate.positive(config.radius, "radius")
    local impulse = validate.number(config.impulse, "impulse")
    local falloff = validate.optional_number(config.falloff, "falloff")
    local mask = validate.optional_number(config.mask, "mask")

    _world.explode(w.id, x, y, z, radius, falloff, impulse, mask)
end

--- @section Queries

--- Casts a ray and returns the closest hit
--- @param config table { origin = {x,y,z}, direction = {x,y,z} (does not need to be normalised), distance = 1000, category, mask }
--- @return table|nil hit Fields: body, shape, x, y, z, nx, ny, nz, distance, fraction. Nil on a miss
function World:raycast(config)
    local w = live(self)
    config = validate.config(config, "raycast config")
    if config.origin == nil or config.direction == nil then fail("raycast needs an origin and a direction") end

    local ox, oy, oz = validate.vec(config.origin, "origin")
    local dx, dy, dz = validate.vec(config.direction, "direction")
    local distance = validate.positive(config.distance or DEFAULT_RAY_DISTANCE, "distance")
    local category = validate.optional_number(config.category, "category")
    local mask = validate.optional_number(config.mask, "mask")

    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if length < 1e-9 then fail("direction must not be zero") end
    local scale = distance / length

    local shape_id, px, py, pz, nx, ny, nz, fraction =
        _query.raycast_closest(w.id, ox, oy, oz, dx * scale, dy * scale, dz * scale, category, mask)
    if not shape_id then return nil end

    return {
        body = w.bodies[_shape.get_body_user_id(shape_id)],
        shape = w.shapes[_shape.get_user_id(shape_id)],
        x = px, y = py, z = pz,
        nx = nx, ny = ny, nz = nz,
        distance = fraction * distance,
        fraction = fraction,
    }
end

--- Lists the bodies whose shapes overlap a box
--- @param config table { min = {x,y,z}, max = {x,y,z}, category, mask }
--- @return table bodies Array of unique bodies
function World:overlap_box(config)
    local w = live(self)
    config = validate.config(config, "overlap config")
    if config.min == nil or config.max == nil then fail("overlap_box needs min and max") end

    local min_x, min_y, min_z = validate.vec(config.min, "min")
    local max_x, max_y, max_z = validate.vec(config.max, "max")
    local category = validate.optional_number(config.category, "category")
    local mask = validate.optional_number(config.mask, "mask")

    local found, seen = {}, {}

    _query.overlap_aabb(w.id, min_x, min_y, min_z, max_x, max_y, max_z, category, mask, function(shape_id)
        local uid = _shape.get_body_user_id(shape_id)
        if not seen[uid] then
            seen[uid] = true
            local body = w.bodies[uid]
            if body then found[#found + 1] = body end
        end
    end)

    return found
end

return m