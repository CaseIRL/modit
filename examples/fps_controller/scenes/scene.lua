--[[

    Modit FPS Controller Example
    ----------------------------

    A full example of a FPS controller.
    Modeled on the raylib example, covers pretty much everything.

    - 60 Hz fixed-step movement
    - render-rate interpolation
    - constant-rate acceleration
    - momentum-preserving air control
    - coyote time
    - head bob and lean
    - sprint
    - chrouch
    - prone
    - jump
]]

--- @section Constants

-- Settings that control camera sensitivity, movement speeds, and physics rules
local LOOK_SPEED = 0.003
local PITCH_LIMIT = math.rad(89)
local BASE_FOV = 70

local SIM_DT = 1 / 60
local EPSILON = 0.0001
local MAX_STEP_DISTANCE = 0.3 -- Max distance moved per collision slice (prevents walking through walls)

local SPAWN_X, SPAWN_Y, SPAWN_Z = 0, 0, 0

local SETTINGS = {
    -- Player size and height adjustments for standing, crouching, and lying down
    radius = 0.4,
    standing_height = 1.8,
    crouching_height = 1.0,
    prone_height = 0.6,
    standing_eye_height = 1.62,
    crouching_eye_height = 0.85,
    prone_eye_height = 0.5,
    step_height = 0.45,

    -- Ground movement speeds (units per second)
    run_speed = 10,
    sprint_speed = 16,
    crouch_speed = 5,
    prone_speed = 3,

    -- How fast the player speeds up or slows down
    ground_accel = 75,
    ground_decel = 90,
    air_accel = 30, 
    max_horizontal_speed = 45,

    -- Jumping and falling gravity rules
    gravity = 32,
    max_fall_speed = 50,
    jump_speed = 12,
    jump_cut_speed = 4,
    air_jumps = 0,
    air_jump_speed = 10,
    coyote_time = 0.1,
    jump_buffer_time = 0.12,
}

-- Camera look and feel settings (head bobbing, leaning, and smooth view transitions)
local EYE_BLEND_RATE = 14
local VIEW_RECOVER_RATE = 10
local VIEW_OFFSET_LIMIT = 0.5
local STEP_DETECT = 0.02
local LAND_DIP_SCALE = 0.008
local LAND_DIP_MAX = 0.12
local BOB_RATE = 3
local BOB_MIN_SPEED = 1
local BOB_SIDE, BOB_UP, BOB_ROLL = 0.1, 0.15, 0.01
local LEAN_ROLL, LEAN_PITCH = 0.02, 0.015
local LEAN_BLEND_RATE = 10
local WALK_BLEND_RATE = 10

-- Colors and layout for the map (floors, walls, and blocks)
local FLOOR_COLOR = { 60, 140, 70, 255 }
local WALL_COLOR = { 90, 100, 120, 255 }
local CRATE_BLUE = { 60, 100, 220, 255 }
local CRATE_RED = { 220, 70, 60, 255 }
local CRATE_YELLOW = { 230, 200, 50, 255 }

--- @section Initialisation

local scene = {}

local level = {
    kill_height = -50, -- Resets the player if they fall past this point
    boxes = {
        { min_x = -50, max_x = 50, min_y = -2, max_y = 0, min_z = -50, max_z = 50 },
        { min_x = -1.5, max_x = 1.5, min_y = 0, max_y = 3, min_z = 6, max_z = 9 },
        { min_x = 5, max_x = 9, min_y = 0, max_y = 2.5, min_z = 3, max_z = 7 },
        { min_x = -9, max_x = -5, min_y = 0, max_y = 4, min_z = 4, max_z = 8 },
        { min_x = 12, max_x = 15, min_y = 0, max_y = 0.4, min_z = -4, max_z = 4 },
        { min_x = 15, max_x = 18, min_y = 0, max_y = 0.8, min_z = -4, max_z = 4 },
        { min_x = 18, max_x = 21, min_y = 0, max_y = 1.2, min_z = -4, max_z = 4 },
    }
}

--- @section Helpers

-- Keeps a value constrained within a minimum and maximum range
local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

-- Calculates how fast the player is moving across the ground plane
local function horizontal_speed(state)
    return math.sqrt(state.vx * state.vx + state.vz * state.vz)
end

