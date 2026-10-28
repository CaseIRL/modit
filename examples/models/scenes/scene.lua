--[[

    Modit Models Example
    --------------------

    Basic models example scene: primitives, transforms, tint, visibility, bounds,
    a per-model shader, unlit models, shadow opt-out and a loaded model file.

    Things are subject to change so develop with this in mind.
]]

local scene = {}

-- Optional: any glTF/GLB/OBJ/Vox file, a missing file just skips that model
local MODEL_PATH = "assets/models/robot.glb"

local TINTS = {
    { 255, 255, 255, 255 },
    { 255, 110, 110, 255 },
    { 110, 160, 255, 255 },
    { 255, 200, 90, 255 },
    { 120, 230, 150, 255 },
}

--- A custom shader needs its own vertex & fragment shader
local GLOW_VERTEX = [[
    #version 330
    in vec3 vertexPosition;
    uniform mat4 mvp;
    uniform mat4 matModel;
    out vec3 fragPosition;
    void main() {
        fragPosition = (matModel * vec4(vertexPosition, 1.0)).xyz;
        gl_Position = mvp * vec4(vertexPosition, 1.0);
    }
]]

local GLOW_FRAGMENT = [[
    #version 330
    in vec3 fragPosition;
    out vec4 finalColor;
    uniform float u_time;
    void main() {
        float pulse = sin(u_time * 4.0 + fragPosition.y * 4.0) * 0.5 + 0.5;
        finalColor = vec4(vec3(0.1, 0.8, 1.0) * (0.35 + 0.65 * pulse), 1.0);
    }
]]

--- Shorthand so the config below stays readable you dont need this
function scene:add(config)
    return modit.graphics.new_model(config)
end

--- Load things for your game scene here
function scene:load()
    -- Set up a 3D camera
    self.camera = modit.graphics.new_camera({ mode = "3d", fov = 60 })
    modit.graphics.set_camera(self.camera)

    -- Set scene state
    self.time, self.angle, self.distance, self.tint_index = 0, 0.4, 20, 1

    -- Envrionment settings are required for showing unlit models mostly
    modit.graphics.set_sun(-0.5, -0.8, -0.3, 255, 240, 220)
    modit.graphics.set_ambient(60, 70, 90)
    modit.graphics.set_sky(20, 24, 33, 100, 115, 140)
    modit.graphics.set_shadows({ mode = "map", strength = 0.6, range = 40, size = 2048 })

    -- Adds the ground
    self:add({ primitive = "plane", scale = { 40, 1, 40 }, colour = { 38, 42, 52, 255 }, cast_shadow = false })

    -- Shapes: unit sized, scale sets the size. T changes the tint of the first three
    self.tinted = {
        self:add({ primitive = "cube", x = -6, y = 0.5, z = 6, colour = TINTS[1] }),
        self:add({ primitive = "sphere", x = -3, y = 0.5, z = 6, colour = TINTS[2] }),
        self:add({ primitive = "cylinder", x = 0, z = 6, colour = TINTS[3] }),
    }

    -- unlit ignores the sun, the custom shader replaces the lit one for this model only
    self:add({ primitive = "sphere", x = 3, y = 0.5, z = 6, colour = TINTS[4], unlit = true })

    -- Load the custom shader and apply to the cube
    modit.graphics.load_shader_from_memory(GLOW_VERTEX, GLOW_FRAGMENT, "glow")
    self.glow = modit.graphics.load_shader_from_memory(GLOW_VERTEX, GLOW_FRAGMENT, "glow")
    self.shader_cube = self:add({ primitive = "cube", x = 6, y = 1, z = 6, scale = 1.8, shader = self.glow })

    -- Rotation is euler degrees { pitch, yaw, roll }, one cube per axis
    self:add({ primitive = "cube", x = -4, y = 1.5, z = 0, rotation = { 45, 0, 0 }, scale = 1.5, colour = TINTS[2] })
    self:add({ primitive = "cube", x = 0, y = 1.5, z = 0, rotation = { 0, 45, 0 }, scale = 1.5, colour = TINTS[3] })
    self:add({ primitive = "cube", x = 4, y = 1.5, z = 0, rotation = { 0, 0, 45 }, scale = 1.5, colour = TINTS[4] })

    -- Left casts a shadow, right has cast_shadow = false
    self:add({ primitive = "cube", x = -6, y = 0.5, z = -6, colour = TINTS[1] })
    self:add({ primitive = "cube", x = -3, y = 0.5, z = -6, colour = TINTS[1], cast_shadow = false })

    -- Group of shapes: scale takes one number or { x, y, z }, V hides this group
    self.group = {
        self:add({ primitive = "cube", x = 2, y = 3, z = -6, scale = 2, colour = TINTS[5] }),
        self:add({ primitive = "cube", x = 6, y = 3, z = -6, colour = TINTS[2] }),
    }
    self.spinner, self.stretcher = self.group[1], self.group[2]

    -- Loaded model, 0.008 scales it from centimetres to metres. nil if the file is missing
    self.loaded = self:add({ path = MODEL_PATH, x = 9, z = 2, scale = 1 })

    self.bounds = modit.graphics.new_text({ text = "", x = 20, y = 20 })
    modit.graphics.new_text({ text = "A/D orbit | W/S zoom | T tint | V hide group", x = 20, y = 50, colour = "gray" })
end

--- Update things in game scene here dt = delta time
function scene:update(dt)
    self.time = self.time + dt

    -- Camera controls
    if modit.input.key_down("a") then self.angle = self.angle - 1.5 * dt end
    if modit.input.key_down("d") then self.angle = self.angle + 1.5 * dt end
    if modit.input.key_down("w") then self.distance = math.max(6, self.distance - 8 * dt) end
    if modit.input.key_down("s") then self.distance = math.min(40, self.distance + 8 * dt) end
    self.camera:set_position(math.cos(self.angle) * self.distance, 9, math.sin(self.angle) * self.distance)
    self.camera:set_target(0, 1, 0)

    -- Toggle tint
    if modit.input.key_pressed("t") then
        self.tint_index = self.tint_index % #TINTS + 1
        for i, model in ipairs(self.tinted) do
            model:set_colour(TINTS[(i + self.tint_index - 2) % #TINTS + 1])
        end
    end

    -- Toggle the shape group
    if modit.input.key_pressed("v") then
        self.hidden = not self.hidden
        for _, model in ipairs(self.group) do model:set_visible(not self.hidden) end
    end

    -- Shader uniforms are set by name through the shader asset
    if self.glow then self.glow:set_value("u_time", self.time, "float") end
    self.shader_cube:set_rotation(self.time * 25, self.time * 45, 0)

    -- Rotation and stretch
    self.spinner:set_rotation(self.time * 40, self.time * 70, 0)
    local s = 1 + (math.sin(self.time * 3) + 1) * 0.6
    self.stretcher:set_scale(s, 3 - s, 1)
    if self.loaded then self.loaded:set_rotation(0, self.time * 30, 0) end

    -- World space bounds of the spinning cube, they change as it rotates
    local x0, y0, z0, x1, y1, z1 = self.spinner:get_bounds()
    self.bounds:set_text(string.format("spinner bounds  min %.1f, %.1f, %.1f  max %.1f, %.1f, %.1f", x0, y0, z0, x1, y1, z1))
end

-- Unload things from your game scene here
function scene:unload()
    -- Models and text are cleaned up for you, cached assets and shaders are not
    modit.graphics.set_camera(nil)
    modit.graphics.cleanup_models()
    modit.graphics.cleanup_shaders()
    modit.graphics.reset_environment()
end

return scene