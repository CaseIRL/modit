--[[

    Modit Environment Example
    -------------------------

    Basic environment example scene: sun, ambient, sky, fog, lighting and shadows.
    Everything here goes through the graphics API and only applies to 3D camera scenes.

    Things are subject to change so develop with this in mind.
]]

local scene = {}

local SHADOW_MODES = { "map", "projected", "blob", "off" }
local WALL = { 70, 76, 92, 255 }

--- Sends the current settings to the engine, called again whenever one changes
function scene:apply()
    -- Sets the lighting
    modit.graphics.set_lighting(self.lighting)
    modit.graphics.set_ambient(60, 70, 90)

    -- Sets the skybox
    if self.sky then
        modit.graphics.set_sky(20, 24, 33, 100, 115, 140)
    else
        modit.graphics.clear_sky()
    end

    -- Without a colour the fog follows the sky horizon
    if self.fog then
        modit.graphics.set_fog(15, 45)
    else
        modit.graphics.set_fog(1e5, 1e6)
    end

    -- ground is the world Y that "projected" and "blob" shadows land on
    modit.graphics.set_shadows({ mode = SHADOW_MODES[self.shadow_index], strength = 0.6, range = 50, size = 2048, ground = 0 })
end

--- Load things for your game here
function scene:load()
    -- Setup a 3d camera
    self.camera = modit.graphics.new_camera({ mode = "3d", fov = 60 })
    modit.graphics.set_camera(self.camera)

    -- Set up state
    self.time, self.angle, self.distance = 0, 0.6, 22
    self.shadow_index = 1
    self.lighting, self.sky, self.fog, self.spin = true, true, false, true

    -- The floor receives shadows but does not cast
    modit.graphics.new_model({ primitive = "plane", scale = { 40, 1, 40 }, colour = { 38, 42, 52, 255 }, cast_shadow = false })

    -- Creates the outer cylinders
    for i = 0, 5 do
        local a = i / 6 * math.pi * 2
        modit.graphics.new_model({ primitive = "cylinder", x = math.cos(a) * 8, z = math.sin(a) * 8, scale = { 1.5, 4, 1.5 }, colour = WALL })
    end

    -- Creates the cube
    modit.graphics.new_model({ primitive = "cube", y = 1, scale = 2, colour = { 255, 110, 110, 255 } })

    -- Creates bobbing sphere
    self.bobber = modit.graphics.new_model({ primitive = "sphere", x = 3, y = 3, scale = 1.5, colour = { 110, 160, 255, 255 } })

    self.info = modit.graphics.new_text({ text = "", x = 20, y = 20 })
    modit.graphics.new_text({ text = "A/D orbit | W/S zoom | Z shadows | L lighting | K sky | F fog | T sun spin", x = 20, y = 50, colour = "gray" })

    self:apply()
end

--- Update things in your game scene here dt = deltatime
function scene:update(dt)
    self.time = self.time + dt

    -- Camera positions
    if modit.input.key_down("a") then self.angle = self.angle - 1.5 * dt end
    if modit.input.key_down("d") then self.angle = self.angle + 1.5 * dt end
    if modit.input.key_down("w") then self.distance = math.max(6, self.distance - 8 * dt) end
    if modit.input.key_down("s") then self.distance = math.min(40, self.distance + 8 * dt) end
    self.camera:set_position(math.cos(self.angle) * self.distance, 9, math.sin(self.angle) * self.distance)
    self.camera:set_target(0, 1, 0)

    -- Each toggle flips a setting, then apply() sends everything again
    if modit.input.key_pressed("z") then self.shadow_index = self.shadow_index % #SHADOW_MODES + 1 end
    if modit.input.key_pressed("l") then self.lighting = not self.lighting end
    if modit.input.key_pressed("k") then self.sky = not self.sky end
    if modit.input.key_pressed("f") then self.fog = not self.fog end
    if modit.input.key_pressed("t") then self.spin = not self.spin end
    if modit.input.key_pressed("z") or modit.input.key_pressed("l") or modit.input.key_pressed("k") or modit.input.key_pressed("f") then
        self:apply()
    end

    -- Sun direction is the way the light travels, spinning it moves every shadow
    local a = self.spin and self.time * 0.5 or 0.5
    modit.graphics.set_sun(math.cos(a), -0.8, math.sin(a), 255, 240, 220)

    -- Moves the spehere
    self.bobber:set_position(3, 3 + math.sin(self.time * 2), 0)

    self.info:set_text(string.format("shadows %s | lighting %s | sky %s | fog %s", SHADOW_MODES[self.shadow_index], self.lighting and "on" or "off", self.sky and "on" or "off", self.fog and "on" or "off"))
end

--- Unload things from game here
function scene:unload()
    -- Models and text are cleaned up for you, free the cached assets and reset the environment
    modit.graphics.set_camera(nil)
    modit.graphics.cleanup_models()
    modit.graphics.reset_environment()
end

return scene