-- Figures out the correct player height depending on stance (standing, crouching, or prone)
local function hull_height(state)
    if state.prone then return SETTINGS.prone_height end
    return state.crouching and SETTINGS.crouching_height or SETTINGS.standing_height
end

-- Checks if the player is touching a specific level box
local function overlaps_box(box, x, y, z, radius, height)
    return x + radius > box.min_x and x - radius < box.max_x and y + height > box.min_y and y < box.max_y and z + radius > box.min_z and z - radius < box.max_z
end

-- Finds any wall or box blocking the player's position
local function find_blocking_box(x, y, z, radius, height)
    for i = 1, #level.boxes do
        if overlaps_box(level.boxes[i], x, y, z, radius, height) then return level.boxes[i] end
    end
    return nil
end

--- Turns movement keys and camera angles into a walking direction vector
local function wish_direction(command)
    local forward_axis, right_axis = command.move_z or 0, command.move_x or 0
    local sin_yaw, cos_yaw = math.sin(command.yaw), math.cos(command.yaw)
    local wish_x = sin_yaw * forward_axis - cos_yaw * right_axis
    local wish_z = cos_yaw * forward_axis + sin_yaw * right_axis
    local length = math.sqrt(wish_x * wish_x + wish_z * wish_z)
    if length < 1e-6 then return 0, 0 end
    if length > 1 then return wish_x / length, wish_z / length end
    return wish_x, wish_z
end

-- Resets the player back to the starting spawn point and clears all speeds/timers
local function reset_state(state)
    state.x, state.y, state.z = SPAWN_X, SPAWN_Y, SPAWN_Z
    state.prev_x, state.prev_y, state.prev_z = SPAWN_X, SPAWN_Y, SPAWN_Z
    state.vx, state.vy, state.vz = 0, 0, 0
    state.on_ground = true
    state.crouching, state.prone, state.fell = false, false, false
    state.ground_grace = SETTINGS.coyote_time
    state.jump_buffer = 0
    state.jump_rising = false
    state.air_jumps_left = SETTINGS.air_jumps
    state.eye_height = SETTINGS.standing_eye_height
    state.view_offset = 0
    state.head_timer, state.walk_blend = 0, 0
    state.lean_roll, state.lean_pitch = 0, 0
end

-- Drops the player straight down onto the ground if they are standing right above a surface
local function drop_to_ground(state, max_distance)
    local height = hull_height(state)
    local target_y = state.y - max_distance
    local highest_top = nil
    for i = 1, #level.boxes do
        local box = level.boxes[i]
        if overlaps_box(box, state.x, target_y, state.z, SETTINGS.radius, height) then
            if highest_top == nil or box.max_y > highest_top then highest_top = box.max_y end
        end
    end
    if highest_top == nil then return false end
    state.y = highest_top + EPSILON
    return true
end

-- Pushes the player out of walls horizontally so they don't clip through them
local function push_out_horizontal(state, axis, delta, new_x, new_z, height)
    local radius = SETTINGS.radius
    local limit = nil
    for i = 1, #level.boxes do
        local box = level.boxes[i]
        if overlaps_box(box, new_x, state.y, new_z, radius, height) then
            local candidate
            if axis == "x" then
                candidate = delta > 0 and (box.min_x - radius - EPSILON) or (box.max_x + radius + EPSILON)
            else
                candidate = delta > 0 and (box.min_z - radius - EPSILON) or (box.max_z + radius + EPSILON)
            end
            if limit == nil or (delta > 0 and candidate < limit) or (delta < 0 and candidate > limit) then limit = candidate end
        end
    end
    if axis == "x" then
        state.x = limit or state.x
        state.vx = 0
    else
        state.z = limit or state.z
        state.vz = 0
    end
end

-- Handles horizontal movement and allows stepping up small ledges automatically
local function move_horizontal(state, axis, delta)
    if delta == 0 then return end
    local height = hull_height(state)
    local new_x, new_z = state.x, state.z
    if axis == "x" then new_x = new_x + delta else new_z = new_z + delta end

    if not find_blocking_box(new_x, state.y, new_z, SETTINGS.radius, height) then
        state.x, state.z = new_x, new_z
        return
    end

    -- Automatically step up small blocks while walking on the ground
    if state.on_ground then
        local raised_y = state.y + SETTINGS.step_height
        if not find_blocking_box(new_x, raised_y, new_z, SETTINGS.radius, height) then
            state.x, state.z, state.y = new_x, new_z, raised_y
            if not drop_to_ground(state, SETTINGS.step_height) then
                state.y = raised_y - SETTINGS.step_height
            end
            return
        end
    end

    push_out_horizontal(state, axis, delta, new_x, new_z, height)
