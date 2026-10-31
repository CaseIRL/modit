--[[
    Optimized Bulk-Drawn Physics Stress-Test Sandbox (with Resizable Grid & Correct Strafing)
]]

local scene = {}

function scene:load()
    modit.input.lock_cursor()

    self.camera = modit.graphics.new_camera({ mode = "3d", fov = 60 })
    modit.graphics.set_camera(self.camera)

    self.cam_x, self.cam_y, self.cam_z = 0, 6, -6
    self.yaw = 0.0
    self.pitch = 0.0
    self.cam_speed = 15.0
    self.mouse_sensitivity = 0.003

    -- Stress test wall initial dimensions
    self.grid_width = 10  
    self.grid_height = 12 

    self.crosshair = modit.graphics.new_text({ text = "+", x = 635, y = 350, font_size = 24, colour = "white" })
    self.info = modit.graphics.new_text({ text = "", x = 30, y = 30, font_size = 18, colour = "white" })

    self:reset_sandbox()
end

function scene:clear_visuals()
    -- Remove every model object from the previous sandbox, otherwise they stay in the render list forever
    if self.floor_model then self.floor_model:remove() end
    if self.bulk_model then self.bulk_model:remove() end
    for _, ent in ipairs(self.other_models or {}) do
        if ent.model then ent.model:remove() end
    end
    self.floor_model, self.bulk_model, self.other_models = nil, nil, {}
end

function scene:reset_sandbox()
    self:clear_visuals()

    local s = 0.47
    local vertices = {
        -s,-s, s,  s,-s, s,  s, s, s,  -s,-s, s,  s, s, s,  -s, s, s,
        -s,-s,-s, -s, s,-s,  s, s,-s,  -s,-s,-s,  s, s,-s,  s,-s,-s,
        -s, s,-s, -s, s, s,  s, s, s,  -s, s,-s,  s, s, s,  s, s,-s,
        -s,-s,-s,  s,-s,-s,  s,-s, s,  -s,-s,-s,  s,-s, s, -s,-s, s,
         s,-s,-s,  s, s,-s,  s, s, s,   s,-s,-s,  s, s, s,  s,-s, s,
        -s,-s,-s, -s,-s, s, -s, s, s,  -s,-s,-s, -s, s, s, -s, s,-s
    }

    local normals = {}
    local face_normals = { {0,0,1}, {0,0,-1}, {0,1,0}, {0,-1,0}, {1,0,0}, {-1,0,0} }
    for f = 1, 6 do
        for v = 1, 6 do
            table.insert(normals, face_normals[f][1])
            table.insert(normals, face_normals[f][2])
            table.insert(normals, face_normals[f][3])
        end
    end

    modit.graphics.build_model({ key = "bulk_cube", vertices = vertices, normals = normals })

    if self.world and self.world:is_valid() then
        self.world:clear()
    end

    self.world = modit.physics.new_world({ gravity = { 0, -15, 0 } })

    modit.graphics.set_lighting(true)
    modit.graphics.set_ambient(60, 70, 90)
    modit.graphics.set_sky(20, 24, 33, 100, 115, 140)
    modit.graphics.set_fog(15, 45)
    modit.graphics.set_shadows({ mode = "map", strength = 0.6, range = 50, size = 2048, ground = 0 })
    modit.graphics.set_sun(0.5, -0.8, 0.5, 255, 240, 220)

    -- Floor
    self.world:new_body({
        type = "static",
        position = { 0, 0, 0 },
        shape = { type = "box", size = { 80, 2, 80 }, friction = 0.6 }
    })
    self.floor_model = modit.graphics.new_model({ primitive = "plane", scale = { 40, 1, 40 }, colour = { 38, 42, 52, 255 }, cast_shadow = false })

    -- Voxel Wall Entities & Instances
    self.cube_entities = {}
    self.bulk_list = {}
    
    local block_size = 1.0
    local start_x = -(self.grid_width * block_size) / 2
    local start_y = 1

    for y = 0, self.grid_height - 1 do
        for x = 0, self.grid_width - 1 do
            local bx = start_x + (x * block_size) + (y % 2 * 0.1)
            local by = start_y + (y * block_size) + (block_size / 2)
            local bz = 8.0

            local body = self.world:new_body({
                type = "dynamic",
                position = { bx, by, bz },
                shape = { type = "box", size = { block_size * 0.94, block_size * 0.94, block_size * 0.94 }, density = 1.5, friction = 0.5 }
            })

            -- qx..qw is filled from the body every frame, so no Euler angles are needed
            local inst = { x = bx, y = by, z = bz, qx = 0, qy = 0, qz = 0, qw = 1, scale = block_size * 0.94, colour = { 220, 30, 30, 255 } }
            table.insert(self.cube_entities, { body = body, instance = inst })
            table.insert(self.bulk_list, inst)
        end
    end

    self.bulk_model = modit.graphics.new_bulk({
        key = "bulk_cube",
        instances = self.bulk_list
    })

    -- Other props
    local prev_body = self.world:new_body({
        type = "static",
        position = { -10, 12, 0 },
        shape = { type = "sphere", radius = 0.2 }
    })

    for i = 1, 6 do
        local link_body = self.world:new_body({
            type = "dynamic",
            position = { -10, 12 - (i * 1.0), 0 },
            shape = { type = "box", size = { 0.6, 0.6, 0.6 }, density = 1.0 }
        })
        self.world:new_spherical_joint(prev_body, link_body, { anchor_a = { 0, -0.5, 0 }, anchor_b = { 0, 0.5, 0 } })
        local model = modit.graphics.new_model({ primitive = "cube", scale = { 0.6, 0.6, 0.6 }, colour = { 200, 200, 200, 255 } })
        table.insert(self.other_models, { body = link_body, model = model })
        prev_body = link_body
    end

    local total_cubes = self.grid_width * self.grid_height
    self.info:set_text(string.format("Cubes: %d (%dx%d) | [WASD+Mouse] Fly | [ARROWS] Resize Grid | [L-CLICK] Ball | [F] Explode | [R] Reset", total_cubes, self.grid_width, self.grid_height))
