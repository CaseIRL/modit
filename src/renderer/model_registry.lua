--- @class ModelRegistry
--- @file src/renderer/model_registry.lua
--- @description Model asset loading/cache and retained Model objects.
--[[
    Notes:

    Models are world objects. They draw inside the scene's camera, so the scene
    needs a camera created with mode = "3d" and set with modit.graphics.set_camera.
    Many instances share one cached asset, each owns its own transform and tint.
    Animation is not supported yet: UpdateModelAnimation rewrites the asset's vertex
    buffers, so animated models will need their own uncached copy.
]]

--- @section Imports

local _model = require("src.renderer.model")
local _fs = require("src.core.filesystem")

--- @section Asset Methods

local AssetMethods = {}
AssetMethods.__index = AssetMethods

--- Unloads the model from memory and drops it from the cache.
--- Instances still using it stop drawing.
function AssetMethods:unload()
    if self.handle then
        _model.unload_model(self.handle)
        self.handle = nil
    end
    if self.registry and self.registry.assets[self.cache_key] == self then
        self.registry.assets[self.cache_key] = nil
    end
end

--- @section Helpers

--- Builds an asset table from a loaded raylib model.
--- @param self table Registry
--- @param handle cdata Model
--- @param cache_key string
--- @param path string|nil
--- @return table Asset
local function make_asset(self, handle, cache_key, path)
    local min_x, min_y, min_z, max_x, max_y, max_z = _model.get_model_bounds(handle)
    local asset = setmetatable({
        handle = handle,
        path = path,
        cache_key = cache_key,
        min = { x = min_x, y = min_y, z = min_z },
        max = { x = max_x, y = max_y, z = max_z },
        registry = self,
    }, AssetMethods)

    self.assets[cache_key] = asset
    return asset
end

--- Rebuilds the instance matrix when its transform changed.
--- @param obj table Model object
local function refresh_matrix(obj)
    if not obj.dirty then return end
    _model.set_transform(obj.matrix, obj.x, obj.y, obj.z, obj.rx, obj.ry, obj.rz, obj.sx, obj.sy, obj.sz)
    obj.dirty = false
end

--- Draws one Model object..
--- @param obj table Model object
local function render_model(obj)
    local asset = obj.asset
    local handle = asset and asset.handle
    if not handle then return end

    refresh_matrix(obj)
    _model.draw_model(handle, obj.matrix, obj.tint, obj.unlit, obj.shader and obj.shader.handle)
end

--- Renders the models shadow.
--- @param obj table Model object
local function render_shadow(obj)
    local handle = obj.asset and obj.asset.handle
    if not handle then return end

    refresh_matrix(obj)
    _model.draw_model(handle, obj.matrix, obj.tint, true)
end

--- @section Constructor

local ModelRegistry = {}
ModelRegistry.__index = ModelRegistry

--- Creates a new ModelRegistry instance.
--- @return ModelRegistry
function ModelRegistry.new()
    local self = setmetatable({}, ModelRegistry)
    self.scenes = {}
    self.assets = {}
    self.active_scene = "default"
    self.next_id = 1
    self.root = "."
    return self
end

--- @section Scene

--- Sets the active scene context.
--- @param scene_name string|nil
function ModelRegistry:set_active_scene(scene_name)
    self.active_scene = scene_name or "default"
    if not self.scenes[self.active_scene] then
        self.scenes[self.active_scene] = {}
    end
end

--- Clears all model objects in a scene.
--- @param scene_name string
function ModelRegistry:clear_scene(scene_name)
    if self.scenes[scene_name] then
        self.scenes[scene_name] = {}
    end
end

--- Placeholder so scenes can update every registry the same way. Models do not animate yet.
--- @param dt number
--- @param scene_name string|nil
function ModelRegistry:update(dt, scene_name)
end

--- @section Assets

--- Loads a model from the project root, or returns it from the cache.
--- @param path string
--- @return ModelAsset|nil
function ModelRegistry:load_model(path)
    if not path or path == "" then return nil end

    local cached = self.assets[path]
    if cached then return cached end

    local resolved = _fs.resolve(path, { self.root, "." })
    if not resolved then
        log("warn", "Failed to resolve model path", { path = path, root = self.root })
        return nil
    end

    local handle = _model.load_model(resolved)
    if not _model.is_model_valid(handle) then
        log("warn", "Failed to load model", { path = path, resolved = resolved })
        return nil
    end

    local asset = make_asset(self, handle, path, resolved)

    log("info", "Model loaded", {
        path = path,
        meshes = handle.meshCount,
        materials = handle.materialCount,
        size = string.format("%.2f x %.2f x %.2f", asset.max.x - asset.min.x, asset.max.y - asset.min.y, asset.max.z - asset.min.z),
        min = string.format("%.2f, %.2f, %.2f", asset.min.x, asset.min.y, asset.min.z),
    })

    return asset
end

--- Loads a unit primitive ("cube", "sphere", "plane", "cylinder"), or returns it from the cache.
--- @param name string
--- @return ModelAsset|nil
function ModelRegistry:load_primitive(name)
    local cache_key = "primitive:" .. tostring(name)
    local cached = self.assets[cache_key]
    if cached then return cached end

    local handle = _model.load_primitive(name)
    if not handle or not _model.is_model_valid(handle) then
        log("warn", "Unknown or invalid model primitive", { primitive = name })
        return nil
    end

    return make_asset(self, handle, cache_key, nil)