end

-- Handles vertical movement
local function move_vertical(state, delta, events)
    local height = hull_height(state)
    local new_y = state.y + delta
    local landing_y, ceiling_y = nil, nil

    for i = 1, #level.boxes do
        local box = level.boxes[i]
        if overlaps_box(box, state.x, new_y, state.z, SETTINGS.radius, height) then
            if delta < 0 then
                if landing_y == nil or box.max_y + EPSILON > landing_y then landing_y = box.max_y + EPSILON end
            else
                if ceiling_y == nil or box.min_y - height - EPSILON < ceiling_y then ceiling_y = box.min_y - height - EPSILON end
            end
        end
    end

    if delta < 0 and landing_y then
        state.y = landing_y
        if not state.on_ground then
            events.landed = true
            events.impact_speed = -state.vy
        end
        state.on_ground = true
        state.vy = 0
    elseif delta > 0 and ceiling_y then
        state.y = ceiling_y
        if state.vy > 0 then state.vy = 0 end
        state.jump_rising = false
    else
        state.y = new_y
    end
end

-- Runs collision checks step-by-step
local function move_with_collision(state, events)
    local fastest = math.max(math.abs(state.vx), math.abs(state.vy), math.abs(state.vz))
    local slice_count = math.max(1, math.ceil(fastest * SIM_DT / MAX_STEP_DISTANCE))
    local slice_dt = SIM_DT / slice_count

    for _ = 1, slice_count do
        move_horizontal(state, "x", state.vx * slice_dt)
        move_horizontal(state, "z", state.vz * slice_dt)

        -- Stick smoothly to the ground when walking down slopes or small drops
        local snapped = false
        if state.on_ground and state.vy <= 0 then
            snapped = drop_to_ground(state, SETTINGS.step_height)
        end

        if snapped then
            state.vy = 0
        else
            state.on_ground = false
            move_vertical(state, state.vy * slice_dt, events)
        end
    end
end

-- Updates jumping and falling grace timers
local function update_timers(state)
    state.ground_grace = state.ground_grace - SIM_DT
    state.jump_buffer = state.jump_buffer - SIM_DT
end

-- Changes player posture between standing, crouching, and lying prone
local function update_stances(state, command)
    if command.prone then
        state.prone = true
        state.crouching = false
    elseif command.crouch then
        state.crouching = true
        state.prone = false
    else
        -- Only stand back up if there is enough ceiling clearance
        if state.prone or state.crouching then
            if not find_blocking_box(state.x, state.y, state.z, SETTINGS.radius, SETTINGS.standing_height) then
                state.prone = false
                state.crouching = false
            end
        end
    end
end

-- Handles jump inputs and lets players jump shortly after walking off ledges
local function update_jump(state, command, events)
    if command.jump_pressed then state.jump_buffer = SETTINGS.jump_buffer_time end

    if state.jump_buffer > 0 then
        local jump_speed = nil

        if state.on_ground or state.ground_grace > 0 then
            jump_speed = SETTINGS.jump_speed
            state.ground_grace = 0
        elseif command.jump_pressed and state.air_jumps_left > 0 then
            jump_speed = SETTINGS.air_jump_speed
            state.air_jumps_left = state.air_jumps_left - 1
        end

        if jump_speed then
            state.vy = jump_speed
            state.on_ground = false
            state.jump_buffer = 0
            state.jump_rising = true
            state.crouching = false
            state.prone = false
            events.jumped = true
        end
    end

    -- Shortens jump height if you let go of the jump key early
    if state.jump_rising then
        if state.vy <= 0 then
            state.jump_rising = false
        elseif not command.jump and state.vy > SETTINGS.jump_cut_speed then
            state.vy = SETTINGS.jump_cut_speed
            state.jump_rising = false
        end
    end
end

-- Smoothly changes horizontal speed toward a target rate
local function approach_velocity(state, target_x, target_z, rate)
    local dx, dz = target_x - state.vx, target_z - state.vz
    local distance = math.sqrt(dx * dx + dz * dz)
    local max_change = rate * SIM_DT
    if distance <= max_change then
        state.vx, state.vz = target_x, target_z
    else
        local scale = max_change / distance
        state.vx = state.vx + dx * scale
        state.vz = state.vz + dz * scale
    end
