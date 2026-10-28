--[[

    Modit Text Example
    ------------------

    Basic text example scene to show how fonts and text objects currently work.

    Things are subject to change so develop with this in mind.
]]

local scene = {}

-- Colours can be a name ("white", "red", "yellow"...) or a table { r, g, b, a }
local COLOURS = {
    { 120, 230, 150, 255 },
    { 255, 110, 110, 255 },
    { 110, 160, 255, 255 },
    { 255, 200, 90, 255 },
}

--- Load whatever your game needs here
function scene:load()
    --[[
        load_font(path, size)
            - path is relative to your project
            - returns nil if the file isn't found
    ]]
    self.font = modit.graphics.load_font("assets/fonts/JetBrainsMono-Regular.ttf", 32)

    self.time = 0
    self.presses = 0

    --[[
        new_text(config) creates a text object that draws every frame.
        Pass `font = self.font` to use your font.
        If font is nil (not found) or left out, it falls back to the default font.
    ]]

    -- Entry 1: uses the loaded font, we change this one live with SPACE
    self.custom = modit.graphics.new_text({
        text = "Custom font, press SPACE to change me",
        font = self.font,
        x = 50, y = 80,
        colour = COLOURS[1],
    })

    -- Entry 2: no font given, so it uses the default font (font_size is only used here)
    self.default = modit.graphics.new_text({
        text = "Default font, I never change",
        x = 50, y = 160,
        font_size = 24,
        colour = "white",
    })

    -- Entry 3: this one moves, see scene:update
    self.mover = modit.graphics.new_text({
        text = "I move!",
        font = self.font,
        x = 50, y = 260,
        colour = "yellow",
    })

    -- Shows if the font loaded or if everything is using the fallback
    modit.graphics.new_text({
        text = self.font and "Font loaded" or "Font not found, using default font",
        x = 50, y = 20,
        font_size = 20,
        colour = "gray",
    })
end

--- Update things in the game here
function scene:update(dt)
    self.time = self.time + dt

    -- Change text and colour on a key press
    if modit.input.key_pressed("space") then
        self.presses = self.presses + 1
        self.custom:set_text("Changed " .. self.presses .. " times")
        self.custom:set_colour(COLOURS[self.presses % #COLOURS + 1])
    end

    -- Move text by setting its position every frame
    local x = 50 + (math.sin(self.time * 2) + 1) * 200
    local y = 260 + math.sin(self.time * 6) * 12
    self.mover:set_position(x, y)
end

--- Unload things you loaded in `scene:load()` here
function scene:unload()
    -- Text objects are cleaned up for you when the scene unloads, fonts are not
    if self.font then self.font:unload() end
end

return scene