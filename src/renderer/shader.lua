--- @module shader
--- @file src/renderer/shader.lua
--- @description Handles shader rendering.

--- @section Imports

local _raylib = require("src.bindings.raylib")
local _ffi = _raylib.ffi
local _rl = _raylib.lib

--- @section Initialisation

local m = {}

m.uniform_types = {
    ["float"] = 0,     -- SHADER_UNIFORM_FLOAT
    ["vec2"] = 1,      -- SHADER_UNIFORM_VEC2
    ["vec3"] = 2,      -- SHADER_UNIFORM_VEC3
    ["vec4"] = 3,      -- SHADER_UNIFORM_VEC4
    ["int"] = 4,       -- SHADER_UNIFORM_INT
    ["ivec2"] = 5,     -- SHADER_UNIFORM_IVEC2
    ["ivec3"] = 6,     -- SHADER_UNIFORM_IVEC3
    ["ivec4"] = 7,     -- SHADER_UNIFORM_IVEC4
    ["sampler2d"] = 8, -- SHADER_UNIFORM_SAMPLER2D
}

--- @section Helpers

local function resolve_uniform_type(t)
    if type(t) == "number" then return t end
    if type(t) == "string" then
        return m.uniform_types[t:lower()] or 0
    end
    return 0
end

--- @section Shader Loading & Unloading

--- Load shader from files and bind default locations.
--- @param vs_file_name string|nil
--- @param fs_file_name string|nil
--- @return Shader
function m.load_shader(vs_file_name, fs_file_name)
    return _rl.LoadShader(vs_file_name, fs_file_name)
end

--- Load shader from code strings and bind default locations.
--- @param vs_code string
--- @param fs_code string
--- @return Shader
function m.load_shader_from_memory(vs_code, fs_code)
    return _rl.LoadShaderFromMemory(vs_code, fs_code)
end

--- Check if shader is valid.
--- @param shader Shader
--- @return boolean
function m.is_shader_valid(shader)
    return _rl.IsShaderValid(shader)
end

--- Unload shader from GPU memory.
--- @param shader Shader
function m.unload_shader(shader)
    _rl.UnloadShader(shader)
end

--- @section Uniforms & Locations

--- Get shader uniform location.
--- @param shader Shader
--- @param uniform_name string
--- @return number
function m.get_shader_location(shader, uniform_name)
    return _rl.GetShaderLocation(shader, uniform_name)
end

--- Get shader attribute location.
--- @param shader Shader
--- @param attrib_name string
--- @return number
function m.get_shader_location_attrib(shader, attrib_name)
    return _rl.GetShaderLocationAttrib(shader, attrib_name)
end

--- Set shader uniform value.
--- @param shader Shader
--- @param loc_index number
--- @param value number|table|cdata
--- @param uniform_type string|number
function m.set_shader_value(shader, loc_index, value, uniform_type)
    local u_type = resolve_uniform_type(uniform_type)
    local cdata_val

    if type(value) == "number" then
        if u_type >= 4 and u_type <= 7 then
            cdata_val = _ffi.new("int[1]", value)
        else
            cdata_val = _ffi.new("float[1]", value)
        end
    elseif type(value) == "table" then
        if u_type == 1 or u_type == 5 then
            cdata_val = _ffi.new("Vector2", value.x or value[1] or 0, value.y or value[2] or 0)
        elseif u_type == 2 or u_type == 6 then
            cdata_val = _ffi.new("Vector3", value.x or value[1] or 0, value.y or value[2] or 0, value.z or value[3] or 0)
        elseif u_type == 3 or u_type == 7 then
            cdata_val = _ffi.new("Vector4", value.x or value[1] or 0, value.y or value[2] or 0, value.z or value[3] or 0, value.w or value[4] or 0)
        else
            cdata_val = _ffi.new("float[1]", value[1] or 0)
        end
    else
        cdata_val = value
    end

    _rl.SetShaderValue(shader, loc_index, cdata_val, u_type)
end

--- Set shader uniform value vector.
--- @param shader Shader
--- @param loc_index number
--- @param value cdata
--- @param uniform_type string|number
--- @param count number
function m.set_shader_value_v(shader, loc_index, value, uniform_type, count)
    local u_type = resolve_uniform_type(uniform_type)
    _rl.SetShaderValueV(shader, loc_index, value, u_type, count)
end

--- Set shader uniform value.
--- @param shader Shader
--- @param loc_index number
--- @param mat cdata Matrix
function m.set_shader_value_matrix(shader, loc_index, mat)
    _rl.SetShaderValueMatrix(shader, loc_index, mat)
end

--- Set shader uniform value and bind the texture.
--- @param shader Shader
--- @param loc_index number
--- @param texture Texture2D|table
function m.set_shader_value_texture(shader, loc_index, texture)
    local tex_handle = texture.handle or texture
    _rl.SetShaderValueTexture(shader, loc_index, tex_handle)
end

return m