end

-- Determines maximum movement speed depending on current stance and sprinting
local function ground_speed_limit(state, command)
    if state.prone then return SETTINGS.prone_speed end
    if state.crouching then return SETTINGS.crouch_speed end
    if command.sprint then return SETTINGS.sprint_speed end
    return SETTINGS.run_speed
end

-- Accelerates or brakes the player while on the ground
local function accelerate_ground(state, wish_x, wish_z, command)
    local wish_length = math.sqrt(wish_x * wish_x + wish_z * wish_z)
    local limit = ground_speed_limit(state, command)
    local target_x, target_z = wish_x * limit, wish_z * limit
    local target_speed = wish_length * limit
    local speed = horizontal_speed(state)

    local reversing = (state.vx * target_x + state.vz * target_z) < 0
    local rate = (target_speed < speed - 0.01 or reversing) and SETTINGS.ground_decel or SETTINGS.ground_accel
    approach_velocity(state, target_x, target_z, rate)
end

-- Allows limited steering control while in mid-air without losing momentum
local function accelerate_air(state, wish_x, wish_z)
    local wish_length = math.sqrt(wish_x * wish_x + wish_z * wish_z)
    if wish_length < 1e-6 then return end

    local dir_x, dir_z = wish_x / wish_length, wish_z / wish_length
    local limit = SETTINGS.run_speed * wish_length
    local current = state.vx * dir_x + state.vz * dir_z
    local add = limit - current
    if add <= 0 then return end

    add = math.min(add, SETTINGS.air_accel * SIM_DT)
    state.vx = state.vx + dir_x * add
    state.vz = state.vz + dir_z * add
end

-- Updates overall player velocity and applies gravity when falling
local function update_velocity(state, wish_x, wish_z, command)
    if state.on_ground then
        accelerate_ground(state, wish_x, wish_z, command)
    else
        accelerate_air(state, wish_x, wish_z)
    end

    local speed = horizontal_speed(state)
    if speed > SETTINGS.max_horizontal_speed then
        local scale = SETTINGS.max_horizontal_speed / speed
        state.vx, state.vz = state.vx * scale, state.vz * scale
    end

    if state.on_ground then
        if state.vy < 0 then state.vy = 0 end
    else
        state.vy = math.max(state.vy - SETTINGS.gravity * SIM_DT, -SETTINGS.max_fall_speed)
    end
end

-- Performs a single fixed-step movement calculation
local function movement_step(state, command)
    local events = {}
    local wish_x, wish_z = wish_direction(command)

    update_timers(state)
    update_stances(state, command)
    update_jump(state, command, events)
    update_velocity(state, wish_x, wish_z, command)
    move_with_collision(state, events)

    if state.on_ground then
        state.ground_grace = SETTINGS.coyote_time
        state.air_jumps_left = SETTINGS.air_jumps
        state.jump_rising = false
    end
    state.fell = state.y < level.kill_height
    return events
end

--- @section Scene

-- Helper function to create text labels on the screen
function scene:label(text, x, y)
    return modit.graphics.new_text({ text = text, font = self.font, x = x, y = y, colour = { 160, 170, 185, 255 } })
end

