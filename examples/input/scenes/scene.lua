--[[

    Modit Input Example
    -------------------

    Basic input example scene: keyboard, mouse, gamepad and an action binding.
    Move the box with WASD or the left stick, hold the "boost" action to go faster.

    Things are subject to change so develop with this in mind.
]]

local scene = {}

local OWNER = "input_demo"
local SPEED = 200

--- You dont need this its just creating the text lines
function scene:line(y)
    return modit.graphics.new_text({ text = "", x = 20, y = y })
end

--- Load whatever your game needs here
function scene:load()
    --[[
        map_action(name, bindings, owner)
            - one action can have many bindings, any of them triggers it
            - a key is just its name: "space"
            - a mouse button is a table: { mouse_button = "left" }
            - a gamepad button is a table: { gamepad_button = "a", pad = 0 } (pad is optional)
            - owner is any string, use the same one to clear them again on unload
    ]]
    modit.input.map_action("boost", { "space", { mouse_button = "left" }, { gamepad_button = "a" } }, OWNER)

    self.x, self.y = 600, 450
    self.wheel = 0
    self.last_button = "none yet"
    self.last_key = "none yet"

    self.box = modit.graphics.new_shape("rectangle", {
        x = self.x, y = self.y, width = 40, height = 40, colour = "white",
    })

    self.keyboard = self:line(20)
    self.mouse = self:line(60)
    self.gamepad = self:line(100)
    self.action = self:line(140)
    modit.graphics.new_text({ text = "WASD / left stick: move | SPACE, left click, A button: boost", x = 20, y = 200, colour = "gray" })
end

--- Update whatever your game needs here; dt = delta time
function scene:update(dt)
    local input = modit.input

    -- Keyboard: key_down is true every frame the key is held (key_pressed is true once)
    local dx, dy, held = 0, 0, {}
    if input.key_down("w") then dy = dy - 1; held[#held + 1] = "W" end
    if input.key_down("s") then dy = dy + 1; held[#held + 1] = "S" end
    if input.key_down("a") then dx = dx - 1; held[#held + 1] = "A" end
    if input.key_down("d") then dx = dx + 1; held[#held + 1] = "D" end

    -- get_key_pressed returns the name of the last key pressed ("space", "enter"...) or nil
    local last = input.get_key_pressed()
    if last then self.last_key = tostring(last) end
    self.keyboard:set_text("KEYBOARD  held: " .. (#held > 0 and table.concat(held, " ") or "-") .. "   last key: " .. self.last_key)

    -- Mouse: position, buttons and wheel
    local mx, my = input.get_mouse_position()
    self.wheel = self.wheel + input.get_mouse_wheel()
    self.mouse:set_text(string.format("MOUSE  %d, %d   left:%s right:%s   wheel %d", mx, my, input.mouse_down("left") and "down" or "-", input.mouse_down("right") and "down" or "-", self.wheel))

    -- Gamepad: only read the sticks when one is connected
    if input.gamepad_available() then
        -- The stick already has a deadzone applied, so small drift reads as 0
        local lx, ly = input.get_gamepad_stick("left")
        dx, dy = dx + lx, dy + ly

        -- Returns the button name ("a", "lb", "dpad_up"...) or nil
        local pressed = input.get_gamepad_button_pressed()
        if pressed then self.last_button = tostring(pressed) end

        self.gamepad:set_text(string.format("GAMEPAD  %s   stick %.2f, %.2f   RT %.2f   last button: %s",
            input.get_gamepad_name() or "unknown", lx, ly, input.get_gamepad_trigger("right"), self.last_button))
    else
        self.gamepad:set_text("GAMEPAD  none connected")
    end

    -- Action: works from any of its bindings
    local boosting = input.action_down("boost")
    if input.action_pressed("boost") then
        input.set_gamepad_vibration(0.5, 0.5, 0.2) -- does nothing without a gamepad
    end
    self.action:set_text(string.format("ACTION boost  down:%s  held %.1fs", boosting and "yes" or "no", input.get_action_hold_time("boost")))

    -- Use it all to move the box
    local speed = boosting and SPEED * 2.5 or SPEED
    self.x = self.x + dx * speed * dt
    self.y = self.y + dy * speed * dt
    self.box:set_position(self.x, self.y)
    self.box:set_colour(boosting and "yellow" or "white")
end

--- Unload things here
function scene:unload()
    -- Actions stay mapped until cleared, so remove the ones this scene made
    modit.input.clear_owner_actions(OWNER)
end

return scene