end

--- Unloads every cached model.
function ModelRegistry:cleanup_models()
    for _, asset in pairs(self.assets) do
        if asset.handle then
            _model.unload_model(asset.handle)
            asset.handle = nil
        end
    end
    self.assets = {}
end

--- @section Models

--- Adds a retained model to the active scene.
--- Rotation is euler degrees { pitch, yaw, roll }. Scale is a number or { x, y, z }.
--- @param config table { path|primitive|model, x, y, z, position, rotation, scale, colour, owner }
--- @return ModelObjectHandle|nil
function ModelRegistry:add(config)
    config = config or {}

    local pool = self.scenes[self.active_scene]
    if not pool then
        pool = {}
        self.scenes[self.active_scene] = pool
    end

    local asset = config.model
    if not asset then
        if config.primitive then
            asset = self:load_primitive(config.primitive)
        elseif config.path then
            asset = self:load_model(config.path)
        end
    end

    if not asset then
        log("warn", "Model not added, no valid path or primitive", { path = config.path, primitive = config.primitive })
        return nil
    end

    local id = self.next_id
    self.next_id = self.next_id + 1

    local pos = config.position or {}
    local rot = config.rotation or {}
    local scale = config.scale or 1
    local sx, sy, sz
    if type(scale) == "table" then
        sx, sy, sz = scale.x or scale[1] or 1, scale.y or scale[2] or 1, scale.z or scale[3] or 1
    else
        sx, sy, sz = scale, scale, scale
    end

    local obj = {
        id = id,
        scene = self.active_scene,
        owner = config.owner,
        asset = asset,
        x = config.x or pos.x or pos[1] or 0,
        y = config.y or pos.y or pos[2] or 0,
        z = config.z or pos.z or pos[3] or 0,
        rx = rot.x or rot[1] or 0,
        ry = rot.y or rot[2] or 0,
        rz = rot.z or rot[3] or 0,
        sx = sx,
        sy = sy,
        sz = sz,
        tint = _model.resolve_colour(config.tint or config.colour or config.color or "white"),
        layer = config.layer or 0,
        space = "world",
        active = true,
        cast_shadow = config.cast_shadow ~= false,
        unlit = config.unlit == true,
        shader = config.shader,
        render_shadow = render_shadow,
        render = render_model,
        registry = self,

        matrix = _model.new_matrix(),
        dirty = true,
    }

    function obj:remove()
        self.registry:remove_model(self.scene, self.id)
    end

    function obj:set_position(x, y, z)
        self.x, self.y, self.z = x, y, z
        self.dirty = true
    end

    function obj:get_position()
        return self.x, self.y, self.z
    end

    function obj:set_rotation(x, y, z)
        self.rx, self.ry, self.rz = x, y, z
        self.dirty = true
    end

    function obj:set_scale(x, y, z)
        self.sx, self.sy, self.sz = x, y or x, z or x
        self.dirty = true
    end

    function obj:set_colour(colour)
        self.tint = _model.resolve_colour(colour)
    end

    function obj:set_visible(visible)
        self.active = visible and true or false
    end

    function obj:set_cast_shadow(flag)
        self.cast_shadow = flag and true or false
    end

    function obj:set_unlit(flag)
        self.unlit = flag and true or false
    end

    function obj:set_shader(shader)
        self.shader = shader
    end

    function obj:get_bounds()
        local a = self.asset
        if not a or not a.handle then return 0, 0, 0, 0, 0, 0 end
        refresh_matrix(self)

        local mat = self.matrix
        local lo, hi = a.min, a.max
        local min_x, min_y, min_z = math.huge, math.huge, math.huge
        local max_x, max_y, max_z = -math.huge, -math.huge, -math.huge

        for i = 0, 7 do
            local cx = (i % 2 == 0) and lo.x or hi.x
            local cy = (math.floor(i / 2) % 2 == 0) and lo.y or hi.y
            local cz = (i < 4) and lo.z or hi.z

            local wx = mat.m0 * cx + mat.m4 * cy + mat.m8 * cz + mat.m12
            local wy = mat.m1 * cx + mat.m5 * cy + mat.m9 * cz + mat.m13
            local wz = mat.m2 * cx + mat.m6 * cy + mat.m10 * cz + mat.m14

            if wx < min_x then min_x = wx end
            if wy < min_y then min_y = wy end
            if wz < min_z then min_z = wz end
            if wx > max_x then max_x = wx end
            if wy > max_y then max_y = wy end
            if wz > max_z then max_z = wz end
        end

        return min_x, min_y, min_z, max_x, max_y, max_z
    end

    pool[id] = obj
    _G.render_list:add(self.active_scene, obj)
    return obj
end

--- Removes a model from the scene pool by ID.
--- @param scene_name string
--- @param id number
function ModelRegistry:remove_model(scene_name, id)
    local pool = self.scenes[scene_name]
    local obj = pool and pool[id]
    if obj then
        pool[id] = nil
        _G.render_list:remove(scene_name, obj)
    end
end

--- Removes every model created by an owner across all scenes.
--- @param owner string
function ModelRegistry:remove_owner(owner)
    for scene_name, pool in pairs(self.scenes) do
        for id, obj in pairs(pool) do
            if obj.owner == owner then
                pool[id] = nil
                _G.render_list:remove(scene_name, obj)
            end
        end
    end
end

return ModelRegistry