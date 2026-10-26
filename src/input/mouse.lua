--- @module mouse
--- @file src/input/mouse.lua
--- @description Mouse buttons, position, wheel and cursor control.

--- @section Imports

local _raylib = require("src.bindings.raylib")
local _rl = _raylib.lib

--- @section Constants

local BUTTONS = {
    -- Primary Clicks
    left = 0, right = 1, middle = 2,
    
    -- Side and Extra Buttons
    side = 3, extra = 4, forward = 5, back = 6,
}

--- @section Initialisation

local m = {}

--- @section Helpers

--- Resolves a mouse button name or code to a numeric button code.
--- @param button string|number
--- @return number
local function resolve_button(button)
    local code = BUTTONS[button]
    if code then
        return code
    end

    if type(button) == "number" then
        return button
    end

    error("unknown mouse button: " .. tostring(button), 3)
end

--- @section Buttons

--- Check if a mouse button is currently held down.
--- @param button string|number
--- @return boolean
function m.is_down(button)
    return _rl.IsMouseButtonDown(resolve_button(button))
end

--- Check if a mouse button is currently up.
--- @param button string|number
--- @return boolean
function m.is_up(button)
    return _rl.IsMouseButtonUp(resolve_button(button))
end

--- Check if a mouse button was pressed this frame.
--- @param button string|number
--- @return boolean
function m.is_pressed(button)
    return _rl.IsMouseButtonPressed(resolve_button(button))
end

--- Check if a mouse button was released this frame.
--- @param button string|number
--- @return boolean
function m.is_released(button)
    return _rl.IsMouseButtonReleased(resolve_button(button))
end

--- Check if a given string is a valid known mouse button name.
--- @param name string
--- @return boolean
function m.is_button_name(name)
    return BUTTONS[name] ~= nil
end

--- @section Position

--- Get the current mouse position as x and y coordinates.
--- @return number, number
function m.get_position()
    local v = _rl.GetMousePosition()
    return v.x, v.y
end

--- Get the current mouse X coordinate.
--- @return number
function m.get_x()
    return _rl.GetMouseX()
end

--- Get the current mouse Y coordinate.
--- @return number
function m.get_y()
    return _rl.GetMouseY()
end

--- Get mouse movement delta since the last frame.
--- @return number, number
function m.get_delta()
    local v = _rl.GetMouseDelta()
    return v.x, v.y
end

--- Set the mouse cursor position.
--- @param x number
--- @param y number
function m.set_position(x, y)
    _rl.SetMousePosition(x, y)
end

--- Set the mouse position offset.
--- @param x number
--- @param y number
function m.set_offset(x, y)
    _rl.SetMouseOffset(x, y)
end

--- Set the mouse scaling factor.
--- @param x number
--- @param y number
function m.set_scale(x, y)
    _rl.SetMouseScale(x, y)
end

--- @section Wheel

--- Get vertical mouse wheel movement.
--- @return number
function m.get_wheel()
    return _rl.GetMouseWheelMove()
end

--- Get horizontal and vertical mouse wheel movement.
--- @return number, number
function m.get_wheel_xy()
    local v = _rl.GetMouseWheelMoveV()
    return v.x, v.y
end

return m