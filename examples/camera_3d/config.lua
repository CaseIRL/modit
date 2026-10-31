--- @module config
--- @file config.lua
--- @description Demo configuration file for games.

return {

    --- @section Window

    width = 1280, -- Window width
    height = 720, -- Window height
    title = "Modit Example - 3D Camera", -- Window title
    --icon = "assets/images/modit_icon_32x32.png", -- Window icon path
    root = ".", -- Project root directory

    vsync = true, -- VSync enabled
    resizable = true, -- Resizable window

    draw_fps = false, -- Draw FPS counter
    target_fps = 500, -- Target frame rate limit
    clear_colour = { 0, 0, 0, 255 }, -- Background clear color (RGBA)

    --- @section Scenes

    scene = "main", -- Initial active scene name
    scenes = { 
        main = "scenes.scene" -- Registered scene paths
    },

    --- @section Modules

    modules = {
        input = true, -- Enables mouse, keyboard, gamepad and action bindings
        graphics = true, -- Enables 2D/3D graphics; shapes, models, lighting, shadows
    },
}