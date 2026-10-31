--- @module lighting
--- @file src/framework/renderer/lighting.lua
--- @description Lit mesh shader, projected shadow shader, shadow-map depth pass and blob discs.
--[[
    Notes:

    Meshes only. 
    Models pick their shader from mesh_shader(), so there is no BeginShaderMode here.
    Bulk (GPU instanced) draws pick theirs from instance_shader(). Every pass has an instanced twin
    (lit, depth, projected shadow) and the lit pass uploads sun, ambient, fog and the shadow map to both
    lit programs. Per instance colour travels in the unused bottom row of each instance matrix (m3, m7, m11)
    as r, g, b in 0-1, the instanced vertex shaders clear that row again before transforming.
    Everything is lit in world space: one sun, one ambient colour, distance fog.
    Shadow modes:
        map - depth pass from the sun into a render texture, sampled by the lit shader.
        projected - casters are flattened along the sun onto a ground plane as black alpha.
        blob - soft flat discs, drawn by the caller through blob_disc.
    Matrices are 16 numbers in raylib memory order (column-major, translation in 13-15).
]]

--- @section Imports

local _raylib = require("src.framework.bindings.raylib")
local _ffi = _raylib.ffi
local _rl = _raylib.lib

--- @section Constants

local UNIFORM_VEC2 = 1
local UNIFORM_VEC3 = 2
local UNIFORM_VEC4 = 3

local LOC_MAP_BRDF = 25
local LOC_INSTANCE_TX = 29
local WRAP_CLAMP = 1
local BLOB_SLICES = 12
local BLOB_HEIGHT = 0.001

