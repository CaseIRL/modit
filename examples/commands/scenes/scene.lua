--[[

    Modit Command Example
    ---------------------

    Commands can be registered by games and mods then called from the console.
    Press F8 to open the console and type a command.
    
    Commands send back an args table of the typed strings

    Simple enough nothing fancy.
]]

local scene = {}

--- Register commands to call in the console, you can register these anywhere it doesnt matter

modit.command.register({
    name = "hello",
    help = "Say a simple hello",
    handler = function()
        log("info", "hello, from command scene!")
    end
})

modit.command.register({
    name = "hello_name",
    help = "Say hello to someone",
    args = {
        { name = "name", help = "The person's name" }
    },
    handler = function(args)
        local name = args[1] or "stranger"
        log("info", "Hello " .. name .. " from command scene!")
    end
})

--- Load whatever your game needs here
function scene:load()
    -- Center text
    self.label = modit.graphics.new_text({ text = "Press F8 To Toggle Console", x = 495, y = 350 })
end

return scene