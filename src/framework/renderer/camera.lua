--- @module camera
--- @file src/framework/renderer/camera.lua
--- @description Camera state plus raylib 2D and 3D camera modes, conversions and rays.

--- @section Imports

local _raylib = require("src.framework.bindings.raylib")
local _ffi = _raylib.ffi
local _rl = _raylib.lib

--- @section Initialisation

local cam3_box = _ffi.new("Camera3D[1]")
local cam3 = cam3_box[0]
local cam2 = _ffi.new("Camera2D")
local vec2 = _ffi.new("Vector2")
local vec3 = _ffi.new("Vector3")
local move = _ffi.new("Vector3")
local spin = _ffi.new("Vector3")

local m = {}

--- @section Constants

local PROJECTIONS = { perspective = 0, orthographic = 1 }

--- @section Helpers

local function fill_3d(c)
    local p, t, u = c.position, c.target, c.up
    cam3.position.x, cam3.position.y, cam3.position.z = p.x, p.y, p.z
    cam3.target.x, cam3.target.y, cam3.target.z = t.x, t.y, t.z
    cam3.up.x, cam3.up.y, cam3.up.z = u.x, u.y, u.z
    cam3.fovy, cam3.projection = c.fov, c.projection
    return cam3
end

local function fill_2d(c)
    cam2.offset.x, cam2.offset.y = c.offset.x, c.offset.y
    cam2.target.x, cam2.target.y = c.target_2d.x, c.target_2d.y
    cam2.rotation, cam2.zoom = c.rotation, c.zoom
    return cam2
end

--- Copies raylib's result (after UpdateCamera) back into the camera's fields.
local function read_3d(c)
    local p, t, u = c.position, c.target, c.up
    p.x, p.y, p.z = cam3.position.x, cam3.position.y, cam3.position.z
    t.x, t.y, t.z = cam3.target.x, cam3.target.y, cam3.target.z
    u.x, u.y, u.z = cam3.up.x, cam3.up.y, cam3.up.z
    c.fov = cam3.fovy
end

--- @section Screen

--- Current screen width and height.
--- @return number, number
function m.get_screen_size()
    return _rl.GetScreenWidth(), _rl.GetScreenHeight()
end

--- @section Constructor

local Camera = {}
Camera.__index = Camera

--- Creates a camera.
--- @param cfg CameraConfig|nil
--- @return Camera
function m.new(cfg)
    cfg = cfg or {}

    local screen_w, screen_h = m.get_screen_size()
    local projection = cfg.projection or 0
    if type(projection) == "string" then
        projection = PROJECTIONS[projection] or 0
    end

    return setmetatable({
        mode = cfg.mode or "2d",
        position = { x = cfg.x or 0, y = cfg.y or 0, z = cfg.z or 10 },
        target = { x = cfg.target_x or 0, y = cfg.target_y or 0, z = cfg.target_z or 0 },
        up = { x = 0, y = 1, z = 0 },
        fov = cfg.fov or 45,
        projection = projection,
        offset = { x = cfg.offset_x or screen_w / 2, y = cfg.offset_y or screen_h / 2 },
        target_2d = { x = cfg.target_2d_x or 0, y = cfg.target_2d_y or 0 },
        rotation = cfg.rotation or 0,
        zoom = cfg.zoom or 1.0,
    }, Camera)
end

--- @section Rendering Modes

--- Begins this camera's mode ("2d" or "3d"). 
--- Use inside scene:frame() for immediate drawing.
function Camera:begin_mode()
    if self.mode == "3d" then
        _rl.BeginMode3D(fill_3d(self))
    else
        _rl.BeginMode2D(fill_2d(self))
    end
end

--- Ends this camera's mode.
function Camera:end_mode()
    if self.mode == "3d" then
        _rl.EndMode3D()
    else
        _rl.EndMode2D()
    end
end

--- Begins 3D camera mode.
function Camera:begin_3d()
    _rl.BeginMode3D(fill_3d(self))
end

--- Ends 3D camera mode.
function Camera:end_3d()
    _rl.EndMode3D()
end