-- Sets up the map, lighting, player camera
function scene:load()
    self.font = modit.graphics.load_font("assets/fonts/JetBrainsMono-Regular.ttf", 16)
    self.accumulator = 0
    self.jump_latched = false
    self.first_frame = true

    self.yaw = 0
    self.pitch = 0

    self.state = {}
    reset_state(self.state)

    -- Locks cursor to window
    modit.input.lock_cursor()

    -- Set up 3d camera
    self.camera = modit.graphics.new_camera({ mode = "3d", x = 0, y = 3, z = 10, fov = BASE_FOV })
    modit.graphics.set_camera(self.camera)

    -- Lighting, sky, and shadow settings
    modit.graphics.set_lighting(true)
    modit.graphics.set_sun(-0.5, -0.8, -0.3, 255, 240, 220)
    modit.graphics.set_ambient(60, 70, 90)
    modit.graphics.set_sky(20, 24, 33, 100, 115, 140)
    modit.graphics.set_shadows({ mode = "map", strength = 0.6, range = 60, size = 2048, ground = 0 })

    -- Spawns the floor and colored crates/walls in the world
    modit.graphics.new_model({ primitive = "plane", scale = { 100, 1, 100 }, colour = FLOOR_COLOR, cast_shadow = false })
    modit.graphics.new_model({ primitive = "cube", x = 0, y = 1.5, z = 7.5, scale = { 3, 3, 3 }, colour = CRATE_BLUE })
    modit.graphics.new_model({ primitive = "cube", x = 7, y = 1.25, z = 5, scale = { 4, 2.5, 4 }, colour = CRATE_RED })
    modit.graphics.new_model({ primitive = "cube", x = -7, y = 2, z = 6, scale = { 4, 4, 4 }, colour = CRATE_YELLOW })

    for i = 1, 3 do
        modit.graphics.new_model({
            primitive = "cube",
            x = 12 + (i - 1) * 3 + 1.5,
            y = (i * 0.4) / 2,
            z = 0,
            scale = { 3, i * 0.4, 8 },
            colour = WALL_COLOR
        })
    end

    -- Creates a crosshair in the center of the screen
    local screen_w, screen_h = modit.graphics.get_screen_size()
    local cx, cy = screen_w / 2, screen_h / 2
    modit.graphics.new_shape("rectangle", {
        x = cx - 10, y = cy - 1, width = 20, height = 2, space = "screen", colour = { 255, 255, 255, 230 }
    })
    modit.graphics.new_shape("rectangle", {
        x = cx - 1, y = cy - 10, width = 2, height = 20, space = "screen", colour = { 255, 255, 255, 230 }
    })

    self.info = self:label("", 10, 34)
    self:label("w/a/s/d: Move | leftshift: Sprint | space: Jump | leftctrl/c: Crouch | x: Prone", 10, screen_h - 30)
end

