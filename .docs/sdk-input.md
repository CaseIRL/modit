# Input SDK Reference

The Input SDK handles keyboard, mouse, gamepad states, clipboard operations, and action mapping.

---

## Keyboard

Check key states and retrieve key labels or text input.

### `modit.input.key_down(key)`

Check if a key is currently held down.

* **Parameters:**
    * `key` (string|number): Key name or key code.

* **Returns:**
    * `boolean`: `true` if down, otherwise `false`.

```lua
if modit.input.key_down("w") then
    print("Moving forward")
end
```

### `modit.input.key_up(key)`

Check if a key is currently up.

* **Parameters:**
    * `key` (string|number): Key name or key code.

* **Returns:**
    * `boolean`.

### `modit.input.key_pressed(key)`

Check if a key was pressed this frame.

* **Parameters:**
    * `key` (string|number): Key name or key code.

* **Returns:**
    * `boolean`.

### `modit.input.key_released(key)`

Check if a key was released this frame.

* **Parameters:**
    * `key` (string|number): Key name or key code.

* **Returns:**
    * `boolean`.

### `modit.input.key_pressed_repeat(key)`

Check if a key is pressed down or repeated via auto-repeat.

* **Parameters:**
    * `key` (string|number): Key name or key code.

* **Returns:**
    * `boolean`.

### `modit.input.get_key_label(key)`

Get the display label for a given key.

* **Parameters:**
    * `key` (string|number): Key name or key code.

* **Returns:**
    * `string`: Key label.

---

## Clipboard

Manage system clipboard text.

### `modit.input.get_clipboard()`

Get text from the system clipboard.

* **Returns:**
    * `string`: Clipboard text contents.

### `modit.input.set_clipboard(text)`

Set text on the system clipboard.

* **Parameters:**
    * `text` (string): Text to copy.

```lua
modit.input.set_clipboard("Hello from Modit!")
```

---

## Mouse Position

Query mouse coordinates, movement deltas, scroll wheel values, and screen bounds.

### `modit.input.get_mouse_position()`

Get current mouse position as X and Y coordinates.

* **Returns:**
    * `number, number`: X and Y positions.

```lua
local mx, my = modit.input.get_mouse_position()
```

### `modit.input.get_mouse_x()` / `modit.input.get_mouse_y()`

Get current mouse X or Y coordinate individually.

* **Returns:**
    * `number`.

### `modit.input.get_mouse_delta()`

Get mouse movement delta since last frame.

* **Returns:**
    * `number, number`: Delta X and Delta Y.

### `modit.input.get_mouse_wheel()`

Get vertical mouse wheel movement.

* **Returns:**
    * `number`.

### `modit.input.get_mouse_wheel_xy()`

Get horizontal and vertical mouse wheel movement.

* **Returns:**
    * `number, number`: Wheel X and Wheel Y.

### `modit.input.mouse_in_rect(x, y, w, h)`

Check if the mouse pointer is inside a given rectangle.

* **Parameters:**
    * `x`, `y` (number): Rectangle top-left coordinates.
    * `w`, `h` (number): Rectangle width and height.

* **Returns:**
    * `boolean`.

```lua
if modit.input.mouse_in_rect(10, 10, 100, 50) then
    print("Mouse is over button")
end
```

---

## Mouse Buttons

Check button states for the mouse.

### `modit.input.mouse_pressed(button)`

Check if a mouse button was pressed this frame.

* **Parameters:**
    * `button` (string|number|nil): Button name (defaults to `"left"`) or code.

* **Returns:**
    * `boolean`.

```lua
if modit.input.mouse_pressed("left") then
    print("Clicked left mouse button")
end
```

### `modit.input.mouse_down(button)`

Check if a mouse button is currently held down.

* **Parameters:**
    * `button` (string|number|nil).

* **Returns:**
    * `boolean`.

### `modit.input.mouse_up(button)`

Check if a mouse button is currently up.

* **Parameters:**
    * `button` (string|number|nil).

* **Returns:**
    * `boolean`.

### `modit.input.mouse_released(button)`

Check if a mouse button was released this frame.

* **Parameters:**
    * `button` (string|number|nil).

* **Returns:**
    * `boolean`.

---

## Gamepad

Check gamepad connection, button states, sticks, triggers, and vibration.

### `modit.input.gamepad_available(pad)`

Check if a gamepad is available and connected.

* **Parameters:**
    * `pad` (number|nil): Gamepad index (defaults to `0`).

* **Returns:**
    * `boolean`.

### `modit.input.get_gamepad_name(pad)`

Get the name of a connected gamepad.

* **Parameters:**
    * `pad` (number|nil).

* **Returns:**
    * `string`.

### `modit.input.gamepad_down(button, pad)`

Check if a gamepad button is currently held down.

* **Parameters:**
    * `button` (string|number): Button name or code.
    * `pad` (number|nil).

* **Returns:**
    * `boolean`.

### `modit.input.gamepad_up(button, pad)`

Check if a gamepad button is currently up.

* **Parameters:**
    * `button` (string|number).
    * `pad` (number|nil).

* **Returns:**
    * `boolean`.

### `modit.input.gamepad_pressed(button, pad)`

Check if a gamepad button was pressed this frame.

* **Parameters:**
    * `button` (string|number).
    * `pad` (number|nil).

* **Returns:**
    * `boolean`.

### `modit.input.gamepad_released(button, pad)`

Check if a gamepad button was released this frame.

* **Parameters:**
    * `button` (string|number).
    * `pad` (number|nil).

* **Returns:**
    * `boolean`.

### `modit.input.get_gamepad_stick(side, pad)`

Get axis values for a gamepad stick.

* **Parameters:**
    * `side` (string): Stick side (`"left"` or `"right"`).
    * `pad` (number|nil).

* **Returns:**
    * `number, number`: X and Y axis values.

```lua
local lx, ly = modit.input.get_gamepad_stick("left")
```

### `modit.input.get_gamepad_trigger(side, pad)`

Get value for a gamepad trigger.

* **Parameters:**
    * `side` (string): Trigger side (`"left"` or `"right"`).
    * `pad` (number|nil).

* **Returns:**
    * `number`: Trigger value.

### `modit.input.set_gamepad_vibration(left, right, duration, pad)`

Set gamepad motor vibration levels and duration.

* **Parameters:**
    * `left` (number): Left motor intensity (`0.0` to `1.0`).
    * `right` (number): Right motor intensity (`0.0` to `1.0`).
    * `duration` (number): Duration in seconds.
    * `pad` (number|nil).

```lua
modit.input.set_gamepad_vibration(0.5, 0.8, 0.2)
```

---

## Actions

Check virtual mapped action states and hold durations.

### `modit.input.action_pressed(name)`

Check if an action was pressed this frame.

* **Parameters:**
    * `name` (string): Action name.

* **Returns:**
    * `boolean`.

```lua
if modit.input.action_pressed("jump") then
    -- perform jump
end
```

### `modit.input.action_down(name)`

Check if an action is currently held down.

* **Parameters:**
    * `name` (string): Action name.

* **Returns:**
    * `boolean`.

### `modit.input.action_released(name)`

Check if an action was released this frame.

* **Parameters:**
    * `name` (string): Action name.

* **Returns:**
    * `boolean`.

### `modit.input.get_action_hold_time(name)`

Get how long an action has been held down in seconds.

* **Parameters:**
    * `name` (string): Action name.

* **Returns:**
    * `number`: Hold duration in seconds.
