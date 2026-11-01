# Physics API Reference

The Physics API handles 3D rigid body simulation, shapes, joints, spatial queries, and explosion physics using config tables.

---

## World Management

Functions to create and manage physics worlds.

### `modit.physics.new_world(config)`

Creates a new physics world bound to the active scene. The world automatically updates each frame and is cleaned up when the scene unloads.

* **Parameters:**
    * `config` (table|nil): Configuration options:
        * `gravity` (table): Vector3 array `{x, y, z}` (default: `{0, -9.81, 0}`).
        * `fixed_dt` (number): Fixed time step in seconds (default: `1/60`).
        * `substeps` (number): Physics solver substeps per step (default: `4`).
        * `max_steps` (number): Maximum steps per frame (default: `5`).

* **Returns:**
    * `table|nil`: Physics world handle.

```lua
local world = modit.physics.new_world({
    gravity = { 0, -9.81, 0 },
    fixed_dt = 1 / 60
})
```

### `modit.physics.cleanup_worlds()`

Destroys all physics worlds bound to the active scene.

```lua
modit.physics.cleanup_worlds()
```

---

## Math Helpers

Rotation conversion utilities between Euler angles and Quaternions.

### `modit.physics.from_euler(pitch, yaw, roll)`

Builds a quaternion from Euler angles in degrees (applied as Y yaw, then X pitch, then Z roll).

* **Parameters:**
    * `pitch` (number): Degrees around X axis.
    * `yaw` (number): Degrees around Y axis.
    * `roll` (number): Degrees around Z axis.

* **Returns:**
    * `number, number, number, number`: Quaternion coordinates `x, y, z, w`.

```lua
local qx, qy, qz, qw = modit.physics.from_euler(0, 90, 0)
```

### `modit.physics.to_euler(x, y, z, w)`

Converts a quaternion to Euler angles in degrees.

* **Parameters:**
    * `x, y, z, w` (number): Quaternion components.

* **Returns:**
    * `number, number, number`: Pitch, yaw, and roll in degrees.

```lua
local pitch, yaw, roll = modit.physics.to_euler(qx, qy, qz, qw)
```

---

## Physics World Methods

Methods available on returned `World` objects.

### `world:new_body(config)`

Creates a new rigid body in the physics world.

* **Parameters:**
    * `config` (table|nil): Configuration options:
        * `type` (string): Body type (`"static"`, `"kinematic"`, or `"dynamic"`, default `"static"`).
        * `x`, `y`, `z` (number): Initial position coordinates.
        * `position` (table): `{x, y, z}` position alternative.
        * `rotation` (table): Euler angles `{pitch, yaw, roll}` in degrees.
        * `quat` (table): Quaternion alternative `{x, y, z, w}`.
        * `velocity` (table): Linear velocity vector `{x, y, z}`.
        * `angular_velocity` (table): Angular velocity vector `{x, y, z}` (rad/s).
        * `linear_damping` (number): Linear drag factor.
        * `angular_damping` (number): Angular drag factor.
        * `gravity_scale` (number): Gravity multiplier.
        * `bullet` (boolean): Continuous collision detection flag.
        * `fixed_rotation` (boolean): Lock angular motion along all axes.
        * `awake` (boolean): Initial sleeping state flag.
        * `shape` or `shapes` (table): Single shape config or list of shape configs.
        * `data` (table): Custom user data table attached to the body.

* **Returns:**
    * `table`: Physics `Body` handle.

```lua
local box = world:new_body({
    type = "dynamic",
    x = 0, y = 5, z = 0,
    shape = { type = "box", size = { 1, 1, 1 }, density = 1.0 }
})
```

### `world:new_spherical_joint(body_a, body_b, config)`

Creates a ball-and-socket joint between two bodies.

* **Parameters:**
    * `body_a`, `body_b` (table): Valid body objects.
    * `config` (table|nil): Options including `anchor_a`, `anchor_b`, `cone_angle`, `twist_lower`, `twist_upper`, `spring_hertz`, `spring_damping`, and `collide_connected`.

* **Returns:**
    * `table`: Physics `Joint` handle.

### `world:new_revolute_joint(body_a, body_b, config)`

Creates a hinge joint between two bodies.

* **Parameters:**
    * `body_a`, `body_b` (table): Valid body objects.
    * `config` (table|nil): Options including `anchor_a`, `anchor_b`, `lower`, `upper`, `spring_hertz`, `spring_damping`, and `collide_connected`.