end

function scene:update(dt)
    local dx, dy = modit.input.get_mouse_delta()
    self.yaw = self.yaw - dx * self.mouse_sensitivity
    self.pitch = math.max(-1.5, math.min(1.5, self.pitch - dy * self.mouse_sensitivity))

    local forward_x = math.sin(self.yaw) * math.cos(self.pitch)
    local forward_y = math.sin(self.pitch)
    local forward_z = math.cos(self.yaw) * math.cos(self.pitch)

    local right_x = math.cos(self.yaw)
    local right_z = -math.sin(self.yaw)

    local move_speed = self.cam_speed * dt
    if modit.input.key_down("w") then
        self.cam_x = self.cam_x + forward_x * move_speed
        self.cam_y = self.cam_y + forward_y * move_speed
        self.cam_z = self.cam_z + forward_z * move_speed
    end
    if modit.input.key_down("s") then
        self.cam_x = self.cam_x - forward_x * move_speed
        self.cam_y = self.cam_y - forward_y * move_speed
        self.cam_z = self.cam_z - forward_z * move_speed
    end
    -- Corrected strafe bindings
    if modit.input.key_down("a") then
        self.cam_x = self.cam_x + right_x * move_speed
        self.cam_z = self.cam_z + right_z * move_speed
    end
    if modit.input.key_down("d") then
        self.cam_x = self.cam_x - right_x * move_speed
        self.cam_z = self.cam_z - right_z * move_speed
    end
    if modit.input.key_down("space") then self.cam_y = self.cam_y + move_speed end
    if modit.input.key_down("leftctrl") then self.cam_y = self.cam_y - move_speed end

    self.camera:set_position(self.cam_x, self.cam_y, self.cam_z)
    self.camera:set_target(self.cam_x + forward_x, self.cam_y + forward_y, self.cam_z + forward_z)

    -- Grid resizing controls
    local resized = false
    if modit.input.key_pressed("arrowleft") then
        self.grid_width = math.max(2, self.grid_width - 2)
        resized = true
    end
    if modit.input.key_pressed("arrowright") then
        self.grid_width = self.grid_width + 2
        resized = true
    end
    if modit.input.key_pressed("arrowdown") then
        self.grid_height = math.max(2, self.grid_height - 2)
        resized = true
    end
    if modit.input.key_pressed("arrowup") then
        self.grid_height = self.grid_height + 2
        resized = true
    end

    if resized or modit.input.key_pressed("r") then
        self:reset_sandbox()
        return
    end

    if modit.input.key_pressed("f") then
        self.world:explode({ position = { 0, 4, 8 }, radius = 12.0, impulse = 200.0, falloff = 4.0 })
    end

    if modit.input.mouse_pressed("left") then
        local spawn_x, spawn_y, spawn_z = self.cam_x, self.cam_y, self.cam_z
        local ball_body = self.world:new_body({
            type = "dynamic",
            position = { spawn_x, spawn_y, spawn_z },
            shape = { type = "sphere", radius = 0.5, density = 4.0, restitution = 0.6 }
        })
        local speed = 50.0
        ball_body:set_velocity(forward_x * speed, forward_y * speed, forward_z * speed)
        local ball_model = modit.graphics.new_model({ primitive = "sphere", scale = 1.0, colour = { 255, 255, 255, 255 } })
        table.insert(self.other_models, { body = ball_body, model = ball_model })
    end

    for _, ent in ipairs(self.other_models) do
        if ent.body and ent.body:is_valid() and ent.model then
            local x, y, z = ent.body:get_position()
            local pitch, yaw, roll = ent.body:get_rotation()
            ent.model:set_position(x, y, z)
            ent.model:set_rotation(pitch, yaw, roll)
        end
    end

    for _, ent in ipairs(self.cube_entities) do
        if ent.body and ent.body:is_valid() then
            -- Interpolated position and quaternion straight into the instance
            ent.body:write_render_transform(ent.instance)
        end
    end
end

function scene:unload()
    modit.input.unlock_cursor()
    modit.graphics.set_camera(nil)
    modit.graphics.cleanup_models()
    modit.graphics.reset_environment()
end

return scene