--- @module model
--- @file src/framework/renderer/model.lua
--- @description Model loading, meshes, and drawing.

--- @section Imports

local _raylib = require("src.framework.bindings.raylib")
local _ffi = _raylib.ffi
local _rl = _raylib.lib

local _lighting = require("src.framework.renderer.lighting")

--- @section Constants

local DEG2RAD = math.pi / 180
local MAP_ALBEDO = 0
local MAP_SHADOW = 10

--- @section Initialisation

local m = {}

local colours = {
    white = _ffi.new("Color", 255, 255, 255, 255),
    black = _ffi.new("Color", 0, 0, 0, 255),
    red = _ffi.new("Color", 230, 41, 55, 255),
    green = _ffi.new("Color", 0, 228, 48, 255),
    blue = _ffi.new("Color", 0, 121, 241, 255),
    yellow = _ffi.new("Color", 253, 249, 0, 255),
    gray = _ffi.new("Color", 130, 130, 130, 255),
    blank = _ffi.new("Color", 0, 0, 0, 0),
}

m.primitives = {
    cube = function() return _rl.GenMeshCube(1, 1, 1) end,
    sphere = function() return _rl.GenMeshSphere(0.5, 16, 16) end,
    plane = function() return _rl.GenMeshPlane(1, 1, 1, 1) end,
    cylinder = function() return _rl.GenMeshCylinder(0.5, 1, 16) end,
}

--- @section Helpers

local function resolve_colour(c)
    if type(c) == "string" then
        return colours[c] or colours.white
    elseif type(c) == "table" then
        return _ffi.new("Color", c[1] or 255, c[2] or 255, c[3] or 255, c[4] or 255)
    end
    return c
end

--- @section Bulk Helpers

local DEFAULT_SCALE = 1.0
local MIN_CAPACITY = 256

-- Named colours as 0-1 floats, so per instance colour never touches cdata
local named_rgb = {}
for name, c in pairs(colours) do
    named_rgb[name] = { c.r / 255, c.g / 255, c.b / 255 }
end

--- Reads a colour of any supported kind as r, g, b in 0-1.
--- @param c string|table|cdata|nil
--- @param dr number Fallback r
--- @param dg number Fallback g
--- @param db number Fallback b
--- @return number, number, number
local function colour_rgb(c, dr, dg, db)
    if c == nil then return dr, dg, db end
    local kind = type(c)
    if kind == "table" then
        return (c[1] or 255) / 255, (c[2] or 255) / 255, (c[3] or 255) / 255
    elseif kind == "string" then
        local n = named_rgb[c] or named_rgb.white
        return n[1], n[2], n[3]
    elseif kind == "cdata" then
        return c.r / 255, c.g / 255, c.b / 255
    end
    return dr, dg, db
end

-- One grow only buffer shared by every bulk draw. DrawMeshInstanced copies it before returning, so sharing is safe,
-- and it never holds more than the largest instance count ever drawn.
local transform_buffer = nil
local transform_capacity = 0

local function transforms_for(n)
    if n > transform_capacity then
        transform_capacity = math.max(n, transform_capacity * 2, MIN_CAPACITY)
        transform_buffer = _ffi.new("Matrix[?]", transform_capacity)
    end
    return transform_buffer
end

-- Camera frustum for sphere culling, rebuilt per bulk draw (a few dozen flops)
local frustum = { cx = 0, cy = 0, cz = 0, fx = 0, fy = 0, fz = 0, rx = 0, ry = 0, rz = 0, ux = 0, uy = 0, uz = 0,
                  tx = 0, ty = 0, kx = 1, ky = 1 }

local FRUSTUM_MARGIN = 1.05

