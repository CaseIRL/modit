--- @module api.input
--- @file src/api/input.lua
--- @description Keyboard, mouse, gamepad and actions.
--- @default_realm client

--- @section Imports

local _keyboard = require("src.framework.input.keyboard")
local _mouse = require("src.framework.input.mouse")
local _gamepad = require("src.framework.input.gamepad")

--- @section Constants

local MAX_KEY = 348
local MAX_MOUSE_BUTTON = 6
local MAX_PAD = 3
local MAX_PAD_BUTTON = 17
local MAX_VIBRATION_TIME = 5

--- @section Initialisation

local m = {}

local actions = {}
local held = {}

local action_checks = {
    key = {
        pressed = _keyboard.is_pressed,
        down = _keyboard.is_down,
        released = _keyboard.is_released,
    },
    mouse = {
        pressed = _mouse.is_pressed,
        down = _mouse.is_down,
        released = _mouse.is_released,
    },
    pad = {
        pressed = _gamepad.is_pressed,
        down = _gamepad.is_down,
        released = _gamepad.is_released,
    },
}

--- @section Helpers

--- True if value is a whole number inside low..high.
--- @param value any
--- @param low number
--- @param high number
--- @return boolean
local function in_range(value, low, high)
    return type(value) == "number" and value == math.floor(value) and value >= low and value <= high
end

--- Clamps a number into a range.
--- @param value number
--- @param low number
--- @param high number
--- @return number
local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

--- Passes key names through and range checks raw key codes.
--- @param key string|number
--- @return string|number
local function check_key(key)
    if type(key) == "number" and not in_range(key, 1, MAX_KEY) then
        error("key code out of range: " .. tostring(key), 3)
    end

    return key
end

--- Defaults to "left" and range checks raw mouse button codes.
--- @param button string|number|nil
--- @return string|number
local function check_mouse_button(button)
    if button == nil then
        return "left"
    end

    if type(button) == "number" and not in_range(button, 0, MAX_MOUSE_BUTTON) then
        error("mouse button out of range: " .. tostring(button), 3)
    end

    return button
end

--- Defaults to pad 0 and range checks the index.
--- @param pad number|nil
--- @return number
local function check_pad(pad)
    if pad == nil then
        return 0
    end

    if not in_range(pad, 0, MAX_PAD) then
        error(("gamepad index must be 0 to %d, got %s"):format(MAX_PAD, tostring(pad)), 3)
    end

    return pad
end

--- Passes button names through and range checks raw gamepad button codes.
--- @param button string|number
--- @return string|number
local function check_pad_button(button)
    if type(button) == "number" and not in_range(button, 0, MAX_PAD_BUTTON) then
        error("gamepad button out of range: " .. tostring(button), 3)
    end

    return button
end

--- Checks that a binding is a known key name or a mouse/gamepad button table.
--- @param binding string|table
local function validate_binding(binding)
    if type(binding) == "string" then
        if not _keyboard.is_key_name(binding) then
            error("unknown key in binding: " .. binding, 4)
        end

    elseif type(binding) == "table" then
        if binding.mouse_button ~= nil then
            if not _mouse.is_button_name(binding.mouse_button) then
                error("unknown mouse button in binding: " .. tostring(binding.mouse_button), 4)
            end

        elseif binding.gamepad_button ~= nil then
            if not _gamepad.is_button_name(binding.gamepad_button) then
                error("unknown gamepad button in binding: " .. tostring(binding.gamepad_button), 4)
            end

            if binding.pad ~= nil and not in_range(binding.pad, 0, MAX_PAD) then
                error(("gamepad index in binding must be 0 to %d"):format(MAX_PAD), 4)
            end

        else
            error("binding table needs mouse_button or gamepad_button", 4)
        end

    else
        error("binding must be a key name or a table, got " .. type(binding), 4)
    end
end

--- Runs one state check (pressed, down, released) against a single binding.
--- @param binding string|table
--- @param check string
--- @return boolean
local function check_binding(binding, check)
    if type(binding) == "string" then
        return action_checks.key[check](binding)
    end

    if binding.mouse_button then
        return action_checks.mouse[check](binding.mouse_button)
    end

    if binding.gamepad_button then
        return action_checks.pad[check](binding.gamepad_button, binding.pad)
    end

    return false
end

--- True if any binding of the action matches the check.
--- @param name string
--- @param check string
--- @return boolean
local function check_action(name, check)
    local action = actions[name]

    if not action then
        return false
    end

    for _, binding in ipairs(action.bindings) do
        if check_binding(binding, check) then
            return true
        end
    end

    return false
end

--- @section Keyboard

--- Check if a key is currently held down.
--- @param key string|number
--- @return boolean
--- @access mod
function m.key_down(key)
    return _keyboard.is_down(check_key(key))
end

--- Check if a key is currently up.
--- @param key string|number
--- @return boolean
--- @access mod
function m.key_up(key)
    return _keyboard.is_up(check_key(key))
end

