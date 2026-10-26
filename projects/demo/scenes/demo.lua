--- @file scenes/demo.lua
--- @description Simple demo scene to test modules. 

--- @section Constants


local IMG = "assets/images/"
local TITLE_IMAGE = IMG .. "fps_title.png"
local ICON_IMAGE = IMG .. "modit_icon_32x32.png"
local SHEET_IMAGE = IMG .. "rpg_base_character_16.png"

--@todo Add way to get screen size from sdk
local SCREEN_W, SCREEN_H = 1280, 720

local SPEED = 240
local ZOOM_LEVELS = { 0.5, 1, 2, 3 }
local MOVES = { front = { 0, 1 }, back = { 0, -1 }, left = { -1, 0 }, right = { 1, 0 } }
local GREY = { 160, 170, 185, 255 }
local WHITE = { 255, 255, 255, 255 }

--- @section Scene

local scene = {}

--- @section Helpers

local function set_group(group, active)
    for _, obj in ipairs(group) do
        obj.active = active
    end
end

function scene:label(text, x, y)
    local txt = modit.graphics.new_text({ text = text, font = self.font, x = x, y = y, colour = GREY })
    table.insert(self.gallery, txt)
    return txt
end

function scene:icon(config)
    config.path = ICON_IMAGE
    local img = modit.graphics.new_image(config)
    table.insert(self.gallery, img)
    return img
end

--- @section Loading

function scene:load()
    self.font = modit.graphics.load_font("assets/fonts/JetBrainsMono-Regular.ttf", 16)

    self.state = "title"
    self.time = 0
    self.title = {}
    self.gallery = {}

    self.camera = modit.graphics.new_camera({ mode = "2d" })
    self.zoom_index = 2
    self:build_title()
    self:build_world()
    self:build_gallery()
    self:build_character()

    self:set_state("title")
end

function scene:build_title()
    self.title_bg = modit.graphics.new_image({
        path = TITLE_IMAGE,
        filter = "bilinear",
        x = 0, y = 0,
        width = SCREEN_W, height = SCREEN_H,
        layer = -10,
    })
    table.insert(self.title, self.title_bg)

    self.logo = modit.graphics.new_image({
        path = ICON_IMAGE,
        x = SCREEN_W / 2, y = SCREEN_H / 2 - 120,
        scale = 8,
        origin = { 16, 16 },
        layer = 5,
    })
    table.insert(self.title, self.logo)

    self.prompt = modit.graphics.new_text({
        text = "Press ENTER to start",
        font = self.font,
        x = SCREEN_W / 2 - 80, y = SCREEN_H / 2 + 100,
        colour = WHITE,
        layer = 6,
    })
    table.insert(self.title, self.prompt)

    if not self.title_bg.texture then
        local note = modit.graphics.new_text({
            text = "title image not found in " .. IMG,
            font = self.font,
            x = 20, y = 20,
            colour = { 255, 120, 120, 255 },
            layer = 6,
        })
        table.insert(self.title, note)
    end
end

function scene:build_gallery()
    -- Filter test
    self:icon({ x = 60, y = 120, scale = 4 })
    self:icon({ x = 220, y = 120, scale = 4, filter = "bilinear" })
    self:label("point", 60, 260)
    self:label("bilinear", 220, 260)

    -- Tint and flip
    self:icon({ x = 380, y = 120, scale = 4, tint = { 255, 110, 110, 255 }, flip_x = true })
    self:label("tint + flip", 380, 260)

    -- No scale
    self:icon({ x = 540, y = 120, width = 32, height = 32 })
    self:label("width/height", 540, 260)

    -- Rotate
    self.spinner = self:icon({ x = 880, y = 184, scale = 4, origin = { 16, 16 } })
    self:label("origin + rotation", 810, 260)

    -- Layer test
    self:icon({ x = 1010, y = 120, scale = 4, layer = 2, tint = { 110, 160, 255, 255 } })
    self:icon({ x = 1050, y = 150, scale = 4, layer = 1, tint = { 255, 200, 90, 255 } })
    self:label("layer 2 over 1", 1010, 260)
end

--- @section World

function scene:build_world()
    local size, count = 128, 12
    local half = size * count / 2
    for ty = 0, count - 1 do
        for tx = 0, count - 1 do
            local dark = (tx + ty) % 2 == 0
            local tile = modit.graphics.new_shape("rectangle", {
                x = tx * size - half, y = ty * size - half,
                width = size, height = size,
                colour = dark and { 34, 38, 48, 255 } or { 46, 52, 66, 255 },
                layer = -5,
                space = "world",
            })
            table.insert(self.gallery, tile)
        end
    end
end

--- @section Sprite