--- Fills the module frustum from a 3D perspective camera.
--- @param camera table Camera object (position, target, up, fov, projection, mode)
--- @return boolean usable False for 2D, orthographic or degenerate cameras (no culling then)
local function build_frustum(camera)
    if type(camera) ~= "table" or camera.mode ~= "3d" or (camera.projection or 0) ~= 0 then return false end
    local p, t, u = camera.position, camera.target, camera.up
    if not (p and t and u and camera.fov) then return false end

    local fx, fy, fz = t.x - p.x, t.y - p.y, t.z - p.z
    local fl = math.sqrt(fx * fx + fy * fy + fz * fz)
    if fl < 1e-6 then return false end
    fx, fy, fz = fx / fl, fy / fl, fz / fl

    local rx, ry, rz = fy * u.z - fz * u.y, fz * u.x - fx * u.z, fx * u.y - fy * u.x
    local rl = math.sqrt(rx * rx + ry * ry + rz * rz)
    if rl < 1e-6 then return false end
    rx, ry, rz = rx / rl, ry / rl, rz / rl

    local ux, uy, uz = ry * fz - rz * fy, rz * fx - rx * fz, rx * fy - ry * fx

    local w, h = _rl.GetScreenWidth(), _rl.GetScreenHeight()
    if h <= 0 or w <= 0 then return false end

    local ty = math.tan(camera.fov * DEG2RAD * 0.5) * FRUSTUM_MARGIN
    local tx = ty * (w / h)

    local f = frustum
    f.cx, f.cy, f.cz = p.x, p.y, p.z
    f.fx, f.fy, f.fz = fx, fy, fz
    f.rx, f.ry, f.rz = rx, ry, rz
    f.ux, f.uy, f.uz = ux, uy, uz
    f.tx, f.ty = tx, ty
    f.kx, f.ky = math.sqrt(1 + tx * tx), math.sqrt(1 + ty * ty)
    return true
end

--- Writes one transform per visible instance, packed from index 0, and returns how many were written.
--- Rotation comes from a quaternion (qx, qy, qz, qw, assumed unit length) when the instance has qw, otherwise from
--- Euler degrees (rx, ry, rz) in the same order as set_transform. The colour goes into m3, m7 and m11.
--- @param buffer cdata Matrix[?] with room for count entries
--- @param list table Instances
--- @param count number
--- @param dr number Default r (0-1)
--- @param dg number Default g (0-1)
--- @param db number Default b (0-1)
--- @param radius number|nil Bounding sphere radius of the unscaled model, enables culling when given
--- @return number written
local function fill_transforms(buffer, list, count, dr, dg, db, radius)
    local f = frustum
    local cx, cy, cz = f.cx, f.cy, f.cz
    local fx, fy, fz = f.fx, f.fy, f.fz
    local rx_, ry_, rz_ = f.rx, f.ry, f.rz
    local ux_, uy_, uz_ = f.ux, f.uy, f.uz
    local tx, ty, kx, ky = f.tx, f.ty, f.kx, f.ky

    local written = 0
    for i = 1, count do
        local inst = list[i]
        local x, y, z = inst.x or 0, inst.y or 0, inst.z or 0

        local scale = inst.scale or DEFAULT_SCALE
        local sx, sy, sz = scale, scale, scale
        if type(scale) == "table" then
            sx = scale.x or scale[1] or 1
            sy = scale.y or scale[2] or 1
            sz = scale.z or scale[3] or 1
        end

        local visible = true
        if radius then
            local sm = sx
            if sy > sm then sm = sy end
            if sz > sm then sm = sz end
            local rad = radius * (sm < 0 and -sm or sm)

            local dx, dy, dz = x - cx, y - cy, z - cz
            local depth = dx * fx + dy * fy + dz * fz
            if depth + rad < 0 then
                visible = false
            else
                local px = dx * rx_ + dy * ry_ + dz * rz_
                local py = dx * ux_ + dy * uy_ + dz * uz_
                local lim = depth * tx + rad * kx
                if px > lim or -px > lim then
                    visible = false
                else
                    lim = depth * ty + rad * ky
                    if py > lim or -py > lim then visible = false end
                end
            end
        end

        if visible then
            local t = buffer[written]
            written = written + 1

            local c = inst.colour or inst.color
            local r, g, b
            if c == nil then r, g, b = dr, dg, db else r, g, b = colour_rgb(c, dr, dg, db) end

            local r00, r10, r20, r01, r11, r21, r02, r12, r22
            local qw = inst.qw
            if qw then
                local qx, qy, qz = inst.qx or 0, inst.qy or 0, inst.qz or 0
                local x2, y2, z2 = qx + qx, qy + qy, qz + qz
                local xx, xy, xz = qx * x2, qx * y2, qx * z2
                local yy, yz, zz = qy * y2, qy * z2, qz * z2
                local wx, wy, wz = qw * x2, qw * y2, qw * z2
                r00, r10, r20 = 1 - (yy + zz), xy + wz, xz - wy
                r01, r11, r21 = xy - wz, 1 - (xx + zz), yz + wx
                r02, r12, r22 = xz + wy, yz - wx, 1 - (xx + yy)
            else
                local rx, ry, rz = inst.rx or 0, inst.ry or 0, inst.rz or 0
                if rx == 0 and ry == 0 and rz == 0 then
                    r00, r10, r20 = 1, 0, 0
                    r01, r11, r21 = 0, 1, 0
                    r02, r12, r22 = 0, 0, 1
                else
                    local sa, ca = math.sin(rx * DEG2RAD), math.cos(rx * DEG2RAD)
                    local sb, cb = math.sin(ry * DEG2RAD), math.cos(ry * DEG2RAD)
                    local sg, cg = math.sin(rz * DEG2RAD), math.cos(rz * DEG2RAD)
                    r00, r10, r20 = cb * cg + sb * sa * sg, ca * sg, -sb * cg + cb * sa * sg
                    r01, r11, r21 = -cb * sg + sb * sa * cg, ca * cg, sb * sg + cb * sa * cg
                    r02, r12, r22 = sb * ca, -sa, cb * ca
                end
            end

            t.m0, t.m1, t.m2 = r00 * sx, r10 * sx, r20 * sx
            t.m4, t.m5, t.m6 = r01 * sy, r11 * sy, r21 * sy
            t.m8, t.m9, t.m10 = r02 * sz, r12 * sz, r22 * sz
            t.m12, t.m13, t.m14 = x, y, z
            t.m3, t.m7, t.m11, t.m15 = r, g, b, 1
        end
    end
    return written
