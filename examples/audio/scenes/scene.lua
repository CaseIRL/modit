--[[
    
    Modit Audio Example
    -------------------

    Basic audio example scene to show how music and sounds currently work.
    
    Things are subject to change so develop with this in mind.

    Example has been commented throughout to try make this as simple as possible.
    Hopefully even a complete beginner to lua can figure it out.
    Any notes on how to improve, let me know. 
]]

local scene = {}

--- Load whatever your game needs here
function scene:load()
    --[[
        You have two functions: 
            - load_music(path)
            - load_sound(path)

        File paths are relative to your project
    ]]
    self.music = modit.audio.load_music("assets/audio/horde_drums.ogg")
    self.sound = modit.audio.load_sound("assets/audio/headshot.ogg")

    self.label = modit.graphics.new_text({ text = "[ENTER] Play/Stop Music  |  [SPACE] Sound Effect", x = 10, y = 10 })

    -- Set a playback state to toggle music if required
    self.playing = false
end

-- Update things in the game here
function scene:update(dt)
    -- Toggle music when ENTER is pressed
    -- Not needed could be toggled by timer, ui, action, etc whatever this is just a simple example
    if modit.input.key_pressed("enter") then

        -- Toggles the playing state to opposite of itself false -> true | true -> false
        self.playing = not self.playing

        -- If `self.playing = true` then play music
        if self.playing then

            -- Plays music
            -- play(true) - plays music in a loop
            -- play() or play(false) - plays music once
            self.music:play(true)
        else
            -- When self.playing = false stop the music
            self.music:stop()
        end
    end

    -- Top music when press spacebar
    if modit.input.key_pressed("space") then
        self.sound:play()
    end
end

-- Unload things you loaded in `scene:load()` here
function scene:unload()
    -- Unload the music and sound
    if self.music then self.music:unload() end
    if self.sound then self.sound:unload() end
end

return scene