--- Begins 2D camera.
function Camera:begin_2d()
    _rl.BeginMode2D(fill_2d(self))
end

--- Ends 2D camera mode.
function Camera:end_2d()
    _rl.EndMode2D()
end

--- @section Setters

--- Sets the 3D position of the camera.
--- @param x number
--- @param y number
--- @param z? number defaults to the current Z
function Camera:set_position(x, y, z)
    self.position.x, self.position.y, self.position.z = x, y, z or self.position.z
end

--- Sets the 3D look-at target.
--- @param x number
--- @param y number
--- @param z? number defaults to the current Z
function Camera:set_target(x, y, z)
    self.target.x, self.target.y, self.target.z = x, y, z or self.target.z
end

--- Sets the 3D up vector.
--- @param x number
--- @param y number
--- @param z number
function Camera:set_up(x, y, z)
    self.up.x, self.up.y, self.up.z = x, y, z
end

--- Sets the 3D field of view in degrees.
--- @param fov number
function Camera:set_fov(fov)
    self.fov = fov
end

--- Sets the 2D screen offset.
--- @param x number
--- @param y number
function Camera:set_offset(x, y)
    self.offset.x, self.offset.y = x, y
end

--- Sets the 2D world point the camera looks at.
--- @param x number
--- @param y number
function Camera:set_target_2d(x, y)
    self.target_2d.x, self.target_2d.y = x, y
end

--- Points the 2D camera at a world position.
--- @param x number
--- @param y number
function Camera:follow(x, y)
    self.target_2d.x, self.target_2d.y = x, y
end

--- Sets the 2D zoom factor clamped to a minimum of 0.1.
--- @param zoom number
function Camera:set_zoom(zoom)
    self.zoom = math.max(0.1, zoom)
end

--- Sets the 2D rotation in degrees.
--- @param angle number
function Camera:set_rotation(angle)
    self.rotation = angle
end

--- @section Conversions

--- 2D: screen position to world position.
--- @param x number
--- @param y number
--- @return number, number
function Camera:screen_to_world(x, y)
    vec2.x, vec2.y = x, y
    local r = _rl.GetScreenToWorld2D(vec2, fill_2d(self))
    return r.x, r.y
end

--- 2D: world position to screen position.
--- @param x number
--- @param y number
--- @return number, number
function Camera:world_to_screen(x, y)
    vec2.x, vec2.y = x, y
    local r = _rl.GetWorldToScreen2D(vec2, fill_2d(self))
    return r.x, r.y
end

--- 3D: world position to screen position.
--- @param x number
--- @param y number
--- @param z number
--- @return number, number
function Camera:world_to_screen_3d(x, y, z)
    vec3.x, vec3.y, vec3.z = x, y, z
    local r = _rl.GetWorldToScreen(vec3, fill_3d(self))
    return r.x, r.y
end

--- 3D: ray through a screen position use mouse position for picking.
--- @param x number
--- @param y number
--- @return number, number, number, number, number, number origin xyz, direction xyz
function Camera:get_ray(x, y)
    vec2.x, vec2.y = x, y
    local r = _rl.GetScreenToWorldRay(vec2, fill_3d(self))
    return r.position.x, r.position.y, r.position.z, r.direction.x, r.direction.y, r.direction.z
end

--- @section raylib Camera Controller

--- Runs raylib's camera controller.
--- @param mode number
function Camera:update(mode)
    fill_3d(self)
    _rl.UpdateCamera(cam3_box, mode)
    read_3d(self)
end

--- Moves and rotates the camera by deltas tables are {x, y, z}.
--- @param movement table
--- @param rotation table
--- @param zoom number
function Camera:update_pro(movement, rotation, zoom)
    fill_3d(self)
    move.x, move.y, move.z = movement[1] or movement.x or 0, movement[2] or movement.y or 0, movement[3] or movement.z or 0
    spin.x, spin.y, spin.z = rotation[1] or rotation.x or 0, rotation[2] or rotation.y or 0, rotation[3] or rotation.z or 0
    _rl.UpdateCameraPro(cam3_box, move, spin, zoom or 0)
    read_3d(self)
end

return m