-- Updates player input, camera movement, and physics every frame
function scene:update(dt)
    if _G.console_open then return end
    local state = self.state

    -- Ensures quick jump button presses are never missed between physics updates
    if modit.input.key_pressed("space") then
        self.jump_latched = true
    end

    local dx, dy = modit.input.get_mouse_delta()
    if self.first_frame then
        dx, dy = 0, 0
        self.first_frame = false
    end

    -- Updates camera view rotation based on mouse movement
    self.yaw = self.yaw - dx * LOOK_SPEED
    self.pitch = clamp(self.pitch - dy * LOOK_SPEED, -PITCH_LIMIT, PITCH_LIMIT)

    local move_x, move_z = 0, 0
    if modit.input.key_down("w") then move_z = move_z + 1 end
    if modit.input.key_down("s") then move_z = move_z - 1 end
    if modit.input.key_down("a") then move_x = move_x - 1 end
    if modit.input.key_down("d") then move_x = move_x + 1 end

    local input_len = math.sqrt(move_x * move_x + move_z * move_z)
    if input_len > 1 then
        move_x = move_x / input_len
        move_z = move_z / input_len
    end

    -- Step accumulator
    self.accumulator = self.accumulator + math.min(dt, 0.1)
    while self.accumulator >= SIM_DT do
        self.accumulator = self.accumulator - SIM_DT

        local was_on_ground = state.on_ground
        local y_before = state.y
        state.prev_x, state.prev_y, state.prev_z = state.x, state.y, state.z

        local events = movement_step(state, {
            move_x = move_x,
            move_z = move_z,
            yaw = self.yaw,
            pitch = self.pitch,
            jump = modit.input.key_down("space"),
            jump_pressed = self.jump_latched,
            crouch = modit.input.key_down("leftctrl") or modit.input.key_down("c"),
            sprint = modit.input.key_down("leftshift"),
            prone = modit.input.key_down("x"),
        })
        self.jump_latched = false

        -- Smooths out camera movement when walking up or down stairs
        if was_on_ground and state.on_ground then
            local step = state.y - y_before
            if math.abs(step) > STEP_DETECT then
                state.prev_y = state.y
                state.view_offset = clamp(state.view_offset - step, -VIEW_OFFSET_LIMIT, VIEW_OFFSET_LIMIT)
            end
        end

        -- Dips the camera slightly when landing from a fall
        if events.landed then
            local dip = math.min(LAND_DIP_MAX, (events.impact_speed or 0) * LAND_DIP_SCALE)
            state.view_offset = math.max(-VIEW_OFFSET_LIMIT, state.view_offset - dip)
        end

        if state.fell then
            reset_state(state)
        end
    end

    -- Render-rate camera work (smooth visuals and head bobbing)
    local alpha = self.accumulator / SIM_DT
    local render_x = state.prev_x + (state.x - state.prev_x) * alpha
    local render_y = state.prev_y + (state.y - state.prev_y) * alpha
    local render_z = state.prev_z + (state.z - state.prev_z) * alpha

    state.view_offset = state.view_offset * math.exp(-VIEW_RECOVER_RATE * dt)
    if math.abs(state.view_offset) < 0.0005 then state.view_offset = 0 end

    -- Smooth eye height adjustments when crouching or standing up
    local target_eye_height = SETTINGS.standing_eye_height
    if state.prone then
        target_eye_height = SETTINGS.prone_eye_height
    elseif state.crouching then
        target_eye_height = SETTINGS.crouching_eye_height
    end
    state.eye_height = state.eye_height + (target_eye_height - state.eye_height) * math.min(1, EYE_BLEND_RATE * dt)

    -- Adds head bobbing motion when walking
    local speed = horizontal_speed(state)
    local walking = state.on_ground and speed > BOB_MIN_SPEED
    if walking then
        state.head_timer = state.head_timer + dt * BOB_RATE * clamp(speed / 12, 0.3, 1.6)
    end
    state.walk_blend = state.walk_blend + ((walking and 1 or 0) - state.walk_blend) * math.min(1, WALK_BLEND_RATE * dt)

    -- Adds leaning effects when moving sideways or forward/backward
    local yaw, pitch = self.yaw, self.pitch
    local right_speed = -state.vx * math.cos(yaw) + state.vz * math.sin(yaw)
    local forward_speed = state.vx * math.sin(yaw) + state.vz * math.cos(yaw)
    local lean_blend = math.min(1, LEAN_BLEND_RATE * dt)
    state.lean_roll = state.lean_roll + (right_speed / SETTINGS.run_speed * LEAN_ROLL - state.lean_roll) * lean_blend
    state.lean_pitch = state.lean_pitch + (forward_speed / SETTINGS.run_speed * LEAN_PITCH - state.lean_pitch) * lean_blend

    local bob_phase = state.head_timer * math.pi
    local head_sin, head_cos = math.sin(bob_phase), math.cos(bob_phase)
    local bob_amount = state.walk_blend

    local right_x, right_z = -math.cos(yaw), math.sin(yaw)
    local eye_x = render_x + right_x * head_sin * BOB_SIDE * bob_amount
    local eye_y = render_y + state.view_offset + state.eye_height + math.abs(head_cos) * BOB_UP * bob_amount
    local eye_z = render_z + right_z * head_sin * BOB_SIDE * bob_amount

    local view_pitch = clamp(pitch - state.lean_pitch, -PITCH_LIMIT, PITCH_LIMIT)
    local flat = math.cos(view_pitch)
    local forward_x, forward_y, forward_z = math.sin(yaw) * flat, math.sin(view_pitch), math.cos(yaw) * flat

    -- Applies final position and angles to the camera
    self.camera:set_position(eye_x, eye_y, eye_z)
    self.camera:set_target(eye_x + forward_x, eye_y + forward_y, eye_z + forward_z)
    self.camera:set_fov(BASE_FOV)

    if self.camera.set_up then
        local roll = head_sin * BOB_ROLL * state.walk_blend + state.lean_roll
        local cos_roll, sin_roll = math.cos(roll), math.sin(roll)
        local along = forward_y * (1 - cos_roll)
        self.camera:set_up(-forward_z * sin_roll + forward_x * along, cos_roll + forward_y * along, forward_x * sin_roll + forward_z * along)
    end

    -- Updates the on-screen coordinate and speed info text
    self.info:set_text(string.format("pos %.1f, %.1f, %.1f   speed %.1f   ground %s", state.x, state.y, state.z, speed, tostring(state.on_ground)))
end

function scene:frame()
end

-- Cleans up models, assets, and resets settings when leaving the scene
function scene:unload()
    modit.graphics.set_camera(nil)
    modit.graphics.cleanup_models()
    modit.graphics.reset_environment()
    if self.font then
        self.font:unload()
    end
    modit.input.unlock_cursor()
end

return scene