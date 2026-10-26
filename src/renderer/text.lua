--- @module text
--- @file src/renderer/text.lua
--- @description Font loading, text drawing, and management.

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

--- Helper to convert a Lua table into a native FFI Vector2.
--- @param v table|cdata Vector2 input
--- @return cdata Vector2
local function resolve_vector2(v)
    if type(v) == "table" then
        return _ffi.new("Vector2", v.x or v[1] or 0, v.y or v[2] or 0)
    end
    return v
end

--- Resolves a colour input into a native FFI Color (cdata passes through untouched).
--- @param c string|table|cdata
--- @return cdata Color
function m.resolve_colour(c)
    return resolve_colour(c)
end

--- Creates a native Vector2 that can be mutated in place.
--- @param x number
--- @param y number
--- @return cdata Vector2
function m.new_vector2(x, y)
    return _ffi.new("Vector2", x or 0, y or 0)
end

--- Sets the texture filter on a font's atlas (bilinear by default).
--- @param font cdata Font
--- @param filter number|nil
function m.set_font_filter(font, filter)
    _rl.SetTextureFilter(font.texture, filter or _ffi.C.TEXTURE_FILTER_BILINEAR)
end

--- @section Font Loading & Unloading

--- Get the default Font.
--- @return cdata Font
function m.get_font_default()
    return _rl.GetFontDefault()
end

--- Load font from file into GPU memory (VRAM).
--- @param file_name string
--- @return cdata Font
function m.load_font(file_name)
    return _rl.LoadFont(file_name)
end

--- Load font from file with defined codepoints and generation size.
--- @param file_name string
--- @param font_size number
--- @param codepoints cdata|nil
--- @param codepoint_count number
--- @return cdata Font
function m.load_font_ex(file_name, font_size, codepoints, codepoint_count)
    return _rl.LoadFontEx(file_name, font_size, codepoints, codepoint_count)
end

--- Load font from Image (XNA style).
--- @param image cdata Image
--- @param key string|table|cdata Color key
--- @param first_char number
--- @return cdata Font
function m.load_font_from_image(image, key, first_char)
    return _rl.LoadFontFromImage(image, resolve_colour(key), first_char)
end

--- Check if font is valid (font data loaded).
--- @param font cdata Font
--- @return boolean
function m.is_font_valid(font)
    return _rl.IsFontValid(font)
end

--- Unload font from GPU memory (VRAM).
--- @param font cdata Font
function m.unload_font(font)
    _rl.UnloadFont(font)
end

--- @section Text Drawing Functions

--- Draw current FPS.
--- @param pos_x number
--- @param pos_y number
function m.draw_fps(pos_x, pos_y)
    _rl.DrawFPS(pos_x, pos_y)
end

--- Draw text.
--- @param text string
--- @param pos_x number
--- @param pos_y number
--- @param font_size number
--- @param colour string|table|cdata
function m.draw_text(text, pos_x, pos_y, font_size, colour)
    _rl.DrawText(text, pos_x, pos_y, font_size, resolve_colour(colour))
end

--- Draw text using font and additional parameters.
--- @param font cdata Font
--- @param text string
--- @param position cdata|table Vector2
--- @param font_size number
--- @param spacing number
--- @param tint string|table|cdata
function m.draw_text_ex(font, text, position, font_size, spacing, tint)
    _rl.DrawTextEx(font, text, resolve_vector2(position), font_size, spacing, resolve_colour(tint))
end

--- Draw text using Font and pro parameters.
--- @param font cdata Font
--- @param text string
--- @param position cdata|table Vector2
--- @param origin cdata|table Vector2
--- @param rotation number
--- @param font_size number
--- @param spacing number
--- @param tint string|table|cdata
function m.draw_text_pro(font, text, position, origin, rotation, font_size, spacing, tint)
    _rl.DrawTextPro(font, text, resolve_vector2(position), resolve_vector2(origin), rotation, font_size, spacing, resolve_colour(tint))
end

--- Draw one character (codepoint).
--- @param font cdata Font
--- @param codepoint number
--- @param position cdata|table Vector2
--- @param font_size number
--- @param tint string|table|cdata
function m.draw_text_codepoint(font, codepoint, position, font_size, tint)
    _rl.DrawTextCodepoint(font, codepoint, resolve_vector2(position), font_size, resolve_colour(tint))
end

--- @section Text Font Info & Measurement

--- Set vertical line spacing when drawing with line-breaks.
--- @param spacing number
function m.set_text_line_spacing(spacing)
    _rl.SetTextLineSpacing(spacing)
end

--- Measure string width for default font.
--- @param text string
--- @param font_size number
--- @return number
function m.measure_text(text, font_size)
    return _rl.MeasureText(text, font_size)
end

--- Measure string size for Font.
--- @param font cdata Font
--- @param text string
--- @param font_size number
--- @param spacing number
--- @return cdata Vector2
function m.measure_text_ex(font, text, font_size, spacing)
    return _rl.MeasureTextEx(font, text, font_size, spacing)
end

--- Get glyph index position in font for a codepoint.
--- @param font cdata Font
--- @param codepoint number
--- @return number
function m.get_glyph_index(font, codepoint)
    return _rl.GetGlyphIndex(font, codepoint)
end

--- Get glyph rectangle in font atlas for a codepoint.
--- @param font cdata Font
--- @param codepoint number
--- @return cdata Rectangle
function m.get_glyph_atlas_rec(font, codepoint)
    return _rl.GetGlyphAtlasRec(font, codepoint)
end

--- @section String Management Utilities

--- Check if two text strings are equal.
--- @param text1 string
--- @param text2 string
--- @return boolean
function m.text_is_equal(text1, text2)
    return _rl.TextIsEqual(text1, text2)
end

--- Get text length, checks for '\0' ending.
--- @param text string
--- @return number
function m.text_length(text)
    return _rl.TextLength(text)
end

--- Get integer value from text.
--- @param text string
--- @return number
function m.text_to_integer(text)
    return _rl.TextToInteger(text)
end

--- Get float value from text.
--- @param text string
--- @return number
function m.text_to_float(text)
    return _rl.TextToFloat(text)
end

return m