end

--- @section Model Loading & Unloading

--- Load model from file (meshes and materials).
--- @param file_name string
--- @return Model
function m.load_model(file_name)
    return _rl.LoadModel(file_name)
end

--- Load a unit primitive by name ("cube", "sphere", "plane", "cylinder").
--- @param name string
--- @return Model|nil
function m.load_primitive(name)
    local gen = m.primitives[name]
    if not gen then return nil end
    return _rl.LoadModelFromMesh(gen())
end

--- Check if a model is valid (loaded in GPU).
--- @param model Model
--- @return boolean
function m.is_model_valid(model)
    return _rl.IsModelValid(model)
end

--- Unload model (including meshes) from memory.
--- @param model Model
function m.unload_model(model)
    _rl.UnloadModel(model)
end

--- Compute the local bounding box of a model.
--- @param model Model
--- @return number, number, number, number, number, number min xyz, max xyz
function m.get_model_bounds(model)
    local box = _rl.GetModelBoundingBox(model)
    return box.min.x, box.min.y, box.min.z, box.max.x, box.max.y, box.max.z
end

--- @section Transform

--- Creates a native Matrix that can be mutated in place.
--- @return cdata Matrix
function m.new_matrix()
    return _ffi.new("Matrix")
end

--- Fills a Matrix with translation * rotation * scale.
--- Rotation is euler degrees applied roll (Z), then pitch (X), then yaw (Y).
--- @param mat cdata Matrix
--- @param x number
--- @param y number
--- @param z number
--- @param rx number pitch degrees
--- @param ry number yaw degrees
--- @param rz number roll degrees
--- @param sx number
--- @param sy number
--- @param sz number
function m.set_transform(mat, x, y, z, rx, ry, rz, sx, sy, sz)
    local sa, ca = math.sin(rx * DEG2RAD), math.cos(rx * DEG2RAD)
    local sb, cb = math.sin(ry * DEG2RAD), math.cos(ry * DEG2RAD)
    local sg, cg = math.sin(rz * DEG2RAD), math.cos(rz * DEG2RAD)

    mat.m0 = (cb * cg + sb * sa * sg) * sx
    mat.m4 = (-cb * sg + sb * sa * cg) * sy
    mat.m8 = (sb * ca) * sz
    mat.m12 = x

    mat.m1 = (ca * sg) * sx
    mat.m5 = (ca * cg) * sy
    mat.m9 = (-sa) * sz
    mat.m13 = y

    mat.m2 = (-sb * cg + cb * sa * sg) * sx
    mat.m6 = (sb * sg + cb * sa * cg) * sy
    mat.m10 = (cb * ca) * sz
    mat.m14 = z

    mat.m3, mat.m7, mat.m11, mat.m15 = 0, 0, 0, 1