* **Returns:**
    * `table`: Physics `Joint` handle.

### `world:update(dt)`

Advances simulation by fixed steps. (Handled automatically by scene lifecycle).

### `world:get_events()`

Returns collision and contact events collected during the last simulation step.

* **Returns:**
    * `table`: Contains lists `touch_begin`, `touch_end`, `hit`, `sensor_begin`, `sensor_end`.

### `world:raycast(config)`

Casts a ray and returns the closest hit.

* **Parameters:**
    * `config` (table): Raycast parameters (`origin`, `direction`, `distance`, `category`, `mask`).

* **Returns:**
    * `table|nil`: Hit table (`body`, `shape`, `x`, `y`, `z`, `nx`, `ny`, `nz`, `distance`, `fraction`) or `nil` on a miss.

```lua
local hit = world:raycast({
    origin = { 0, 10, 0 },
    direction = { 0, -1, 0 },
    distance = 100
})
```

### `world:overlap_box(config)`

Lists bodies overlapping an axis-aligned bounding box.

* **Parameters:**
    * `config` (table): Bounds options (`min = {x,y,z}`, `max = {x,y,z}`, `category`, `mask`).

* **Returns:**
    * `table`: Array of overlapping `Body` objects.

### `world:explode(config)`

Applies a spherical explosion force to surrounding dynamic bodies.

* **Parameters:**
    * `config` (table): Options (`x`, `y`, `z` or `position`, `radius`, `impulse`, `falloff`, `mask`).

### `world:set_gravity(x, y, z)` / `world:get_gravity()`

Sets or queries the world gravity vector.

### `world:clear()`

Destroys all bodies and joints while maintaining the world instance.

### `world:destroy()` / `world:is_valid()`

Destroys the world or checks if it remains valid.

---

## Body Methods

Methods available on returned `Body` handles.

### Transform & Motion

* `body:get_position()` -> `x, y, z`
* `body:set_position(x, y, z)`
* `body:get_rotation()` -> `pitch, yaw, roll` (degrees)
* `body:set_rotation(pitch, yaw, roll)`
* `body:get_quat()` -> `x, y, z, w`
* `body:get_transform()` -> `x, y, z, qx, qy, qz, qw`
* `body:set_transform(x, y, z, qx, qy, qz, qw)`
* `body:get_render_transform()` -> `x, y, z, qx, qy, qz, qw` (Interpolated for smooth rendering)
* `body:write_render_transform(target)` -> Writes render transform directly to an instance table.

### Space Conversions

* `body:get_world_point(x, y, z)` -> `wx, wy, wz`
* `body:get_local_point(x, y, z)` -> `lx, ly, lz`
* `body:get_world_vector(x, y, z)` -> `wx, wy, wz`

### Velocities & Forces

* `body:get_velocity()` / `body:set_velocity(x, y, z)`
* `body:get_angular_velocity()` / `body:set_angular_velocity(x, y, z)`
* `body:apply_force(x, y, z, [px, py, pz])`
* `body:apply_impulse(x, y, z, [px, py, pz])`
* `body:apply_torque(x, y, z)`
* `body:apply_angular_impulse(x, y, z)`

### Shapes & Properties

* `body:add_shape(config)` -> Attaches a new `box`, `sphere`, or `capsule` shape.
* `body:get_mass()` -> `number`
* `body:set_gravity_scale(scale)`
* `body:set_damping(linear, angular)`
* `body:is_awake()` / `body:set_awake(awake)`
* `body:set_enabled(enabled)`
* `body:destroy()` / `body:is_valid()`

---

## Shape Methods

Methods available on returned `Shape` handles.

* `shape:get_body()` -> Returns parent `Body`.
* `shape:set_friction(friction)`
* `shape:set_restitution(restitution)`
* `shape:set_filter(category, mask)`
* `shape:destroy()` / `shape:is_valid()`

---

## Joint Methods

Methods available on returned `Joint` handles.

* `joint:get_bodies()` -> Returns `body_a, body_b`.
* `joint:get_constraint_force()` -> `fx, fy, fz`
* `joint:get_angle()` -> Returns current angle or twist angle in radians.
* `joint:get_type()` -> `"spherical"` or `"revolute"`.
* `joint:destroy()` / `joint:is_valid()`