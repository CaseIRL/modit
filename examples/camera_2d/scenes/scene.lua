--[[

    Modit 2D Camera Example
    -----------------------

    Basic 2D camera example scene: following a target, zooming and converting the mouse to world space.

    Things are subject to change so develop with this in mind.
]]

local scene = {}

local SPEED = 240
local ZOOMS = { 0.5, 1, 2, 3 }

--- Load whatever your game needs here
function scene:load()
    -- A 2D camera, nothing uses it until set_camera is called
    self.camera = modit.graphics.new_camera({ mode = "2d" })
    modit.graphics.set_camera(self.camera)

    self.zoom_index = 2
    self.x, self.y = 0, 0

    --[[
        `space = "world"` means a shape is drawn through the camera, so it moves and zooms with it.
        Without it (the default is "screen") a shape stays fixed on the window like a HUD.
    ]]
    for ty = -5, 5 do
        for tx = -5, 5 do
            modit.graphics.new_shape("rectangle", {
                x = tx * 100,
                y = ty * 100,
                width = 96,
                height = 96,
                colour = (tx + ty) % 2 == 0 and { 34, 38, 48, 255 } or { 46, 52, 66, 255 },
                layer = -1,
                space = "world",
            })
        end
    end

    -- The thing the camera follows
    self.player = modit.graphics.new_shape("rectangle", { x = 0, y = 0, width = 32, height = 32, colour = "red", space = "world" })

    -- Text is screen space by default so it stays put while the camera moves
    self.info = modit.graphics.new_text({ text = "", x = 20, y = 20 })
    modit.graphics.new_text({ text = "WASD move | Q/E zoom", x = 20, y = 50, colour = "gray" })
end

-- Update your game here by dt - delta time
function scene:update(dt)
    local input = modit.input

    -- Move the player
    if input.key_down("w") then self.y = self.y - SPEED * dt end
    if input.key_down("s") then self.y = self.y + SPEED * dt end
    if input.key_down("a") then self.x = self.x - SPEED * dt end
    if input.key_down("d") then self.x = self.x + SPEED * dt end
    self.player:set_position(self.x, self.y)

    -- Control zoom
    if input.key_pressed("e") and self.zoom_index < #ZOOMS then self.zoom_index = self.zoom_index + 1 end
    if input.key_pressed("q") and self.zoom_index > 1 then self.zoom_index = self.zoom_index - 1 end

    -- Point the camera at the player and set the zoom
    self.camera:follow(self.x, self.y)
    self.camera:set_zoom(ZOOMS[self.zoom_index])

    -- Convert the mouse from screen pixels to world position
    local wx, wy = self.camera:screen_to_world(input.get_mouse_position())
    self.info:set_text(string.format("mouse world %d, %d   zoom %.1f", wx, wy, self.camera.zoom))
end

--- Unload things you loaded in `scene:load()` here
function scene:unload()
    -- Shapes and text are cleaned up for you, the camera just needs clearing
    modit.graphics.set_camera(nil)
end

return scene