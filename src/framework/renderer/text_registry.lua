--- @class TextRegistry
--- @file src/graphics/text_registry.lua
--- @description Unified text registry managing font loading and retained text objects.

--- @section Imports

local _text = require("src.framework.renderer.text")
local _fs = require("src.framework.core.filesystem")

--- @section Font Methods

local FontMethods = {}
FontMethods.__index = FontMethods

--- Measures the width of a given text string using this font.
--- @param text string
--- @param font_size number
--- @param spacing number|nil
--- @return number width
function FontMethods:measure(text, font_size, spacing)
    local size_vec = _text.measure_text_ex(self.handle, text, font_size, spacing or 1.0)
    return size_vec.x
end

--- Unloads this font from memory and removes it from the cache.
function FontMethods:unload()
    if self.handle then
        _text.unload_font(self.handle)
    end
    if self.registry and self.registry.font_cache then
        self.registry.font_cache[self.cache_key] = nil
    end
end

--- @section Rendering

--- Draws one text object. Registered with the render list as obj:render().
--- @param t table Text object
local function render_text(t)
    local str = tostring(t.text or "")
    if t.font and t.font.handle then
        _text.draw_text_ex(t.font.handle, str, t.position, t.font_size, t.spacing, t.colour)
    else
        _text.draw_text(str, t.x, t.y, t.font_size, t.colour)
    end
end

--- @section Text Constructor

local TextRegistry = {}
TextRegistry.__index = TextRegistry

--- Creates a new TextRegistry instance.
--- @return TextRegistry
function TextRegistry.new()
    local self = setmetatable({}, TextRegistry)
    self.scenes = {}
    self.font_cache = {}
    self.active_scene = "default"
    self.next_id = 1
    self.root = "."
    return self
end

--- @section Scene

--- Sets the active scene context.
--- @param scene_name string|nil
function TextRegistry:set_active_scene(scene_name)
    self.active_scene = scene_name or "default"
    if not self.scenes[self.active_scene] then
        self.scenes[self.active_scene] = {}
    end
end

--- @section Fonts

--- Loads a custom font from disk using project root.
--- @param path string
--- @param size number
--- @return FontObject|nil
function TextRegistry:load_font(path, size)
    if not path or path == "" then return nil end
    size = size or 20

    local cache_key = path .. "_" .. tostring(size)
    if self.font_cache[cache_key] then return self.font_cache[cache_key] end

    local resolved_path = _fs.resolve(path, { self.root, "." })
    if not resolved_path then
        log("warn", "Failed to resolve font path", { path = path, root = self.root })
        return nil
    end

    local success, raw_font = pcall(function() return _text.load_font_ex(resolved_path, size, nil, 0) end)
    if not success or not _text.is_font_valid(raw_font) then
        log("warn", "Failed to load font from resolved path", { path = path, resolved = resolved_path })
        return nil
    end

    _text.set_font_filter(raw_font)

    local font_obj = setmetatable({
        handle = raw_font,
        size = size,
        path = resolved_path,
        cache_key = cache_key,
        registry = self
    }, FontMethods)

    self.font_cache[cache_key] = font_obj
    return font_obj
end

--- Cleans up all cached fonts.
function TextRegistry:cleanup_fonts()
    for key, font_obj in pairs(self.font_cache) do
        if font_obj.handle then
            _text.unload_font(font_obj.handle)
        end
        self.font_cache[key] = nil
    end
end

--- @section Text

--- Adds a retained text object, uses font if provided, fallsback to raylib if not.
--- @param config table Configuration table ({ text, font, x, y, position, font_size, colour, spacing })
--- @return TextObjectHandle Text object handle
function TextRegistry:add(config)
    config = config or {}
    local scene_pool = self.scenes[self.active_scene]
    if not scene_pool then
        scene_pool = {}
        self.scenes[self.active_scene] = scene_pool
    end

    local id = self.next_id
    self.next_id = self.next_id + 1

    local init_x = config.x or (config.position and config.position.x) or 0
    local init_y = config.y or (config.position and config.position.y) or 0
    local font = config.font

    --- @type TextObjectHandle
    local text_obj = {
        id = id,
        scene = self.active_scene,
        text = tostring(config.text or ""),
        x = init_x,
        y = init_y,
        position = _text.new_vector2(init_x, init_y),
        font = font,
        font_size = config.font_size or (font and font.size) or 20,
        spacing = config.spacing or 1.0,
        colour = _text.resolve_colour(config.colour or config.color or "white"),
        layer = config.layer or 0,
        space = config.space or "screen",
        active = true,
        render = render_text,
        registry = self,
    }

    function text_obj:remove()
        self.registry:remove_text(self.scene, self.id)
    end

    function text_obj:set_text(new_text)
        self.text = tostring(new_text)
    end

    function text_obj:set_font(new_font)
        self.font = new_font
    end

    function text_obj:set_position(x, y)
        self.x = x
        self.y = y
        self.position.x = x
        self.position.y = y
    end

    function text_obj:set_colour(colour)
        self.colour = _text.resolve_colour(colour)
    end

    function text_obj:set_space(space)
        self.space = space
        _G.render_list:touch(self.scene)
    end

    function text_obj:set_layer(layer)
        self.layer = layer
        _G.render_list:touch(self.scene)
    end

    function text_obj:measure()
        if self.font and self.font.measure then
            return self.font:measure(self.text, self.font_size, self.spacing)
        else
            return _text.measure_text(self.text, self.font_size)
        end
    end

    scene_pool[id] = text_obj
    _G.render_list:add(self.active_scene, text_obj)
    return text_obj
end

--- Removes a text object from the scene pool by ID.
--- @param scene_name string
--- @param id number
function TextRegistry:remove_text(scene_name, id)
    local pool = self.scenes[scene_name]
    local obj = pool and pool[id]
    if obj then
        pool[id] = nil
        _G.render_list:remove(scene_name, obj)
    end
end

--- Clears all text objects in a scene.
--- @param scene_name string
function TextRegistry:clear_scene(scene_name)
    if self.scenes[scene_name] then
        self.scenes[scene_name] = {}
    end
end

return TextRegistry