--[[
    
    Modit Image & Sprite Example
    ----------------------------

    Basic image and sprite example scene showing images, labels, 
    and character sprite animations assigned directly to self.
    
    Things are subject to change so develop with this in mind.

    Example has been commented throughout to try make this as simple as possible.
    Hopefully even a complete beginner to lua can figure it out.
    Any notes on how to improve, let me know. 
]]

local scene = {}

function scene:load()
    -- Initialize 2D camera so the world moves sprite
    self.camera = modit.graphics.new_camera({ mode = "2d" })
    modit.graphics.set_camera(self.camera)

    -- Loading image type
    self.img_point = modit.graphics.new_image({ path = "assets/images/mod_logo.png", x = 60, y = 120, scale = 0.64 })
    self.txt_point = modit.graphics.new_text({ text = "point", x = 60, y = 260, colour = { 160, 170, 185, 255 } })
    self.img_bilinear = modit.graphics.new_image({ path = "assets/images/mod_logo.png", x = 220, y = 120, scale = 0.64, filter = "bilinear" })
    self.txt_bilinear = modit.graphics.new_text({ text = "bilinear", x = 220, y = 260, colour = { 160, 170, 185, 255 } })
    self.img_tint = modit.graphics.new_image({ path = "assets/images/mod_logo.png", x = 380, y = 120, scale = 0.64, tint = { 255, 110, 110, 255 }, flip_x = true })
    self.txt_tint = modit.graphics.new_text({ text = "tint + flip", x = 380, y = 260, colour = { 160, 170, 185, 255 } })
    self.img_size = modit.graphics.new_image({ path = "assets/images/mod_logo.png", x = 540, y = 120, width = 128, height = 128 })
    self.txt_size = modit.graphics.new_text({ text = "width/height", x = 540, y = 260, colour = { 160, 170, 185, 255 } })
    self.spinner = modit.graphics.new_image({ path = "assets/images/mod_logo.png", x = 880, y = 184, scale = 0.64, origin = { 100, 100 } })
    self.txt_spinner = modit.graphics.new_text({ text = "origin + rotation", x = 810, y = 260, colour = { 160, 170, 185, 255 } })
    self.img_layer1 = modit.graphics.new_image({ path = "assets/images/mod_logo.png", x = 1010, y = 120, scale = 0.64, layer = 1, tint = { 255, 200, 90, 255 } })
    self.img_layer2 = modit.graphics.new_image({ path = "assets/images/mod_logo.png", x = 1050, y = 150, scale = 0.64, layer = 2, tint = { 110, 160, 255, 255 } })
    self.txt_layers = modit.graphics.new_text({ text = "layer 2 over 1", x = 1010, y = 260, colour = { 160, 170, 185, 255 } })

    -- Loading a sprite
    self.character = modit.graphics.new_image({
        path = "assets/images/rpg_base_character_16.png",
        x = 0,
        y = 0,
        scale = 8,
        origin = { 8, 8 },
        space = "world",
        frame_width = 16, 
        frame_height = 16,
        animations = {
            idle_front = { y = 0, frames = 2, fps = 4, loop = true },
            idle_back  = { y = 1, frames = 2, fps = 4, loop = true },
            idle_right = { y = 2, frames = 2, fps = 4, loop = true },
            idle_left  = { y = 3, frames = 2, fps = 4, loop = true },
            walk_front = { y = 4, frames = 4, fps = 6, loop = true },
            walk_back  = { y = 5, frames = 4, fps = 6, loop = true },
            walk_right = { y = 6, frames = 4, fps = 6, loop = true },
            walk_left  = { y = 7, frames = 4, fps = 6, loop = true },
        },
        animation = "idle_front",
    })

    -- Set the state
    self.pos_x, self.pos_y = 0, 0
    self.speed = 240
    self.facing = "front"

    -- Help text, you dont need this.
    self.txt_help = modit.graphics.new_text({ text = "WASD / arrows walk", x = 20, y = 640, colour = { 160, 170, 185, 255 } })
    self.status = modit.graphics.new_text({ text = "Animation: idle_front", x = 20, y = 680, colour = { 160, 170, 185, 255 } })
end

function scene:update(dt)
    -- Continuously rotate the spinner image
    self.spinner:set_rotation(os.clock() * 90)

    local input = modit.input
    local anim

    -- Check direction keys to move sprite
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

    -- Play animation and update status text
    self.character:play(anim)
    self.status:set_text("Animation: " .. anim)

    -- Update sprite position if walking
    if anim:sub(1, 4) == "walk" then
        local MOVES = { 
            front = { 0, 1 }, back = { 0, -1 }, 
            left = { -1, 0 }, right = { 1, 0 } 
        }
        local move = MOVES[self.facing]
        self.pos_x = self.pos_x + move[1] * self.speed * dt
        self.pos_y = self.pos_y + move[2] * self.speed * dt
    end

    local px, py = math.floor(self.pos_x), math.floor(self.pos_y)
    self.character:set_position(px, py)
    self.camera:follow(px, py)
end

-- Unload things from scene:load() here
function scene:unload()
    -- Unload all assets loaded on self
    for _, obj in pairs({
        self.img_point, self.txt_point, self.img_bilinear, self.txt_bilinear,
        self.img_tint, self.txt_tint, self.img_size, self.txt_size,
        self.spinner, self.txt_spinner, self.img_layer1, self.img_layer2,
        self.txt_layers, self.character, self.txt_help, self.status
    }) do
        if obj and obj.unload then obj:unload() end
    end
end

return scene