--- @module model
--- @file src/renderer/model.lua
--- @description Model loading, meshes, and drawing.

--- @section Imports

local _raylib = require("src.bindings.raylib")
local _ffi = _raylib.ffi
local _rl = _raylib.lib

local _lighting = require("src.renderer.lighting")

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

--- @section Exported Helpers

--- Resolves a colour input into a native FFI Color.
--- @param c string|table|cdata
--- @return cdata Color
function m.resolve_colour(c)
    return resolve_colour(c)
end

return m