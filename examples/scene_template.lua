--[[
    
    Modit - Scene Template
    ----------------------

    All projects need a `config.lua` in the root and at least 1 Lua file.
    In modit this is your `scene`.

    scene = "main", -- Initial active scene
    scenes = { 
        main = "scenes.main" -- Registered scene paths
    },

    You can have as many scenes as you want and switch them with self.scene:switch()
]]

local scene = {}


--- Load whatever your game needs here
function scene:load()

end

--- Game updates go here; dt = deltatime
function scene:update(dt)

end

--- The window frame your main game stuff goes here
--- Anything in here is rendered first before the RenderList
function scene:frame()

end

--- Unload things you loaded in `scene:load()` here
function scene:unload()

end

return scene