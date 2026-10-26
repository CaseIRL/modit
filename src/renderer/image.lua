--- @module image
--- @file src/renderer/image.lua
--- @description Handles everything image and texture related.

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

--- Resolves a colour input into a native FFI Color.
--- @param c string|table|cdata
--- @return cdata Color
local function resolve_colour(c)
    if type(c) == "string" then
        return colours[c] or colours.white
    elseif type(c) == "table" then
        return _ffi.new("Color", c[1] or 255, c[2] or 255, c[3] or 255, c[4] or 255)
    end
    return c
end

--- @param v table|cdata
--- @return cdata Vector2
local function resolve_vector2(v)
    if type(v) == "table" then
        return _ffi.new("Vector2", v.x or v[1] or 0, v.y or v[2] or 0)
    end
    return v
end

--- @param r table|cdata
--- @return cdata Rectangle
local function resolve_rectangle(r)
    if type(r) == "table" then
        return _ffi.new("Rectangle", r.x or r[1] or 0, r.y or r[2] or 0, r.width or r.w or r[3] or 0, r.height or r.h or r[4] or 0)
    end
    return r
end

--- @param n table|cdata
--- @return cdata NPatchInfo
local function resolve_npatch(n)
    if type(n) == "table" then
        local info = _ffi.new("NPatchInfo")
        info.source = resolve_rectangle(n.source)
        info.left, info.top, info.right, info.bottom = n.left or 0, n.top or 0, n.right or 0, n.bottom or 0
        info.layout = n.layout or 0
        return info
    end
    return n
end

--- Copies the result of an `Image *` call back into the callers image.
--- @param image cdata Image
--- @param p cdata Image[1]
--- @return cdata Image
local function sync_image(image, p)
    image.data, image.width, image.height = p[0].data, p[0].width, p[0].height
    image.mipmaps, image.format = p[0].mipmaps, p[0].format
    return image
end

--- Copies the result of a `Texture2D *` call back into the callers texture.
--- @param texture cdata Texture2D
--- @param p cdata Texture2D[1]
--- @return cdata Texture2D
local function sync_texture(texture, p)
    texture.id, texture.width, texture.height = p[0].id, p[0].width, p[0].height
    texture.mipmaps, texture.format = p[0].mipmaps, p[0].format
    return texture
end


--- @section Image Loading

--- Load image from file into CPU memory.
--- @param file_name string
--- @return Image
function m.load_image(file_name)
    return _rl.LoadImage(file_name)
end

--- Load image from memory buffer, fileType refers to extension: i.e. '.png'.
--- @param file_type string
--- @param file_data string|cdata
--- @param data_size number
--- @return Image
function m.load_image_from_memory(file_type, file_data, data_size)
    return _rl.LoadImageFromMemory(file_type, file_data, data_size)
end

--- Load image from screen buffer.
--- @return Image
function m.load_image_from_screen()
    return _rl.LoadImageFromScreen()
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

--- Export image data to file.
--- @param image Image
--- @param file_name string
--- @return boolean
function m.export_image(image, file_name)
    return _rl.ExportImage(image, file_name)
end


--- @section Image Generation

--- Generate image: plain colour.
--- @param width number
--- @param height number
--- @param colour string|table|cdata
--- @return Image
function m.gen_image_colour(width, height, colour)
    return _rl.GenImageColor(width, height, resolve_colour(colour))
end


--- @section Image Manipulation

--- Crop an image to a defined rectangle.
--- @param image cdata Image (modified in place)
--- @param crop table|cdata
--- @return cdata Image
function m.image_crop(image, crop)
    local p = _ffi.new("Image[1]", image)
    _rl.ImageCrop(p, resolve_rectangle(crop))
    return sync_image(image, p)
end

--- Resize image.
--- @param image cdata Image (modified in place)
--- @param new_width number
--- @param new_height number
--- @return cdata Image
function m.image_resize_nn(image, new_width, new_height)
    local p = _ffi.new("Image[1]", image)
    _rl.ImageResizeNN(p, new_width, new_height)
    return sync_image(image, p)
end

--- Flip image vertically.
--- @param image cdata Image (modified in place)
--- @return cdata Image
function m.image_flip_vertical(image)
    local p = _ffi.new("Image[1]", image)
    _rl.ImageFlipVertical(p)
    return sync_image(image, p)
end

--- Flip image horizontally.
--- @param image cdata Image (modified in place)
--- @return cdata Image
function m.image_flip_horizontal(image)
    local p = _ffi.new("Image[1]", image)
    _rl.ImageFlipHorizontal(p)
    return sync_image(image, p)
end


--- @section Texture Loading (requires GPU access)

--- Load texture from file into GPU memory.
--- @param file_name string
--- @return Texture2D
function m.load_texture(file_name)
    return _rl.LoadTexture(file_name)
end

