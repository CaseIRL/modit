--- @class Environment
--- @file src/framework/renderer/environment.lua
--- @description Scene environment: sun, ambient, fog, sky, and shadows.
--[[
    Notes:

    Only applies to scenes with a 3D camera. The render list calls, in order:
        begin_scene     shadow-map depth pass, sky
        begin_lighting  uploads sun, ambient, fog (camera mode is now active)
        end_lighting    projected and blob shadows
    Models opt out per object: cast_shadow = false, unlit = true.
    Colours are 0-255 in the API and stored 0-1 for the shaders, sky colours stay 0-255.
]]

--- @section Imports

local _lighting = require("src.framework.renderer.lighting")
local _sky = require("src.framework.renderer.sky")
local _camera = require("src.framework.renderer.camera")

--- @section Constants

local SHADOW_MODES = { off = true, blob = true, projected = true, map = true }
local MIN_SUN_DROP = 0.05
local SHADOW_LIFT = 0.01
local MAP_NEAR = 0.1
local BLOB_LAYERS = { { 1.0, 0.45 }, { 0.72, 0.35 }, { 0.45, 0.3 } }

--- @section Helpers

--- Stores a normalised sun direction.
--- @param sun table
--- @param dx number
--- @param dy number
--- @param dz number
local function set_direction(sun, dx, dy, dz)
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    if len < 1e-6 then
        dx, dy, dz, len = 0, -1, 0, 1
    end
    dx, dy, dz = dx / len, dy / len, dz / len

    if dy > -MIN_SUN_DROP then
        dy = -MIN_SUN_DROP
        len = math.sqrt(dx * dx + dy * dy + dz * dz)
        dx, dy, dz = dx / len, dy / len, dz / len
    end

    sun.dx, sun.dy, sun.dz = dx, dy, dz
end

--- out = a * b for column-major 4x4 matrices given as 16 numbers.
local function multiply(out, a, b)
    for c = 0, 3 do
        for r = 0, 3 do
            local sum = 0
            for k = 0, 3 do
                sum = sum + a[k * 4 + r + 1] * b[c * 4 + k + 1]
            end
            out[c * 4 + r + 1] = sum
        end
    end
end

local view, proj = {}, {}
for i = 1, 16 do
    view[i], proj[i] = 0, 0
end

--- Builds the sun's orthographic view-projection around a point just ahead of the camera.
--- The centre is snapped to shadow-map texels so shadows don't shimmer as the camera moves.
--- @param out table 16 numbers
--- @param sun table
--- @param camera table
--- @param range number Side length of the shadowed square in world units
--- @param size number Shadow map size in pixels
--- @return number depth_range World units covered from near to far plane
local function build_light_matrix(out, sun, camera, range, size)
    local half = range * 0.5

    local fx = camera.target.x - camera.position.x
    local fy = camera.target.y - camera.position.y
    local fz = camera.target.z - camera.position.z
    local fl = math.sqrt(fx * fx + fy * fy + fz * fz)
    if fl < 1e-6 then fx, fy, fz, fl = 0, 0, -1, 1 end

    local ahead = range * 0.25 / fl
    local cx = camera.position.x + fx * ahead
    local cy = camera.position.y + fy * ahead
    local cz = camera.position.z + fz * ahead

    local dx, dy, dz = sun.dx, sun.dy, sun.dz
    local px, py, pz = 0, 1, 0
    if math.abs(dy) > 0.99 then px, py, pz = 0, 0, 1 end

    local sx, sy, sz = dy * pz - dz * py, dz * px - dx * pz, dx * py - dy * px
    local sl = math.sqrt(sx * sx + sy * sy + sz * sz)
    sx, sy, sz = sx / sl, sy / sl, sz / sl
    local vx, vy, vz = sy * dz - sz * dy, sz * dx - sx * dz, sx * dy - sy * dx

    local texel = range / size
    local a = cx * sx + cy * sy + cz * sz
    local b = cx * vx + cy * vy + cz * vz
    local da = math.floor(a / texel + 0.5) * texel - a
    local db = math.floor(b / texel + 0.5) * texel - b
    cx, cy, cz = cx + sx * da + vx * db, cy + sy * da + vy * db, cz + sz * da + vz * db

    local ex, ey, ez = cx - dx * range, cy - dy * range, cz - dz * range

    view[1], view[2], view[3], view[4] = sx, vx, -dx, 0
    view[5], view[6], view[7], view[8] = sy, vy, -dy, 0
    view[9], view[10], view[11], view[12] = sz, vz, -dz, 0
    view[13] = -(sx * ex + sy * ey + sz * ez)
    view[14] = -(vx * ex + vy * ey + vz * ez)
    view[15] = dx * ex + dy * ey + dz * ez
    view[16] = 1

    local far = range * 2
    proj[1] = 1 / half
    proj[6] = 1 / half
    proj[11] = -2 / (far - MAP_NEAR)
    proj[15] = -(far + MAP_NEAR) / (far - MAP_NEAR)
    proj[16] = 1

    multiply(out, proj, view)
    return far - MAP_NEAR