--- Check if a key was pressed this frame.
--- @param key string|number
--- @return boolean
--- @access mod
function m.key_pressed(key)
    return _keyboard.is_pressed(check_key(key))
end

--- Check if a key was released this frame.
--- @param key string|number
--- @return boolean
--- @access mod
function m.key_released(key)
    return _keyboard.is_released(check_key(key))
end

--- Check if a key is pressed down or repeated via auto-repeat.
--- @param key string|number
--- @return boolean
--- @access mod
function m.key_pressed_repeat(key)
    return _keyboard.is_pressed_repeat(check_key(key))
end

--- Get the display label for a given key.
--- @param key string|number
--- @return string
--- @access mod
function m.get_key_label(key)
    return _keyboard.get_key_label(check_key(key))
end

--- Get the key code of the last key pressed.
--- @return number
--- @access game
function m.get_key_pressed()
    return _keyboard.get_key_pressed()
end

--- Get the last character typed.
--- @return string
--- @access game
function m.get_char()
    return _keyboard.get_char()
end

--- @section Clipboard

--- Get text from the system clipboard.
--- @return string
--- @access game
function m.get_clipboard()
    return _keyboard.get_clipboard()
end

--- Set text on the system clipboard.
--- @param text string
--- @access game
function m.set_clipboard(text)
    _keyboard.set_clipboard(text)
end

--- @section Mouse Position

--- Get current mouse position as x and y coordinates.
--- @return number, number
--- @access mod
function m.get_mouse_position()
    return _mouse.get_position()
end

--- Get current mouse X coordinate.
--- @return number
--- @access mod
function m.get_mouse_x()
    return _mouse.get_x()
end

--- Get current mouse Y coordinate.
--- @return number
--- @access mod
function m.get_mouse_y()
    return _mouse.get_y()
end

--- Get mouse movement delta since last frame.
--- @return number, number
--- @access mod
function m.get_mouse_delta()
    return _mouse.get_delta()
end

--- Get vertical mouse wheel movement.
--- @return number
--- @access mod
function m.get_mouse_wheel()
    return _mouse.get_wheel()
end

--- Get horizontal and vertical mouse wheel movement.
--- @return number, number
--- @access mod
function m.get_mouse_wheel_xy()
    return _mouse.get_wheel_xy()
end

--- Check if the mouse is inside a given rectangle.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @return boolean
--- @access mod
function m.mouse_in_rect(x, y, w, h)
    local mx, my = _mouse.get_position()

    return mx >= x and mx < x + w and my >= y and my < y + h
end

--- Lock the mouse cursor to the window and hide it.
--- @access game
function m.lock_cursor()
    _mouse.lock_cursor()
end

--- Unlock the mouse cursor.
--- @access game
function m.unlock_cursor()
    _mouse.unlock_cursor()
end

--- Set the mouse cursor position.
--- @param x number
--- @param y number
--- @access game
function m.set_mouse_position(x, y)
    _mouse.set_position(x, y)
end

--- Set mouse offset.
--- @param x number
--- @param y number
--- @access game
function m.set_mouse_offset(x, y)
    _mouse.set_offset(x, y)
end

--- Set mouse scale.
--- @param x number
--- @param y number
--- @access game
function m.set_mouse_scale(x, y)
    _mouse.set_scale(x, y)
end

--- @section Mouse Buttons

--- Check if a mouse button was pressed this frame.
--- @param button string|number|nil
--- @return boolean
--- @access mod
function m.mouse_pressed(button)
    return _mouse.is_pressed(check_mouse_button(button))
end

--- Check if a mouse button is currently held down.
--- @param button string|number|nil
--- @return boolean
--- @access mod
function m.mouse_down(button)
    return _mouse.is_down(check_mouse_button(button))
end

--- Check if a mouse button is currently up.
--- @param button string|number|nil
--- @return boolean
--- @access mod
function m.mouse_up(button)
    return _mouse.is_up(check_mouse_button(button))
end

--- Check if a mouse button was released this frame.
--- @param button string|number|nil
--- @return boolean
--- @access mod
function m.mouse_released(button)
    return _mouse.is_released(check_mouse_button(button))
end

--- @section Gamepad

--- Check if a gamepad is available and connected.
--- @param pad number|nil
--- @return boolean
--- @access mod
function m.gamepad_available(pad)
    return _gamepad.is_available(check_pad(pad))
end

--- Get the name of a connected gamepad.
--- @param pad number|nil
--- @return string
--- @access mod
function m.get_gamepad_name(pad)
    return _gamepad.get_name(check_pad(pad))
end

--- Check if a gamepad button is currently held down.
--- @param button string|number
--- @param pad number|nil
--- @return boolean
--- @access mod
function m.gamepad_down(button, pad)
    return _gamepad.is_down(check_pad_button(button), check_pad(pad))
end

--- Check if a gamepad button is currently up.
--- @param button string|number
--- @param pad number|nil
--- @return boolean
--- @access mod
function m.gamepad_up(button, pad)
    return _gamepad.is_up(check_pad_button(button), check_pad(pad))
