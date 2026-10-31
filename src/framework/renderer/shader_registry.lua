--- @class ShaderRegistry
--- @file src/framework/renderer/shader_registry.lua
--- @description Shader asset loading/cache and utility methods.

--- @section Imports

local _shader = require("src.framework.renderer.shader")
local _fs = require("src.framework.core.filesystem")

--- @section Shader Methods

local ShaderMethods = {}
ShaderMethods.__index = ShaderMethods

--- Unloads the shader from VRAM and drops it from the cache.
function ShaderMethods:unload()
    if self.handle then
        _shader.unload_shader(self.handle)
        self.handle = nil
    end
    if self.registry and self.registry.shaders[self.cache_key] == self then
        self.registry.shaders[self.cache_key] = nil
    end
end

--- Gets a uniform location by name.
--- @param uniform_name string
--- @return number
function ShaderMethods:get_location(uniform_name)
    if not self.handle then return -1 end
    return _shader.get_shader_location(self.handle, uniform_name)
end

--- Sets a uniform value by name or location index.
--- @param loc_index string|number
--- @param value number|table|cdata
--- @param uniform_type string|number
function ShaderMethods:set_value(loc_index, value, uniform_type)
    if not self.handle then return end
    if type(loc_index) == "string" then
        loc_index = self:get_location(loc_index)
    end
    if loc_index < 0 then return end
    _shader.set_shader_value(self.handle, loc_index, value, uniform_type)
end

--- Sets a vector array uniform.
--- @param loc_index string|number
--- @param value cdata
--- @param uniform_type string|number
--- @param count number
function ShaderMethods:set_value_v(loc_index, value, uniform_type, count)
    if not self.handle then return end
    if type(loc_index) == "string" then
        loc_index = self:get_location(loc_index)
    end
    if loc_index < 0 then return end
    _shader.set_shader_value_v(self.handle, loc_index, value, uniform_type, count)
end

--- Sets a 4x4 matrix uniform.
--- @param loc_index string|number
--- @param mat cdata Matrix
function ShaderMethods:set_matrix(loc_index, mat)
    if not self.handle then return end
    if type(loc_index) == "string" then
        loc_index = self:get_location(loc_index)
    end
    if loc_index < 0 then return end
    _shader.set_shader_value_matrix(self.handle, loc_index, mat)
end

--- Sets a sampler2D texture uniform.
--- @param loc_index string|number
--- @param texture Texture2D|table
function ShaderMethods:set_texture(loc_index, texture)
    if not self.handle then return end
    if type(loc_index) == "string" then
        loc_index = self:get_location(loc_index)
    end
    if loc_index < 0 then return end
    _shader.set_shader_value_texture(self.handle, loc_index, texture)
end

--- @section Constructor

local ShaderRegistry = {}
ShaderRegistry.__index = ShaderRegistry

--- Creates a new ShaderRegistry instance.
--- @return ShaderRegistry
function ShaderRegistry.new()
    local self = setmetatable({}, ShaderRegistry)
    self.shaders = {}
    self.root = "."
    return self
end

--- @section Methods

--- Loads a shader from vertex and fragment shader files, or returns from cache.
--- @param vs_path string|nil
--- @param fs_path string|nil
--- @return ShaderAsset|nil
function ShaderRegistry:load_shader(vs_path, fs_path)
    local cache_key = (vs_path or "nil") .. "|" .. (fs_path or "nil")
    local cached = self.shaders[cache_key]
    if cached then return cached end

    local resolved_vs = vs_path and _fs.resolve(vs_path, { self.root, "." }) or nil
    local resolved_fs = fs_path and _fs.resolve(fs_path, { self.root, "." }) or nil

    local handle = _shader.load_shader(resolved_vs, resolved_fs)
    if not _shader.is_shader_valid(handle) then
        log("warn", "Failed to load shader", { vs = vs_path, fs = fs_path })
        return nil
    end

    local asset = setmetatable({
        handle = handle,
        vs_path = vs_path,
        fs_path = fs_path,
        cache_key = cache_key,
        registry = self,
    }, ShaderMethods)

    self.shaders[cache_key] = asset
    log("info", "Shader loaded", { vs = vs_path, fs = fs_path })
    return asset
end

--- Loads a shader from code strings in memory.
--- @param vs_code string
--- @param fs_code string
--- @param cache_key string|nil
--- @return ShaderAsset|nil
function ShaderRegistry:load_shader_from_memory(vs_code, fs_code, cache_key)
    cache_key = cache_key or ("mem:" .. vs_code .. "|" .. fs_code)
    local cached = self.shaders[cache_key]
    if cached then return cached end

    local handle = _shader.load_shader_from_memory(vs_code, fs_code)
    if not _shader.is_shader_valid(handle) then
        log("warn", "Failed to load shader from memory")
        return nil
    end

    local asset = setmetatable({
        handle = handle,
        cache_key = cache_key,
        registry = self,
    }, ShaderMethods)

    self.shaders[cache_key] = asset
    log("info", "Shader loaded from memory", { key = cache_key })
    return asset
end

--- Unloads every cached shader.
function ShaderRegistry:cleanup_shaders()
    for _, asset in pairs(self.shaders) do
        if asset.handle then
            _shader.unload_shader(asset.handle)
            asset.handle = nil
        end
    end
    self.shaders = {}
end

return ShaderRegistry