function scene:build_character()
    local animations = {
        idle_front = { y = 0, frames = 2, fps = 4, loop = true },
        idle_back = { y = 1, frames = 2, fps = 4, loop = true },
        idle_right = { y = 2, frames = 2, fps = 4, loop = true },
        idle_left = { y = 3, frames = 2, fps = 4, loop = true },
        walk_front = { y = 4, frames = 4, fps = 6, loop = true },
        walk_back = { y = 5, frames = 4, fps = 6, loop = true },
        walk_right = { y = 6, frames = 4, fps = 6, loop = true },
        walk_left = { y = 7, frames = 4, fps = 6, loop = true },
        jump_front = { y = 8, frames = 4, fps = 8, loop = false },
        jump_back = { y = 9, frames = 4, fps = 8, loop = false },
        jump_right = { y = 10, frames = 4, fps = 8, loop = false },
        jump_left = { y = 11, frames = 4, fps = 8, loop = false },
        death_front = { y = 12, frames = 4, fps = 6, loop = false },
        death_back = { y = 13, frames = 4, fps = 6, loop = false },
        death_right = { y = 14, frames = 4, fps = 6, loop = false },
        death_left = { y = 15, frames = 4, fps = 6, loop = false },
        chop_front_left = { y = 16, frames = 4, fps = 8, loop = false },
        chop_front_right = { y = 17, frames = 4, fps = 8, loop = false },
        chop_back_right = { y = 18, frames = 4, fps = 8, loop = false },
        chop_back_left = { y = 19, frames = 4, fps = 8, loop = false },
        chop_right = { y = 20, frames = 4, fps = 8, loop = false },
        chop_left = { y = 21, frames = 4, fps = 8, loop = false },
        pickup_front = { y = 22, frames = 4, fps = 8, loop = false },
        pickup_back = { y = 23, frames = 4, fps = 8, loop = false },
        pickup_right = { y = 24, frames = 4, fps = 8, loop = false },
        pickup_left = { y = 25, frames = 4, fps = 8, loop = false },
    }

    self.character = modit.graphics.new_image({
        path = SHEET_IMAGE,
        x = 0, y = 0,
        scale = 8,
        origin = { 8, 8 },
        space = "world",
        frame_width = 16, frame_height = 16,
        animations = animations,
        animation = "idle_front",
    })
    table.insert(self.gallery, self.character)

    self.pos_x, self.pos_y = 0, 0
    self.facing = "front"
    self.action = false

    self:label("WASD/arrows walk | J jump | C chop | P pickup | X death | Q/E zoom | ESC title", 20, SCREEN_H - 100)
    self.status = self:label("Animation: idle_front", 20, SCREEN_H - 70)
    self.mouse_text = self:label("mouse world: 0, 0", 20, SCREEN_H - 40)
end

--- @section State

function scene:set_state(state)
    self.state = state
    set_group(self.title, state == "title")
    set_group(self.gallery, state == "play")
    modit.graphics.set_camera(state == "play" and self.camera or nil)
end

--- @section Update

function scene:update(dt)
    self.time = self.time + dt

    if self.state == "title" then
        self:update_title()
    else
        self:update_play(dt)
    end
end

function scene:update_title()
    self.logo:set_scale(8 + math.sin(self.time * 2) * 0.4)
    self.logo:set_rotation(math.sin(self.time) * 6)
    self.prompt.active = math.floor(self.time * 2) % 2 == 0

    if modit.input.key_pressed("enter") then
        self:set_state("play")
    end
end

function scene:update_play(dt)
    self.spinner:set_rotation(self.time * 90)

    if modit.input.key_pressed("escape") then
        self:set_state("title")
        return
    end

    if self.action then
        if self.character.playing then
            self:update_camera()
            return
        end
        self.action = false
    end

    local input = modit.input
    local anim

    if input.key_pressed("j") then return self:play_action("jump") end
    if input.key_pressed("c") then return self:play_action("chop") end
    if input.key_pressed("p") then return self:play_action("pickup") end
    if input.key_pressed("x") then return self:play_action("death") end

    if input.key_down("arrowdown") or input.key_down("s") then
        self.facing, anim = "front", "walk_front"
    elseif input.key_down("arrowup") or input.key_down("w") then
        self.facing, anim = "back", "walk_back"
    elseif input.key_down("arrowleft") or input.key_down("a") then
        self.facing, anim = "left", "walk_left"
    elseif input.key_down("arrowright") or input.key_down("d") then
        self.facing, anim = "right", "walk_right"
    else
        anim = "idle_" .. self.facing
    end

    self.character:play(anim)
    self.status:set_text("Animation: " .. anim)

    if anim:sub(1, 4) == "walk" then
        local move = MOVES[self.facing]
        self.pos_x = self.pos_x + move[1] * SPEED * dt
        self.pos_y = self.pos_y + move[2] * SPEED * dt
    end
    self.character:set_position(math.floor(self.pos_x), math.floor(self.pos_y))
    self:update_camera()
end

function scene:update_camera()
    local input = modit.input

    if input.key_pressed("e") and self.zoom_index < #ZOOM_LEVELS then
        self.zoom_index = self.zoom_index + 1
    elseif input.key_pressed("q") and self.zoom_index > 1 then
        self.zoom_index = self.zoom_index - 1
    end
    self.camera:set_zoom(ZOOM_LEVELS[self.zoom_index])
    self.camera:follow(math.floor(self.pos_x), math.floor(self.pos_y))

    local mx, my = input.get_mouse_position()
    local wx, wy = self.camera:screen_to_world(mx, my)

    local mouse_str = string.format("mouse world: %4d, %4d   zoom: %.1f", math.floor(wx), math.floor(wy), self.camera.zoom)
    self.mouse_text:set_text(mouse_str)
end

function scene:play_action(name)
    local anim = name .. "_" .. self.facing
    self.character:play(anim, true)
    self.status:set_text("Animation: " .. anim)
    self.action = true
end

--- @section Frame
--- Anything added here draws first, DrawList handles the order for everything else. 

function scene:frame()
end

--- @section Unload

function scene:unload()
    if self.font then
        self.font:unload()
    end
end

return scene