end

--- Check if a gamepad button was pressed this frame.
--- @param button string|number
--- @param pad number|nil
--- @return boolean
--- @access mod
function m.gamepad_pressed(button, pad)
    return _gamepad.is_pressed(check_pad_button(button), check_pad(pad))
end

--- Check if a gamepad button was released this frame.
--- @param button string|number
--- @param pad number|nil
--- @return boolean
--- @access mod
function m.gamepad_released(button, pad)
    return _gamepad.is_released(check_pad_button(button), check_pad(pad))
end

--- Get the last gamepad button pressed.
--- @return number
--- @access mod
function m.get_gamepad_button_pressed()
    return _gamepad.get_button_pressed()
end

--- Get axis values for a gamepad stick (left or right).
--- @param side string
--- @param pad number|nil
--- @return number, number
--- @access mod
function m.get_gamepad_stick(side, pad)
    return _gamepad.get_stick(side, check_pad(pad))
end

--- Get trigger value for a gamepad trigger (left or right).
--- @param side string
--- @param pad number|nil
--- @return number
--- @access mod
function m.get_gamepad_trigger(side, pad)
    return _gamepad.get_trigger(side, check_pad(pad))
end

--- Set gamepad motor vibration levels and duration.
--- @param left number
--- @param right number
--- @param duration number
--- @param pad number|nil
--- @access mod
function m.set_gamepad_vibration(left, right, duration, pad)
    if type(left) ~= "number" or type(right) ~= "number" or type(duration) ~= "number" then
        error("vibration needs numbers: left, right, duration", 2)
    end

    _gamepad.set_vibration(clamp(left, 0, 1), clamp(right, 0, 1), clamp(duration, 0, MAX_VIBRATION_TIME), check_pad(pad))
end

--- Set the deadzone threshold for gamepad sticks.
--- @param value number
--- @access game
function m.set_gamepad_deadzone(value)
    _gamepad.set_deadzone(value)
end

--- Set custom internal gamepad mappings.
--- @param mappings string
--- @return boolean
--- @access game
function m.set_gamepad_mappings(mappings)
    return _gamepad.set_mappings(mappings)
end

--- @section Actions

--- Map a virtual action name to a list of input bindings.
--- @param name string
--- @param bindings table
--- @param owner string
--- @access game
function m.map_action(name, bindings, owner)
    if type(name) ~= "string" or name == "" then
        error("action name must be a non-empty string", 2)
    end

    if type(bindings) ~= "table" or #bindings == 0 then
        error("action bindings must be a non-empty list", 2)
    end

    local existing = actions[name]
    if existing and existing.owner ~= owner then
        error(("action '%s' is owned by '%s'"):format(name, tostring(existing.owner)), 2)
    end

    local copy = {}

    for index, binding in ipairs(bindings) do
        validate_binding(binding)

        if type(binding) == "table" then
            copy[index] = {
                mouse_button = binding.mouse_button,
                gamepad_button = binding.gamepad_button,
                pad = binding.pad,
            }
        else
            copy[index] = binding
        end
    end

    actions[name] = { bindings = copy, owner = owner }
    held[name] = nil
end

--- Check if an action was pressed this frame.
--- @param name string
--- @return boolean
--- @access mod
function m.action_pressed(name)
    return check_action(name, "pressed")
end

--- Check if an action is currently held down.
--- @param name string
--- @return boolean
--- @access mod
function m.action_down(name)
    return check_action(name, "down")
end

--- Check if an action was released this frame.
--- @param name string
--- @return boolean
--- @access mod
function m.action_released(name)
    return check_action(name, "released")
end

--- Get how long an action has been held down in seconds.
--- @param name string
--- @return number
--- @access mod
function m.get_action_hold_time(name)
    return held[name] or 0
end

--- Clear all registered actions and held states.
--- @access game
function m.clear_actions()
    actions = {}
    held = {}
end

--- @section Engine Internal

--- Clear all actions registered by a specific owner.
--- @param owner string
function m.clear_owner_actions(owner)
    if owner == nil then
        error("owner is required", 2)
    end

    for name, action in pairs(actions) do
        if action.owner == owner then
            actions[name] = nil
            held[name] = nil
        end
    end
end

--- Create a scoped input context tied to a specific owner.
--- @param owner string
--- @return table
function m.scoped(owner)
    if type(owner) ~= "string" or owner == "" then
        error("owner must be a non-empty string", 2)
    end

    local api = {}

    function api.map_action(name, bindings)
        return m.map_action(name, bindings, owner)
    end

    function api.clear_actions()
        m.clear_owner_actions(owner)
    end

    return api
end

--- Update hold times for active actions.
--- @param dt number
function m.update(dt)
    for name in pairs(actions) do
        if check_action(name, "down") then
            held[name] = (held[name] or 0) + dt
        else
            held[name] = nil
        end
    end
end

return m