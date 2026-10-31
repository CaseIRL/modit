--- @class ImageRegistry
--- @file src/graphics/image_registry.lua
--- @description Texture loading/cache and retained Image objects.

--- @section Imports

local _image = require("src.framework.renderer.image")
local _fs = require("src.framework.core.filesystem")

--- @section Constants

local DEFAULT_FILTER = "point"
local DEFAULT_FPS = 8

--- @section Texture Methods

local TextureMethods = {}
TextureMethods.__index = TextureMethods

--- Unloads the texture from VRAM and drops it from the cache.
--- Images still using it stop drawing.
function TextureMethods:unload()
    if self.handle then
        _image.unload_texture(self.handle)
        self.handle = nil
    end
    if self.registry and self.registry.textures[self.cache_key] == self then
        self.registry.textures[self.cache_key] = nil
    end
end

--- @section Helpers

--- Reads an image into CPU memory from the project root, or from the bundle.
--- @param self table Registry
--- @param path string
--- @return cdata|nil Image
local function read_image(self, path)
    local resolved = _fs.resolve(path, { self.root, "." })
    if resolved then
        return _image.load_image(resolved)
    end

    local bundle = rawget(_G, "MODIT_BUNDLE")
    if bundle then
        local key = (path:gsub("\\", "/"):gsub("^%./", ""))
        if bundle.has(key) then
            local data = bundle.get(key)
            local ext = key:match("%.%w+$") or ".png"
            return _image.load_image_from_memory(ext, data, #data)
        end
    end

    return nil
end

--- Sets the source rectangle for the current animation frame or grid index.
--- @param img table Image object
local function apply_frame(img)
    local src = img.src
    local anim = img.anim

    if anim then
        src.x = (anim.x + img.frame_index - 1) * img.fw
        src.y = anim.y * img.fh
    elseif img.cols then
        local index = img.frame_index - 1
        src.x = (index % img.cols) * img.fw
        src.y = math.floor(index / img.cols) * img.fh
    end
end

--- Draws one Image object. Registered with the render list as obj:render().
--- @param img table Image object
local function render_image(img)
    local tex = img.texture and img.texture.handle
    if not tex then return end

    local src, dst, origin = img.src, img.dst, img.origin_v
    local dw = img.width or img.fw * img.scale
    local dh = img.height or img.fh * img.scale
    src.width = img.flip_x and -img.fw or img.fw
    src.height = img.flip_y and -img.fh or img.fh
    dst.x, dst.y = img.x, img.y
    dst.width, dst.height = dw, dh
    origin.x, origin.y = img.origin_x * dw / img.fw, img.origin_y * dh / img.fh

    _image.draw_texture_pro(tex, src, dst, origin, img.rotation, img.tint)
end

--- @section Constructor

local ImageRegistry = {}
ImageRegistry.__index = ImageRegistry

--- Creates a new ImageRegistry instance.
--- @return ImageRegistry
function ImageRegistry.new()
    local self = setmetatable({}, ImageRegistry)
    self.scenes = {}
    self.textures = {}
    self.active_scene = "default"
    self.next_id = 1
    self.root = "."
    return self
end

--- @section Scene

--- Sets the active scene context.
--- @param scene_name string|nil
function ImageRegistry:set_active_scene(scene_name)
    self.active_scene = scene_name or "default"
    if not self.scenes[self.active_scene] then
        self.scenes[self.active_scene] = {}
    end
end

--- Clears all image objects in a scene.
--- @param scene_name string
function ImageRegistry:clear_scene(scene_name)
    if self.scenes[scene_name] then
        self.scenes[scene_name] = {}
    end
end

--- Advances animations for a scene.
--- @param dt number
--- @param scene_name string|nil
function ImageRegistry:update(dt, scene_name)
    local pool = self.scenes[scene_name or self.active_scene]
    if not pool then return end

    for _, img in pairs(pool) do
        if img.playing and img.active then
            img:update(dt)
        end
    end
end

--- @section Textures

--- Loads a texture from the project root, or returns it from the cache.
--- @param path string
--- @param filter string|nil "point" (default), "bilinear" or "trilinear"
--- @return TextureObject|nil
function ImageRegistry:load_texture(path, filter)
    if not path or path == "" then return nil end
    filter = filter or DEFAULT_FILTER

    local cache_key = path .. "|" .. filter
    local cached = self.textures[cache_key]
    if cached then return cached end

    local img = read_image(self, path)
    if not img or not _image.is_image_valid(img) then
        log("warn", "Failed to load image", { path = path, root = self.root })
        return nil
    end

    local handle = _image.load_texture_from_image(img)
    _image.unload_image(img)

    if not _image.is_texture_valid(handle) then
        log("warn", "Failed to create texture", { path = path })
        return nil
    end

    _image.set_texture_filter(handle, _image.filters[filter] or _image.filters.point)

    local texture = setmetatable({
        handle = handle,
        width = handle.width,
        height = handle.height,
        path = path,
        filter = filter,
        cache_key = cache_key,
        registry = self,
    }, TextureMethods)

    self.textures[cache_key] = texture
    return texture
end

--- Unloads every cached texture.
function ImageRegistry:cleanup_textures()
    for _, texture in pairs(self.textures) do
        if texture.handle then
            _image.unload_texture(texture.handle)
            texture.handle = nil
        end
    end
    self.textures = {}
end

--- @section Images

--- Adds a retained image to the active scene.
--- Animation defs follow `{ frames = count, x = first column, y = row, fps = 8, loop = true }`.
--- @param config table { texture|path, filter, x, y, scale, width, height, rotation, origin, tint, layer, space, flip_x, flip_y, frame_width, frame_height, animations, animation }
--- @return ImageObjectHandle
function ImageRegistry:add(config)
    config = config or {}

    local pool = self.scenes[self.active_scene]
    if not pool then
        pool = {}
        self.scenes[self.active_scene] = pool
    end

    local texture = config.texture or config.path
    if type(texture) == "string" then
        texture = self:load_texture(texture, config.filter)
    end

    local id = self.next_id
    self.next_id = self.next_id + 1

    local tex_w = texture and texture.width or 0
    local tex_h = texture and texture.height or 0

    local fw = config.frame_width or tex_w
    local fh = config.frame_height or tex_h
    local origin = config.origin or {}

    local img = {
        id = id,
        scene = self.active_scene,
        texture = texture,
        x = config.x or 0,
        y = config.y or 0,
        scale = config.scale or 1,
        width = config.width,
        height = config.height,
        rotation = config.rotation or 0,
        origin_x = origin.x or origin[1] or 0,
        origin_y = origin.y or origin[2] or 0,
        flip_x = config.flip_x or false,
        flip_y = config.flip_y or false,
        tint = _image.resolve_colour(config.tint or config.colour or config.color or "white"),
        layer = config.layer or 0,
        space = config.space or "screen",
        active = true,
        render = render_image,
        registry = self,

        fw = fw,
        fh = fh,
        cols = (config.frame_width and fw > 0) and math.max(1, math.floor(tex_w / fw)) or nil,
        src = _image.new_rectangle(0, 0, fw, fh),
        dst = _image.new_rectangle(0, 0, fw, fh),
        origin_v = _image.new_vector2(0, 0),

        animations = config.animations or {},
        anim = nil,
        anim_name = nil,
        frame_index = 1,
        timer = 0,
        playing = false,
    }

    function img:remove()
        self.registry:remove_image(self.scene, self.id)
    end

    function img:set_position(x, y)
        self.x, self.y = x, y
    end

    function img:set_scale(scale)
        self.scale = scale
    end

    function img:set_size(width, height)
        self.width, self.height = width, height
    end

    function img:set_rotation(degrees)
        self.rotation = degrees
    end

    function img:set_origin(x, y)
        self.origin_x, self.origin_y = x, y
    end

    function img:set_flip(flip_x, flip_y)
        self.flip_x, self.flip_y = flip_x and true or false, flip_y and true or false
    end

    function img:set_colour(colour)
        self.tint = _image.resolve_colour(colour)
    end

    function img:set_space(space)
        self.space = space
        _G.render_list:touch(self.scene)
    end

    function img:set_layer(layer)
        self.layer = layer
        _G.render_list:touch(self.scene)
    end

    function img:get_size()
        return self.width or self.fw * self.scale, self.height or self.fh * self.scale
    end

    function img:set_frame(index)
        self.frame_index = index
        apply_frame(self)
    end

    function img:play(name, restart)
        local def = self.animations[name]
        if not def then
            log("warn", "Unknown animation", { name = name })
            return
        end
        if self.anim_name == name and self.playing and not restart then return end

        self.anim = {
            frames = def.frames or 1,
            x = def.x or 0,
            y = def.y or 0,
            fps = def.fps or DEFAULT_FPS,
            loop = def.loop ~= false,
        }
        self.anim_name = name
        self.frame_index = 1
        self.timer = 0
        self.playing = self.anim.frames > 1
        apply_frame(self)
    end

    function img:stop()
        self.playing = false
    end

    function img:update(dt)
        local anim = self.anim
        if not anim then return end

        local step = 1 / anim.fps
        self.timer = self.timer + dt

        while self.timer >= step do
            self.timer = self.timer - step
            self.frame_index = self.frame_index + 1

            if self.frame_index > anim.frames then
                if anim.loop then
                    self.frame_index = 1
                else
                    self.frame_index = anim.frames
                    self.playing = false
                    self.timer = 0
                    break
                end
            end
        end

        apply_frame(self)
    end

    apply_frame(img)
    if config.animation then
        img:play(config.animation)
    end

    pool[id] = img
    _G.render_list:add(self.active_scene, img)
    return img
end

--- Removes an image from the scene pool by ID.
--- @param scene_name string
--- @param id number
function ImageRegistry:remove_image(scene_name, id)
    local pool = self.scenes[scene_name]
    local obj = pool and pool[id]
    if obj then
        pool[id] = nil
        _G.render_list:remove(scene_name, obj)
    end
end

return ImageRegistry