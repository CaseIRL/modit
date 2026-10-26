--- @module keyboard
--- @file src/input/keyboard.lua
--- @description Keyboard input and clipboard.

--- @section Imports

local _raylib = require("src.bindings.raylib")
local _ffi = _raylib.ffi
local _rl = _raylib.lib

--- @section Constants

local KEY_CODES = {
    -- Letters
    a = 65, b = 66, c = 67, d = 68, e = 69, f = 70, g = 71, h = 72, i = 73, j = 74,
    k = 75, l = 76, m = 77, n = 78, o = 79, p = 80, q = 81, r = 82, s = 83, t = 84,
    u = 85, v = 86, w = 87, x = 88, y = 89, z = 90,

    -- Numbers
    ["0"] = 48, ["1"] = 49, ["2"] = 50, ["3"] = 51, ["4"] = 52,
    ["5"] = 53, ["6"] = 54, ["7"] = 55, ["8"] = 56, ["9"] = 57,

    -- F keys
    f1 = 290, f2 = 291, f3 = 292, f4 = 293, f5 = 294, f6 = 295,
    f7 = 296, f8 = 297, f9 = 298, f10 = 299, f11 = 300, f12 = 301,

    -- Punctuation
    apostrophe = 39, comma = 44, minus = 45, period = 46, slash = 47,
    semicolon = 59, equal = 61, leftbracket = 91, backslash = 92,
    rightbracket = 93, grave = 96,

    -- Editing and navigation
    space = 32, enter = 257, escape = 256, tab = 258, backspace = 259,
    insert = 260, delete = 261,
    arrowright = 262, arrowleft = 263, arrowdown = 264, arrowup = 265,
    pageup = 266, pagedown = 267, home = 268, ["end"] = 269,

    -- Locks and system
    capslock = 280, scrolllock = 281, numlock = 282, printscreen = 283, pause = 284,

    -- Modifiers
    leftshift = 340, leftctrl = 341, leftalt = 342, leftsuper = 343,
    rightshift = 344, rightctrl = 345, rightalt = 346, rightsuper = 347,
    menu = 348,

    -- Keypad
    kp0 = 320, kp1 = 321, kp2 = 322, kp3 = 323, kp4 = 324,
    kp5 = 325, kp6 = 326, kp7 = 327, kp8 = 328, kp9 = 329,
    kpdecimal = 330, kpdivide = 331, kpmultiply = 332, kpsubtract = 333,
    kpadd = 334, kpenter = 335, kpequal = 336,
}

local KEY_NAMES = {}
for name, code in pairs(KEY_CODES) do
    KEY_NAMES[code] = name
end

--- @section Initialisation

local m = {}

--- @section Helpers

--- Resolves a key name or code to a numeric key code.
--- @param key string|number
--- @return number
local function resolve(key)
    local code = KEY_CODES[key]
    if code then
        return code
    end

    if type(key) == "number" then
        return key
    end

    error("unknown key: " .. tostring(key), 3)
end

--- @section Keys

--- Check if a key is currently held down.
--- @param key string|number
--- @return boolean
function m.is_down(key)
    return _rl.IsKeyDown(resolve(key))
end

--- Check if a key was pressed this frame.
--- @param key string|number
--- @return boolean
function m.is_pressed(key)
    return _rl.IsKeyPressed(resolve(key))
end

--- Check if a key is pressed down or repeated via auto-repeat.
--- @param key string|number
--- @return boolean
function m.is_pressed_repeat(key)
    return _rl.IsKeyPressedRepeat(resolve(key))
end

--- Check if a key was released this frame.
--- @param key string|number
--- @return boolean
function m.is_released(key)
    return _rl.IsKeyReleased(resolve(key))
end

--- Check if a key is currently up.
--- @param key string|number
--- @return boolean
function m.is_up(key)
    return _rl.IsKeyUp(resolve(key))
end

--- Check if a given string is a valid known key name.
--- @param name string
--- @return boolean
function m.is_key_name(name)
    return KEY_CODES[name] ~= nil
end

--- @section Text Input

--- Get the last character pressed this frame.
--- @return number
function m.get_char()
    return _rl.GetCharPressed()
end

--- Get the key name or code of the last key pressed.
--- @return string|number|nil
function m.get_key_pressed()
    local code = _rl.GetKeyPressed()
    if code == 0 then
        return nil
    end
    return KEY_NAMES[code] or code
end

--- Get the display label name for a given key.
--- @param key string|number
--- @return string|nil
function m.get_key_label(key)
    local label = _rl.GetKeyName(resolve(key))
    if label == nil then
        return nil
    end

    local text = _ffi.string(label)
    return text ~= "" and text or nil
end

--- @section Clipboard

--- Get text from the system clipboard.
--- @return string
function m.get_clipboard()
    local text = _rl.GetClipboardText()
    if text == nil then
        return ""
    end
    return _ffi.string(text)
end

--- Set text on the system clipboard.
--- @param text string
function m.set_clipboard(text)
    if type(text) ~= "string" then
        error("clipboard text must be a string", 2)
    end
    _rl.SetClipboardText(text)
end

return m