end

--- @section Constructor

local Environment = {}
Environment.__index = Environment

--- Creates a new Environment instance.
--- @return Environment
function Environment.new()
    local self = setmetatable({}, Environment)
    self.vp = {}
    for i = 1, 16 do self.vp[i] = 0 end
    self.fog_draw = { near = 0, far = 1, r = 0, g = 0, b = 0 }
    self.depth_range = 1
    self.map_ready = false
    self.lit = false
    self:reset()
    return self
end

--- @section Settings

--- Restores every setting to its default.
function Environment:reset()
    self.lighting = true
    self.sun = { dx = 0, dy = -1, dz = 0, r = 1, g = 0.95, b = 0.85 }
    set_direction(self.sun, -0.4, -1, -0.3)
    self.ambient = { r = 0.35, g = 0.37, b = 0.45 }
    self.fog = { near = 1e5, far = 1e6, r = 22 / 255, g = 22 / 255, b = 22 / 255, custom = false }
    self.sky = nil
    self.shadows = { mode = "off", strength = 0.6, range = 40, size = 2048, ground = 0 }
end

--- Turns lighting on or off.
--- @param enabled boolean
function Environment:set_lighting(enabled)
    self.lighting = enabled and true or false
end

--- Sets the sun direction and colour.
--- @param dx number
--- @param dy number Should be negative, clamped to stay pointing down
--- @param dz number
--- @param r number|nil 0-255 (default 255)
--- @param g number|nil 0-255 (default 255)
--- @param b number|nil 0-255 (default 255)
function Environment:set_sun(dx, dy, dz, r, g, b)
    set_direction(self.sun, dx, dy, dz)
    self.sun.r, self.sun.g, self.sun.b = (r or 255) / 255, (g or 255) / 255, (b or 255) / 255
end

--- Sets the ambient light colour.
--- @param r number 0-255
--- @param g number 0-255
--- @param b number 0-255
function Environment:set_ambient(r, g, b)
    self.ambient.r, self.ambient.g, self.ambient.b = r / 255, g / 255, b / 255
end

--- Sets distance fog.
--- @param near number Distance where fog starts
--- @param far number Distance where fog is solid
--- @param r number|nil 0-255
--- @param g number|nil 0-255
--- @param b number|nil 0-255
function Environment:set_fog(near, far, r, g, b)
    local fog = self.fog
    fog.near, fog.far = near, math.max(far, near + 0.01)
    if r then
        fog.r, fog.g, fog.b, fog.custom = r / 255, (g or r) / 255, (b or r) / 255, true
    else
        fog.custom = false
    end
end

--- Sets the sky gradient.
--- @param tr number Top red 0-255
--- @param tg number Top green 0-255
--- @param tb number Top blue 0-255
--- @param hr number Horizon red 0-255
--- @param hg number Horizon green 0-255
--- @param hb number Horizon blue 0-255
function Environment:set_sky(tr, tg, tb, hr, hg, hb)
    self.sky = {
        top = { r = tr, g = tg, b = tb },
        horizon = { r = hr, g = hg, b = hb },
    }
end

--- Removes the sky, the window clear colour shows instead.
function Environment:clear_sky()
    self.sky = nil
end

--- Sets the shadow mode and its options.
--- @param config table { mode = "off"|"blob"|"projected"|"map", strength, range, size, ground }
function Environment:set_shadows(config)
    config = config or {}
    local shadows = self.shadows

    if config.mode ~= nil then
        if not SHADOW_MODES[config.mode] then
            log("warn", "Unknown shadow mode", { mode = tostring(config.mode) })
        else
            shadows.mode = config.mode
        end
    end

    shadows.strength = math.max(0, math.min(1, config.strength or shadows.strength))
    shadows.range = math.max(1, config.range or shadows.range)
    shadows.size = math.max(256, math.floor(config.size or shadows.size))
    shadows.ground = config.ground or shadows.ground