end

--- @section Drawing

--- Draws every mesh of a model with a transform matrix and tint.
--- @param model Model
--- @param transform cdata Matrix
--- @param tint cdata Color
--- @param unlit boolean|nil Skip lighting and use the materials own shader
--- @param custom cdata|nil Shader handle that replaces the lit shader for this draw
function m.draw_model(model, transform, tint, unlit, custom)
    local shadow_pass = _lighting.is_shadow_pass()
    local shader = (custom and not shadow_pass) and custom or _lighting.mesh_shader(unlit)
    local shadow_texture = shader and not custom and _lighting.shadow_texture()

    local tr, tg, tb, ta = tint.r, tint.g, tint.b, tint.a
    local white = _lighting.is_shadow_pass() or (tr == 255 and tg == 255 and tb == 255 and ta == 255)

    for i = 0, model.meshCount - 1 do
        local mesh = model.meshes[i]
        local material = model.materials[model.meshMaterial[i]]

        local saved_id, saved_locs
        if shader then
            saved_id, saved_locs = material.shader.id, material.shader.locs
            material.shader.id, material.shader.locs = shader.id, shader.locs
            if shadow_texture then
                material.maps[MAP_SHADOW].texture = shadow_texture
            end
            _lighting.set_mesh(mesh.normals ~= nil)
        end

        local colour, r, g, b, a
        if not white then
            colour = material.maps[MAP_ALBEDO].color
            r, g, b, a = colour.r, colour.g, colour.b, colour.a
            colour.r = math.floor(r * tr / 255)
            colour.g = math.floor(g * tg / 255)
            colour.b = math.floor(b * tb / 255)
            colour.a = math.floor(a * ta / 255)
        end

        _rl.DrawMesh(mesh, material, transform)

        if colour then
            colour.r, colour.g, colour.b, colour.a = r, g, b, a
        end

        if shader then
            material.shader.id, material.shader.locs = saved_id, saved_locs
            if shadow_texture then
                material.maps[MAP_SHADOW].texture.id = 0
            end
        end
    end
end

-- Every mesh of the model, one DrawMeshInstanced each. Module level so a draw never allocates a closure.
local function draw_meshes(model, shader, buffer, n, set_normals, shadow_texture)
    for i = 0, model.meshCount - 1 do
        local mesh = model.meshes[i]
        local material = model.materials[model.meshMaterial[i]]

        -- Copy the shader fields, a nested struct read from FFI is a reference, so saving the struct itself
        -- would just alias whatever we write over it.
        local saved_id, saved_locs = material.shader.id, material.shader.locs
        material.shader.id, material.shader.locs = shader.id, shader.locs

        if shadow_texture then
            material.maps[MAP_SHADOW].texture = shadow_texture
        end
        if set_normals then
            _lighting.set_mesh(mesh.normals ~= nil, true)
        end

        local ok, err = pcall(_rl.DrawMeshInstanced, mesh, material, buffer, n)

        if shadow_texture then
            material.maps[MAP_SHADOW].texture.id = 0
        end
        material.shader.id, material.shader.locs = saved_id, saved_locs

        if not ok then error(err, 0) end
    end
end

local warned_bulk = false