--- Load texture from image data.
--- @param image Image
--- @return Texture2D
function m.load_texture_from_image(image)
    return _rl.LoadTextureFromImage(image)
end

--- Load texture for rendering.
--- @param width number
--- @param height number
--- @return RenderTexture2D
function m.load_render_texture(width, height)
    return _rl.LoadRenderTexture(width, height)
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

--- Check if render texture is valid.
--- @param target RenderTexture2D
--- @return boolean
function m.is_render_texture_valid(target)
    return _rl.IsRenderTextureValid(target)
end

--- Unload render texture from GPU memory.
--- @param target RenderTexture2D
function m.unload_render_texture(target)
    _rl.UnloadRenderTexture(target)
end

--- Update GPU texture with new data.
--- @param texture Texture2D
--- @param pixels cdata
function m.update_texture(texture, pixels)
    _rl.UpdateTexture(texture, pixels)
end


--- @section Texture Configuration

--- Generate GPU mipmaps for a texture.
--- @param texture cdata Texture2D (modified in place)
--- @return cdata Texture2D
function m.gen_texture_mipmaps(texture)
    local p = _ffi.new("Texture2D[1]", texture)
    _rl.GenTextureMipmaps(p)
    return sync_texture(texture, p)
end

--- Set texture scaling filter mode.
--- @param texture Texture2D
--- @param filter number
function m.set_texture_filter(texture, filter)
    _rl.SetTextureFilter(texture, filter)
end

--- Set texture wrapping mode.
--- @param texture Texture2D
--- @param wrap number
function m.set_texture_wrap(texture, wrap)
    _rl.SetTextureWrap(texture, wrap)
end


--- @section Texture Drawing

--- Draw a Texture2D.
--- @param texture Texture2D
--- @param pos_x number
--- @param pos_y number
--- @param tint string|table|cdata
function m.draw_texture(texture, pos_x, pos_y, tint)
    _rl.DrawTexture(texture, pos_x, pos_y, resolve_colour(tint))
end

--- Draw a Texture2D with position defined as Vector2.
--- @param texture Texture2D
--- @param position table|cdata
--- @param tint string|table|cdata
function m.draw_texture_v(texture, position, tint)
    _rl.DrawTextureV(texture, resolve_vector2(position), resolve_colour(tint))
end

--- Draw a Texture2D with rotation and scale.
--- @param texture Texture2D
--- @param position table|cdata
--- @param rotation number
--- @param scale number
--- @param tint string|table|cdata
function m.draw_texture_ex(texture, position, rotation, scale, tint)
    _rl.DrawTextureEx(texture, resolve_vector2(position), rotation, scale, resolve_colour(tint))
end

--- Draw a part of a texture defined by a rectangle.
--- @param texture Texture2D
--- @param rec table|cdata
--- @param position table|cdata
--- @param tint string|table|cdata
function m.draw_texture_rec(texture, rec, position, tint)
    _rl.DrawTextureRec(texture, resolve_rectangle(rec), resolve_vector2(position), resolve_colour(tint))
end

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

--- Draw a texture that stretches or shrinks nicely.
--- @param texture Texture2D
--- @param n_patch_info table|cdata
--- @param dstrec table|cdata
--- @param origin table|cdata
--- @param rotation number
--- @param tint string|table|cdata
function m.draw_texture_n_patch(texture, n_patch_info, dstrec, origin, rotation, tint)
    _rl.DrawTextureNPatch(texture, resolve_npatch(n_patch_info), resolve_rectangle(dstrec), resolve_vector2(origin), rotation, resolve_colour(tint))
end


--- @section Colour and Pixel Utilities

--- Get colour with alpha applied, alpha goes from 0.0f to 1.0f.
--- @param colour string|table|cdata
--- @param alpha number
--- @return string|table|cdata
function m.fade(colour, alpha)
    return _rl.Fade(resolve_colour(colour), alpha)
end

--- Get colour multiplied with another colour.
--- @param colour string|table|cdata
--- @param tint string|table|cdata
--- @return string|table|cdata
function m.colour_tint(colour, tint)
    return _rl.ColorTint(resolve_colour(colour), resolve_colour(tint))
end

--- Get colour with alpha applied, alpha goes from 0.0f to 1.0f.
--- @param colour string|table|cdata
--- @param alpha number
--- @return string|table|cdata
function m.colour_alpha(colour, alpha)
    return _rl.ColorAlpha(resolve_colour(colour), alpha)
end

--- Get colour lerp interpolation between two colours, factor [0.0f..1.0f].
--- @param colour1 string|table|cdata
--- @param colour2 string|table|cdata
--- @param factor number
--- @return string|table|cdata
function m.colour_lerp(colour1, colour2, factor)
    return _rl.ColorLerp(resolve_colour(colour1), resolve_colour(colour2), factor)
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