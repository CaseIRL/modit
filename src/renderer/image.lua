--- @module image
--- @file src/renderer/image.lua
--- @description Handles everything image and texture related with a lean, build-only-what-is-needed footprint.

--- @section Imports

local _raylib = require("src.bindings.raylib")
local _ffi = _raylib.ffi
local _rl = _raylib.lib

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

m.filters = {
    point = _ffi.C.TEXTURE_FILTER_POINT,
    bilinear = _ffi.C.TEXTURE_FILTER_BILINEAR,
    trilinear = _ffi.C.TEXTURE_FILTER_TRILINEAR,
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

local function resolve_vector2(v)
    if type(v) == "table" then
        return _ffi.new("Vector2", v.x or v[1] or 0, v.y or v[2] or 0)
    end
    return v
end

local function resolve_rectangle(r)
    if type(r) == "table" then
        return _ffi.new("Rectangle", r.x or r[1] or 0, r.y or r[2] or 0, r.width or r.w or r[3] or 0, r.height or r.h or r[4] or 0)
    end
    return r
end

--- @section Image Loading & Unloading

--- Load image from file into CPU memory.
--- @param file_name string
--- @return Image
function m.load_image(file_name)
    return _rl.LoadImage(file_name)
end

--- Load image from memory buffer.
--- @param file_type string
--- @param file_data string|cdata
--- @param data_size number
--- @return Image
function m.load_image_from_memory(file_type, file_data, data_size)
    return _rl.LoadImageFromMemory(file_type, file_data, data_size)
end

--- Check if an image is valid.
--- @param image Image
--- @return boolean
function m.is_image_valid(image)
    return _rl.IsImageValid(image)
end

--- Unload image from CPU memory.
--- @param image Image
function m.unload_image(image)
    _rl.UnloadImage(image)
end

--- @section Texture Loading & Unloading

--- Load texture from image data into GPU memory.
--- @param image Image
--- @return Texture2D
function m.load_texture_from_image(image)
    return _rl.LoadTextureFromImage(image)
end

--- Check if texture is valid.
--- @param texture Texture2D
--- @return boolean
function m.is_texture_valid(texture)
    return _rl.IsTextureValid(texture)
end

--- Unload texture from GPU memory.
--- @param texture Texture2D
function m.unload_texture(texture)
    _rl.UnloadTexture(texture)
end

--- @section Texture Configuration

--- Set texture scaling filter mode.
--- @param texture Texture2D
--- @param filter number
function m.set_texture_filter(texture, filter)
    _rl.SetTextureFilter(texture, filter)
end

--- @section Texture Drawing

--- Draw a part of a texture defined by a source rectangle to destination rectangle, with scaling and rotation.
--- @param texture Texture2D
--- @param srcrec table|cdata
--- @param dstrec table|cdata
--- @param origin table|cdata
--- @param rotation number
--- @param tint string|table|cdata
function m.draw_texture_pro(texture, srcrec, dstrec, origin, rotation, tint)
    _rl.DrawTexturePro(texture, resolve_rectangle(srcrec), resolve_rectangle(dstrec), resolve_vector2(origin), rotation, resolve_colour(tint))
end

--- @section Exported Helpers

--- Resolves a colour input into a native FFI Color.
--- @param c string|table|cdata
--- @return cdata Color
function m.resolve_colour(c)
    return resolve_colour(c)
end

--- Creates a native Rectangle that can be mutated in place.
--- @param x number
--- @param y number
--- @param width number
--- @param height number
--- @return cdata Rectangle
function m.new_rectangle(x, y, width, height)
    return _ffi.new("Rectangle", x or 0, y or 0, width or 0, height or 0)
end

--- Creates a native Vector2 that can be mutated in place.
--- @param x number
--- @param y number
--- @return cdata Vector2
function m.new_vector2(x, y)
    return _ffi.new("Vector2", x or 0, y or 0)
end

return m