local LIT_VERTEX = [[
#version 330
in vec3 vertexPosition;
in vec3 vertexNormal;
in vec2 vertexTexCoord;
in vec4 vertexColor;
uniform mat4 mvp;
uniform mat4 matView;
uniform mat4 matModel;
uniform mat4 matNormal;
uniform mat4 lightVP;
out vec2 fragTexCoord;
out vec4 fragColor;
out vec3 viewPos;
out vec3 worldPos;
out vec3 worldNormal;
out vec4 lightPos;
void main() {
    vec4 world = matModel * vec4(vertexPosition, 1.0);
    worldPos = world.xyz;
    worldNormal = mat3(matNormal) * vertexNormal;
    viewPos = (matView * world).xyz;
    lightPos = lightVP * world;
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
]]

local LIT_FRAGMENT = [[
#version 330
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 viewPos;
in vec3 worldPos;
in vec3 worldNormal;
in vec4 lightPos;
uniform sampler2D texture0;
uniform sampler2D shadowMap;
uniform vec4 colDiffuse;
uniform vec4 meshParams;
uniform vec3 sunDir;
uniform vec3 sunColour;
uniform vec3 ambient;
uniform vec3 fogColour;
uniform vec2 fogRange;
uniform vec4 shadowParams;
out vec4 finalColor;
float unpack_depth(vec3 c) {
    return dot(c, vec3(1.0, 1.0 / 255.0, 1.0 / 65025.0));
}
void main() {
    vec4 base = texture(texture0, fragTexCoord) * colDiffuse * fragColor;

    // Mesh normals when the mesh has them, otherwise flat faces from screen derivatives.
    vec3 n = cross(dFdx(worldPos), dFdy(worldPos));
    if (meshParams.x > 0.5 && dot(worldNormal, worldNormal) > 1e-10) {
        n = gl_FrontFacing ? worldNormal : -worldNormal;
    }
    float len = length(n);
    float ndl = len > 1e-10 ? max(dot(n / len, -sunDir), 0.0) : 1.0;

    float sun_vis = 1.0;
    if (shadowParams.w > 0.5) {
        vec3 proj = lightPos.xyz / lightPos.w * 0.5 + 0.5;
        if (proj.x > 0.0 && proj.x < 1.0 && proj.y > 0.0 && proj.y < 1.0 && proj.z < 1.0) {
            float bias = (0.05 + 0.3 * (1.0 - ndl)) / shadowParams.y;
            float vis = 0.0;
            for (int x = -1; x <= 1; x++) {
                for (int y = -1; y <= 1; y++) {
                    vec2 uv = proj.xy + vec2(float(x), float(y)) * shadowParams.x;
                    float d = unpack_depth(textureLod(shadowMap, uv, 0.0).rgb);
                    vis += (proj.z - bias <= d) ? 1.0 : 0.0;
                }
            }
            sun_vis = mix(1.0 - shadowParams.z, 1.0, vis / 9.0);
            vec2 edge = min(proj.xy, 1.0 - proj.xy);
            float fade = smoothstep(0.0, 0.1, min(edge.x, edge.y));
            sun_vis = mix(1.0, sun_vis, fade);
        }
    }

    vec3 lit = base.rgb * min(ambient + sunColour * ndl * sun_vis, vec3(1.5));
    float fog = clamp((-viewPos.z - fogRange.x) / (fogRange.y - fogRange.x), 0.0, 1.0);
    finalColor = vec4(mix(lit, fogColour, fog), 1.0);
}
]]

local SHADOW_VERTEX = [[
#version 330
in vec3 vertexPosition;
uniform mat4 matProjection;
uniform mat4 matView;
uniform mat4 matModel;
uniform vec3 sunWorld;
uniform vec4 shadow;
out vec3 viewPos;
void main() {
    vec3 p = (matModel * vec4(vertexPosition, 1.0)).xyz;
    p += sunWorld * ((shadow.x - p.y) / sunWorld.y);
    viewPos = (matView * vec4(p, 1.0)).xyz;
    gl_Position = matProjection * matView * vec4(p, 1.0);
}
]]

local SHADOW_FRAGMENT = [[
#version 330
in vec3 viewPos;
uniform vec4 shadow;
out vec4 finalColor;
void main() {
    float fog = clamp((-viewPos.z - shadow.z) / (shadow.w - shadow.z), 0.0, 1.0);
    finalColor = vec4(0.0, 0.0, 0.0, shadow.y * (1.0 - fog));
}
]]

local DEPTH_VERTEX = [[
#version 330
in vec3 vertexPosition;
uniform mat4 matModel;
uniform mat4 lightVP;
void main() {
    gl_Position = lightVP * (matModel * vec4(vertexPosition, 1.0));
}
]]

local DEPTH_FRAGMENT = [[
#version 330
out vec4 finalColor;
vec3 pack_depth(float d) {
    vec3 enc = fract(d * vec3(1.0, 255.0, 65025.0));
    enc -= enc.yzz * vec3(1.0 / 255.0, 1.0 / 255.0, 0.0);
    return enc;
}
void main() {
    finalColor = vec4(pack_depth(clamp(gl_FragCoord.z, 0.0, 0.99999)), 1.0);
}
]]

local INSTANCED_LIT_VERTEX = [[
#version 330
in vec3 vertexPosition;
in vec3 vertexNormal;
in vec2 vertexTexCoord;
in vec4 vertexColor;
in mat4 instanceTransform;

uniform mat4 mvp;
uniform mat4 matView;
uniform mat4 lightVP;
out vec2 fragTexCoord;
out vec4 fragColor;
out vec3 viewPos;
out vec3 worldPos;
out vec3 worldNormal;
out vec4 lightPos;

void main() {
    // Bottom row of the instance matrix carries the instance colour, see model.lua
    mat4 t = instanceTransform;
    vec3 tint = vec3(t[0].w, t[1].w, t[2].w);
    t[0].w = 0.0;
    t[1].w = 0.0;
    t[2].w = 0.0;

    vec4 world = t * vec4(vertexPosition, 1.0);
    worldPos = world.xyz;

    // Cofactor matrix: the normal matrix up to a scale, correct for non uniform scale and uses the instance rotation
    mat3 m = mat3(t);
    vec3 n = mat3(cross(m[1], m[2]), cross(m[2], m[0]), cross(m[0], m[1])) * vertexNormal;
    worldNormal = dot(n, n) > 0.0 ? normalize(n) : vec3(0.0);

    viewPos = (matView * world).xyz;
    lightPos = lightVP * world;
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor * vec4(tint, 1.0);
    gl_Position = mvp * world;
}
]]

local INSTANCED_DEPTH_VERTEX = [[
#version 330
in vec3 vertexPosition;
in mat4 instanceTransform;
uniform mat4 lightVP;
void main() {
    mat4 t = instanceTransform;
    t[0].w = 0.0;
    t[1].w = 0.0;
    t[2].w = 0.0;
    gl_Position = lightVP * (t * vec4(vertexPosition, 1.0));
}
]]

local INSTANCED_SHADOW_VERTEX = [[
#version 330
in vec3 vertexPosition;
in mat4 instanceTransform;
uniform mat4 mvp;
uniform mat4 matView;
uniform vec3 sunWorld;
uniform vec4 shadow;
out vec3 viewPos;
void main() {
    mat4 t = instanceTransform;
    t[0].w = 0.0;
    t[1].w = 0.0;
    t[2].w = 0.0;
    vec3 p = (t * vec4(vertexPosition, 1.0)).xyz;
    p += sunWorld * ((shadow.x - p.y) / sunWorld.y);
    viewPos = (matView * vec4(p, 1.0)).xyz;
    gl_Position = mvp * vec4(p, 1.0);
}
]]

--- @section State

local buf2 = _ffi.new("float[2]")
local buf3 = _ffi.new("float[3]")
local buf4 = _ffi.new("float[4]")

local matrix = _ffi.new("Matrix")
local matrix_floats = _ffi.cast("float*", matrix)

local map_camera = _ffi.new("Camera3D")
map_camera.up.y = 1
map_camera.position.z = 1
map_camera.fovy = 45
local map_clear = _ffi.new("Color", 255, 255, 255, 255)

local blob_pos = _ffi.new("Vector3")
local blob_colour = _ffi.new("Color", 0, 0, 0, 255)

local map_target = nil
local map_size = 0

local mode = nil
local receiving = false
local instance_flat = false

local lit = {
    name = "lit", vertex = LIT_VERTEX, fragment = LIT_FRAGMENT, probe = "sunDir", shadow_map = true,
    uniforms = { "sunDir", "sunColour", "ambient", "fogColour", "fogRange", "lightVP", "shadowParams", "meshParams" },
}
local shadow = {
    name = "shadow", vertex = SHADOW_VERTEX, fragment = SHADOW_FRAGMENT, probe = "sunWorld",
    uniforms = { "sunWorld", "shadow" },
}
local depth = {
    name = "depth", vertex = DEPTH_VERTEX, fragment = DEPTH_FRAGMENT, probe = "lightVP",
    uniforms = { "lightVP" },
}
local instance_lit = {
    name = "instance_lit", vertex = INSTANCED_LIT_VERTEX, fragment = LIT_FRAGMENT, probe = "sunDir",
    instanced = true, shadow_map = true,
    uniforms = { "sunDir", "sunColour", "ambient", "fogColour", "fogRange", "lightVP", "shadowParams", "meshParams" },
}
local instance_depth = {
    name = "instance_depth", vertex = INSTANCED_DEPTH_VERTEX, fragment = DEPTH_FRAGMENT, probe = "lightVP",
    instanced = true,
    uniforms = { "lightVP" },
}
local instance_shadow = {
    name = "instance_shadow", vertex = INSTANCED_SHADOW_VERTEX, fragment = SHADOW_FRAGMENT, probe = "sunWorld",
    instanced = true,
    uniforms = { "sunWorld", "shadow" },
}

local PROGRAMS = { lit, shadow, depth, instance_lit, instance_depth, instance_shadow }

-- Programs that run the lit fragment shader, they all get the same sun, ambient, fog and shadow map
local LIT_PROGRAMS = { lit, instance_lit }

--- @section Helpers

local function set_vec2(program, name, x, y)
    buf2[0], buf2[1] = x, y
    _rl.SetShaderValue(program.shader, program.locs[name], buf2, UNIFORM_VEC2)
end

local function set_vec3(program, name, x, y, z)
    buf3[0], buf3[1], buf3[2] = x, y, z
    _rl.SetShaderValue(program.shader, program.locs[name], buf3, UNIFORM_VEC3)
end

local function set_vec4(program, name, x, y, z, w)
    buf4[0], buf4[1], buf4[2], buf4[3] = x, y, z, w
    _rl.SetShaderValue(program.shader, program.locs[name], buf4, UNIFORM_VEC4)
end

local function set_matrix(program, name, v)
    matrix.m0, matrix.m1, matrix.m2, matrix.m3 = v[1], v[2], v[3], v[4]
    matrix.m4, matrix.m5, matrix.m6, matrix.m7 = v[5], v[6], v[7], v[8]
    matrix.m8, matrix.m9, matrix.m10, matrix.m11 = v[9], v[10], v[11], v[12]
    matrix.m12, matrix.m13, matrix.m14, matrix.m15 = v[13], v[14], v[15], v[16]
    _rl.SetShaderValueMatrix(program.shader, program.locs[name], matrix)
end

local function ensure(program)
    if program.shader then return true end
    if program.failed then return false end

    local loaded = _rl.LoadShaderFromMemory(program.vertex, program.fragment)
    if _rl.GetShaderLocation(loaded, program.probe) < 0 then
        _rl.UnloadShader(loaded)
        program.failed = true
        log("warn", "Lighting shader failed to compile", { program = program.name })
        return false
    end

    program.shader = loaded
    program.locs = {}
    for _, name in ipairs(program.uniforms) do
        program.locs[name] = _rl.GetShaderLocation(loaded, name)
    end
    if program.shadow_map then
        loaded.locs[LOC_MAP_BRDF] = _rl.GetShaderLocation(loaded, "shadowMap")
    end
    if program.instanced then
        loaded.locs[LOC_INSTANCE_TX] = _rl.GetShaderLocationAttrib(loaded, "instanceTransform")
    end
    return true
end

--- Uploads the sun, ambient and fog to one lit program.
--- @param program table
--- @param sun table
--- @param ambient table
--- @param fog table
local function upload_scene(program, sun, ambient, fog)
    set_vec3(program, "sunDir", sun.dx, sun.dy, sun.dz)
    set_vec3(program, "sunColour", sun.r, sun.g, sun.b)
    set_vec3(program, "ambient", ambient.r, ambient.g, ambient.b)
    set_vec3(program, "fogColour", fog.r, fog.g, fog.b)
    set_vec2(program, "fogRange", fog.near, fog.far)
    set_vec4(program, "shadowParams", 0, 1, 0, 0)
end

--- @section Lit Pass

local m = {}

--- Uploads the sun, ambient and fog to the lit shader and starts a lit pass.
--- @param sun table { dx, dy, dz, r, g, b } direction the light travels, colour 0-1
--- @param ambient table { r, g, b } 0-1
--- @param fog table { near, far, r, g, b } colour 0-1
--- @return boolean started
function m.begin(sun, ambient, fog)
    if not ensure(lit) then return false end

    upload_scene(lit, sun, ambient, fog)
    if ensure(instance_lit) then
        upload_scene(instance_lit, sun, ambient, fog)
    end
    instance_flat = false

    mode, receiving = "lit", false
    return true
end

--- Ends the lit pass. Call right before the camera mode ends.
function m.finish()
    mode, receiving = nil, false
end

--- Gets the shader a mesh must use right now.
--- @param unlit boolean|nil Skip lighting for this mesh (it still casts shadows)
--- @return cdata|nil shader nil means leave the material's own shader alone
function m.mesh_shader(unlit)
    if mode == "map" then return depth.shader end
    if mode == "shadow" then return shadow.shader end
    if mode == "lit" and not unlit then return lit.shader end
    return nil
end

--- Tells the lit shader whether the next mesh has real normals.
--- @param smooth boolean
--- @param instanced boolean|nil Target the instanced lit program
function m.set_mesh(smooth, instanced)
    if mode == "lit" then
        set_vec4(instanced and instance_lit or lit, "meshParams", smooth and 1 or 0, 0, 0, 0)
    elseif instanced and mode == nil and instance_lit.shader then
        set_vec4(instance_lit, "meshParams", smooth and 1 or 0, 0, 0, 0)
    end
end

--- True while casters are being drawn into a shadow pass.
--- @return boolean
function m.is_shadow_pass()
    return mode == "shadow" or mode == "map"
end

--- @section Projected Shadows

--- Switches to the projected shadow shader. Must be inside a lit pass.
--- @param sun table { dx, dy, dz } dy must be negative
--- @param plane_y number World Y the shadows land on
--- @param strength number Opacity 0-1
--- @param fog table { near, far }
--- @return boolean started
function m.shadow_begin(sun, plane_y, strength, fog)
    if mode ~= "lit" or not ensure(shadow) then return false end

    set_vec3(shadow, "sunWorld", sun.dx, sun.dy, sun.dz)
    set_vec4(shadow, "shadow", plane_y, strength, fog.near, fog.far)
    if ensure(instance_shadow) then
        set_vec3(instance_shadow, "sunWorld", sun.dx, sun.dy, sun.dz)
        set_vec4(instance_shadow, "shadow", plane_y, strength, fog.near, fog.far)
    end
    mode = "shadow"
    return true
end

--- Returns to the lit pass.
function m.shadow_end()
    if mode == "shadow" then mode = "lit" end
end

--- @section Shadow Map

--- Starts the depth pass from the sun. Must be called outside any texture or camera mode.
--- @param size number Shadow map width and height in pixels
--- @param light_vp table 16 numbers, light projection * light view
--- @return boolean started
function m.map_begin(size, light_vp)
    if mode ~= nil or not ensure(depth) then return false end

    if not map_target or map_size ~= size then
        if map_target then _rl.UnloadRenderTexture(map_target) end
        map_target = _rl.LoadRenderTexture(size, size)
        _rl.SetTextureFilter(map_target.texture, _ffi.C.TEXTURE_FILTER_POINT)
        _rl.SetTextureWrap(map_target.texture, WRAP_CLAMP)
        map_size = size
    end

    set_matrix(depth, "lightVP", light_vp)
    if ensure(instance_depth) then
        set_matrix(instance_depth, "lightVP", light_vp)
    end

    _rl.BeginTextureMode(map_target)
    _rl.ClearBackground(map_clear)
    _rl.BeginMode3D(map_camera)
    mode = "map"
    return true
end

--- Ends the depth pass.
function m.map_end()
    mode = nil
    _rl.EndMode3D()
    _rl.EndTextureMode()
end

--- Hands the finished shadow map to the lit pass. Call after begin.
--- @param light_vp table 16 numbers, light projection * light view
--- @param texel number One shadow-map texel in UV units
--- @param depth_range number Depth covered by the light in world units
--- @param strength number Shadow opacity 0-1
function m.map_receive(light_vp, texel, depth_range, strength)
    if mode ~= "lit" or not map_target then return end

    for i = 1, #LIT_PROGRAMS do
        local program = LIT_PROGRAMS[i]
        if program.shader then
            set_matrix(program, "lightVP", light_vp)
            set_vec4(program, "shadowParams", texel, depth_range, strength, 1)
        end
    end
    receiving = true
end

--- Gets the shadow map texture meshes must bind right now.
--- @return cdata|nil texture nil when meshes receive no map shadows
function m.shadow_texture()
    if receiving and map_target then return map_target.texture end
    return nil
end

--- @section Blob Shadows

--- Draws one flat black disc.
--- @param x number Centre X
--- @param y number Ground Y
--- @param z number Centre Z
--- @param radius number
--- @param alpha number Opacity 0-1
function m.blob_disc(x, y, z, radius, alpha)
    blob_pos.x, blob_pos.y, blob_pos.z = x, y, z
    blob_colour.a = math.floor(math.max(0, math.min(1, alpha)) * 255)
    _rl.DrawCylinder(blob_pos, radius, radius, BLOB_HEIGHT, BLOB_SLICES, blob_colour)
end

--- @section Shaders

--- Gets the instanced shader a bulk draw must use right now.
--- Follows the same passes as mesh_shader: the sun's depth pass, projected shadows or the lit pass. Outside a lit
--- pass (lighting off, or drawn immediately) the lit program is switched to flat colours so instances are not black.
--- @return cdata|nil shader nil means this pass cannot draw instances
--- @return string|nil pass "depth", "shadow", "lit" or "flat"
function m.instance_shader()
    if mode == "map" then
        if not ensure(instance_depth) then return nil end
        return instance_depth.shader, "depth"
    end

    if mode == "shadow" then
        if not ensure(instance_shadow) then return nil end
        return instance_shadow.shader, "shadow"
    end

    if not ensure(instance_lit) then return nil end
    if mode == "lit" then return instance_lit.shader, "lit" end

    if not instance_flat then
        set_vec3(instance_lit, "sunDir", 0, -1, 0)
        set_vec3(instance_lit, "sunColour", 0, 0, 0)
        set_vec3(instance_lit, "ambient", 1, 1, 1)
        set_vec3(instance_lit, "fogColour", 0, 0, 0)
        set_vec2(instance_lit, "fogRange", 1e5, 1e6)
        set_vec4(instance_lit, "shadowParams", 0, 1, 0, 0)
        instance_flat = true
    end
    return instance_lit.shader, "flat"
end

--- @section Cleanup

--- Releases every shader and the shadow map from VRAM.
function m.free()
    for _, program in ipairs(PROGRAMS) do
        if program.shader then _rl.UnloadShader(program.shader) end
        program.shader, program.locs, program.failed = nil, nil, nil
    end
    if map_target then
        _rl.UnloadRenderTexture(map_target)
        map_target, map_size = nil, 0
    end
    mode, receiving, instance_flat = nil, false, false
end

return m