--- Draws many copies of a model, every mesh of it, in GPU instanced draw calls.
---
--- Works in every pass: the lit pass (with sun, fog and received shadows), the sun's depth pass and projected
--- shadows, so bulk objects cast and receive shadows like normal models. Colour is per instance for free.
--- Instances: { x, y, z, scale (number or {x,y,z}), colour, and either rx, ry, rz (degrees) or qx, qy, qz, qw }.
--- Frustum culling runs in the lit pass only (shadow casters outside the view still cast shadows).
--- @param asset table|cdata Loaded model asset or native Model
--- @param instances table Array of instance tables
--- @param count number|nil How many entries to draw, defaults to #instances
--- @param camera table|nil Camera object, enables frustum culling together with opts.radius
--- @param colour string|table|cdata|nil Colour for instances without their own
--- @param uniform boolean|nil Ignored, kept for older callers (colour is always per instance now)
--- @param opts table|nil { radius = bounding sphere radius of the unscaled model, cull = boolean }
--- @return boolean ok
function m.draw_bulk_instances(asset, instances, count, camera, colour, uniform, opts)
    local shader, pass = _lighting.instance_shader()
    if not shader then return false end

    local model = (type(asset) == "table" and asset.handle) or asset
    if not model or model.meshCount <= 0 then return false end

    count = count or #instances
    if count <= 0 then return true end

    local radius = nil
    if opts and opts.radius and opts.cull ~= false and (pass == "lit" or pass == "flat") then
        if build_frustum(camera) then radius = opts.radius end
    end

    local dr, dg, db = colour_rgb(colour, 1, 1, 1)
    local buffer = transforms_for(count)
    local n = fill_transforms(buffer, instances, count, dr, dg, db, radius)
    if n == 0 then return true end

    _rl.rlDrawRenderBatchActive()

    local lit_pass = pass == "lit" or pass == "flat"
    local shadow_texture = pass == "lit" and _lighting.shadow_texture() or nil

    local ok, err = pcall(draw_meshes, model, shader, buffer, n, lit_pass, shadow_texture)
    if not ok then
        if not warned_bulk then
            warned_bulk = true
            if log then log("error", "bulk draw failed: " .. tostring(err)) end
        end
        return false
    end
    return true
end

--- Builds a custom model mesh from raw vertex and normal arrays.
--- @param opts table { key, vertices, normals }
--- @return Model|nil
function m.build(opts)
    local vertices = opts.vertices
    local normals = opts.normals
    local v_count = #vertices / 3

    -- Allocate and fully zero-initialize the Mesh struct to clear garbage pointers
    local mesh = _ffi.new("Mesh")
    _ffi.fill(mesh, _ffi.sizeof("Mesh"))

    mesh.vertexCount = v_count
    mesh.triangleCount = v_count / 3

    -- Vertices
    mesh.vertices = _rl.MemAlloc(v_count * 3 * _ffi.sizeof("float"))
    local v_ptr = _ffi.cast("float*", mesh.vertices)
    for i = 1, #vertices do
        v_ptr[i - 1] = vertices[i]
    end

    -- Normals
    if normals and #normals > 0 then
        mesh.normals = _rl.MemAlloc(#normals * _ffi.sizeof("float"))
        local n_ptr = _ffi.cast("float*", mesh.normals)
        for i = 1, #normals do
            n_ptr[i - 1] = normals[i]
        end
    end

    -- Texcoords (Required by shader attribute stream)
    mesh.texcoords = _rl.MemAlloc(v_count * 2 * _ffi.sizeof("float"))
    local tc_ptr = _ffi.cast("float*", mesh.texcoords)
    for i = 1, v_count * 2 do
        tc_ptr[i - 1] = 0.0
    end

    -- Colors (Required by shader attribute stream)
    mesh.colors = _rl.MemAlloc(v_count * 4 * _ffi.sizeof("unsigned char"))
    local c_ptr = _ffi.cast("unsigned char*", mesh.colors)
    for i = 1, v_count * 4 do
        c_ptr[i - 1] = 255
    end

    -- Upload mesh safely to GPU
    _rl.UploadMesh(mesh, false)
    return _rl.LoadModelFromMesh(mesh)
end

--- @section Exported Helpers

--- Resolves a colour input into a native FFI Color.
--- @param c string|table|cdata
--- @return cdata Color
function m.resolve_colour(c)
    return resolve_colour(c)
end

return m