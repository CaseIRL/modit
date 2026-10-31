--- @module gamepad
--- @file src/framework/input/gamepad.lua
--- @description Gamepad buttons, sticks, triggers and vibration.

--- @section Imports

local _raylib = require("src.framework.bindings.raylib")
local _ffi = _raylib.ffi
local _rl = _raylib.lib

--- @section Constants

local BUTTONS = {
    -- Dpad
    dpad_up = 1, dpad_right = 2, dpad_down = 3, dpad_left = 4,
    
    -- Buttons & Triggers
    y = 5, b = 6, a = 7, x = 8,
    lb = 9, lt = 10, rb = 11, rt = 12,
    back = 13, guide = 14, start = 15,

    -- Sticks
    left_stick = 16, right_stick = 17,
}

local AXES = {
    -- Left
    left_x = 0, left_y = 1, 
    left_trigger = 4,

    -- Right
    right_x = 2, right_y = 3,
    right_trigger = 5,
}

local BUTTON_NAMES = {}
for name, code in pairs(BUTTONS) do
    BUTTON_NAMES[code] = name
end

--- @section Initialisation

local m = {}

local deadzone = 0.15

--- @section Helpers

--- Resolves a button name or code to a numeric button code.
--- @param button string|number
--- @return number
local function resolve_button(button)
    if _G.console_open then return 0 end
    local code = BUTTONS[button]
    if code then
        return code
    end

    if type(button) == "number" then
        return button
    end

    error("unknown gamepad button: " .. tostring(button), 3)
end

--- Resolves an axis name or code to a numeric axis code.
--- @param axis string|number
--- @return number
local function resolve_axis(axis)
    local code = AXES[axis]
    if code then
        return code
    end

    if type(axis) == "number" then
        return axis
    end

    error("unknown gamepad axis: " .. tostring(axis), 3)
end

--- Applies deadzone thresholding and scaling to stick coordinates.
--- @param x number
--- @param y number
--- @return number, number
local function apply_deadzone(x, y)
    local length = math.sqrt(x * x + y * y)
    if length < deadzone then
        return 0, 0
    end

    local scale = (math.min(length, 1) - deadzone) / (1 - deadzone) / length
    return x * scale, y * scale
end

--- @section Pads

--- Check if a gamepad is available and connected.
--- @param pad number|nil
--- @return boolean
function m.is_available(pad)
    return _rl.IsGamepadAvailable(pad or 0)
end

--- Get the name of a connected gamepad.
--- @param pad number|nil
--- @return string|nil
function m.get_name(pad)
    local name = _rl.GetGamepadName(pad or 0)
    if name == nil then
        return nil
    end
    return _ffi.string(name)
end

--- Get the total number of axes available on a gamepad.
--- @param pad number|nil
--- @return number
function m.get_axis_count(pad)
    return _rl.GetGamepadAxisCount(pad or 0)
end

--- @section Buttons

--- Check if a gamepad button is currently held down.
--- @param button string|number
--- @param pad number|nil
--- @return boolean
function m.is_down(button, pad)
    return _rl.IsGamepadButtonDown(pad or 0, resolve_button(button))
end

--- Check if a gamepad button is currently up.
--- @param button string|number
--- @param pad number|nil
--- @return boolean
function m.is_up(button, pad)
    return _rl.IsGamepadButtonUp(pad or 0, resolve_button(button))
end

--- Check if a gamepad button was pressed this frame.
--- @param button string|number
--- @param pad number|nil
--- @return boolean
function m.is_pressed(button, pad)
    return _rl.IsGamepadButtonPressed(pad or 0, resolve_button(button))
end

--- Check if a gamepad button was released this frame.
--- @param button string|number
--- @param pad number|nil
--- @return boolean
function m.is_released(button, pad)
    return _rl.IsGamepadButtonReleased(pad or 0, resolve_button(button))
end

--- Get the name or code of the last gamepad button pressed.
--- @return string|number|nil
function m.get_button_pressed()
    if _G.console_open then return nil end
    local code = _rl.GetGamepadButtonPressed()
    if code <= 0 then
        return nil
    end
    return BUTTON_NAMES[code] or code
end

--- Check if a given string is a valid known gamepad button name.
--- @param name string
--- @return boolean
function m.is_button_name(name)
    return BUTTONS[name] ~= nil
end

--- @section Axes

--- Get the movement value of a specific gamepad axis.
--- @param axis string|number
--- @param pad number|nil
--- @return number
function m.get_axis(axis, pad)
    return _rl.GetGamepadAxisMovement(pad or 0, resolve_axis(axis))
end

--- Get the movement values of a gamepad stick (left or right).
--- @param side string
--- @param pad number|nil
--- @return number, number
function m.get_stick(side, pad)
    if _G.console_open then return 0, 0 end
    if side ~= "left" and side ~= "right" then
        error("stick side must be \"left\" or \"right\", got " .. tostring(side), 2)
    end

    pad = pad or 0
    local x = _rl.GetGamepadAxisMovement(pad, AXES[side .. "_x"])
    local y = _rl.GetGamepadAxisMovement(pad, AXES[side .. "_y"])
    return apply_deadzone(x, y)
end

--- Get the normalized value of a gamepad trigger (left or right).
--- @param side string
--- @param pad number|nil
--- @return number
function m.get_trigger(side, pad)
    if _G.console_open then return 0 end
    if side ~= "left" and side ~= "right" then
        error("trigger side must be \"left\" or \"right\", got " .. tostring(side), 2)
    end

    local value = _rl.GetGamepadAxisMovement(pad or 0, AXES[side .. "_trigger"])
    return math.max(0, math.min(1, (value + 1) / 2))
end

--- Set the global deadzone threshold for gamepad sticks.
--- @param value number
function m.set_deadzone(value)
    if type(value) ~= "number" or value < 0 or value >= 1 then
        error("deadzone must be a number from 0 up to (not including) 1", 2)
    end
    deadzone = value
end

--- Get the current global deadzone threshold.
--- @return number
function m.get_deadzone()
    return deadzone
end

--- @section Feedback

--- Set motor vibration levels and duration for a gamepad.
--- @param left number
--- @param right number
--- @param duration number
--- @param pad number|nil
function m.set_vibration(left, right, duration, pad)
    _rl.SetGamepadVibration(pad or 0, left, right, duration)
end

--- @section Mappings

--- Set custom gamepad mapping configuration strings.
--- @param mappings string
--- @return boolean
function m.set_mappings(mappings)
    if type(mappings) ~= "string" then
        error("mappings must be a string", 2)
    end
    return _rl.SetGamepadMappings(mappings) ~= 0
end

return m