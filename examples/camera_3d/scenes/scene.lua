--[[

    Modit 3D Camera Example
    -----------------------

    Basic 3D camera example scene
    Orbiting a target, changing zoom and fov, and pinning a screen-space label to a point in the world.

    Things are subject to change so develop with this in mind.
]]

local scene = {}

--- Load things for your game scene here
function scene:load()
    -- A 3D camera, models draw through it automatically once set_camera is called
    self.camera = modit.graphics.new_camera({ mode = "3d", fov = 60 })
    modit.graphics.set_camera(self.camera)

    self.angle = 0
    self.distance = 10
    self.fov = 60

    -- Primitives are unit sized, scale sets the size
    modit.graphics.new_model({ primitive = "plane", scale = { 20, 1, 20 }, colour = { 50, 55, 70, 255 } })
    self.cube = modit.graphics.new_model({ primitive = "cube", y = 1, scale = 2, colour = { 255, 110, 110, 255 } })
    modit.graphics.new_model({ primitive = "sphere", x = 4, y = 0.5, colour = { 110, 160, 255, 255 } })
    modit.graphics.new_model({ primitive = "cube", x = -4, y = 0.5, colour = { 255, 200, 90, 255 } })

    -- Screen space text that we move onto the cube every frame
    self.tag = modit.graphics.new_text({ text = "cube", colour = "white" })
    self.info = modit.graphics.new_text({ text = "", x = 20, y = 20 })
    modit.graphics.new_text({ text = "A/D orbit | W/S zoom | Q/E fov", x = 20, y = 50, colour = "gray" })
end

--- Update things here; dt = deltatime
function scene:update(dt)
    local input = modit.input

    if input.key_down("a") then self.angle = self.angle - 1.5 * dt end
    if input.key_down("d") then self.angle = self.angle + 1.5 * dt end
    if input.key_down("w") then self.distance = math.max(3, self.distance - 6 * dt) end
    if input.key_down("s") then self.distance = math.min(30, self.distance + 6 * dt) end
    if input.key_down("q") then self.fov = math.max(20, self.fov - 30 * dt) end
    if input.key_down("e") then self.fov = math.min(110, self.fov + 30 * dt) end

    -- Orbit: place the camera on a circle around the target and look at it
    self.camera:set_position(math.cos(self.angle) * self.distance, 5, math.sin(self.angle) * self.distance)
    self.camera:set_target(0, 1, 0)
    self.camera:set_fov(self.fov)

    -- Convert a world point to screen pixels, here just above the cube
    local sx, sy = self.camera:world_to_screen_3d(0, 2.4, 0)
    self.tag:set_position(sx - 15, sy)

    self.info:set_text(string.format("distance %.1f   fov %d", self.distance, self.fov))
end

--- Unload things here
function scene:unload()
    -- Models and text are cleaned up for you, free the cached assets and clear the camera
    modit.graphics.set_camera(nil)
    modit.graphics.cleanup_models()
end

return scene