end

--- @section Frame

--- Screen Y of the horizon for the camera's heading.
--- @param camera table
--- @param height number Screen height in pixels
--- @return number
function Environment:horizon(camera, height)
    local fx = camera.target.x - camera.position.x
    local fz = camera.target.z - camera.position.z
    local len = math.sqrt(fx * fx + fz * fz)
    if len < 1e-4 then fx, fz, len = 0, -1, 1 end

    local _, y = camera:world_to_screen_3d(
        camera.position.x + fx / len * 1000,
        camera.position.y,
        camera.position.z + fz / len * 1000)
    return math.max(0, math.min(height, math.floor(y)))
end

--- Runs the shadow-map depth pass and draws the sky.
--- @param camera table 3D camera
--- @param items table Draw list items, world objects first
--- @param count number How many leading items are world objects
function Environment:begin_scene(camera, items, count)
    _lighting.finish()
    self.map_ready = false

    local shadows = self.shadows
    if self.lighting and shadows.mode == "map" then
        self.depth_range = build_light_matrix(self.vp, self.sun, camera, shadows.range, shadows.size)
        if _lighting.map_begin(shadows.size, self.vp) then
            for i = 1, count do
                local obj = items[i]
                if obj.active and obj.cast_shadow then
                    obj:render_shadow()
                end
            end
            _lighting.map_end()
            self.map_ready = true
        end
    end

    local width, height = _camera.get_screen_size()
    local sky = self.sky

    if sky then
        local horizon_y = self:horizon(camera, height)
        _sky.draw(width, height, horizon_y, sky.top, sky.horizon)
    end
end

--- Uploads sun, ambient and fog and hands over the shadow map.
function Environment:begin_lighting()
    self.lit = false
    if not self.lighting then return end

    local fog, draw = self.fog, self.fog_draw
    draw.near, draw.far = fog.near, fog.far
    if fog.custom or not self.sky then
        draw.r, draw.g, draw.b = fog.r, fog.g, fog.b
    else
        local horizon = self.sky.horizon
        draw.r, draw.g, draw.b = horizon.r / 255, horizon.g / 255, horizon.b / 255
    end

    self.lit = _lighting.begin(self.sun, self.ambient, draw)

    if self.lit and self.map_ready then
        local shadows = self.shadows
        _lighting.map_receive(self.vp, 1 / shadows.size, self.depth_range, shadows.strength)
    end
end

--- Draws one soft blob under a caster.
--- @param obj table Draw list item with get_bounds
function Environment:draw_blob(obj)
    local shadows = self.shadows
    local x0, _, z0, x1, _, z1 = obj:get_bounds()
    local radius = math.max(x1 - x0, z1 - z0) * 0.5
    local cx, cz = (x0 + x1) * 0.5, (z0 + z1) * 0.5

    for i, layer in ipairs(BLOB_LAYERS) do
        _lighting.blob_disc(cx, shadows.ground + SHADOW_LIFT + i * 0.002, cz, radius * layer[1], layer[2] * shadows.strength)
    end
end

--- Draws projected and blob shadows, then ends the lit pass.
--- @param items table Draw list items, world objects first
--- @param count number How many leading items are world objects
function Environment:end_lighting(items, count)
    if not self.lit then return end

    local shadows = self.shadows
    if shadows.mode == "projected" then
        if _lighting.shadow_begin(self.sun, shadows.ground + SHADOW_LIFT, shadows.strength, self.fog_draw) then
            for i = 1, count do
                local obj = items[i]
                if obj.active and obj.cast_shadow then
                    obj:render_shadow()
                end
            end
            _lighting.shadow_end()
        end
    elseif shadows.mode == "blob" then
        for i = 1, count do
            local obj = items[i]
            if obj.active and obj.cast_shadow and obj.get_bounds then
                self:draw_blob(obj)
            end
        end
    end

    _lighting.finish()
    self.lit = false
end

--- @section Cleanup

--- Releases shaders and the shadow map.
function Environment:free()
    _lighting.free()
    self.map_ready, self.lit = false, false
end

return Environment