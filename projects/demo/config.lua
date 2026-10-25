--- @module config
--- @file config.lua
--- @description Demo configuration file for games.

return {

    --- @section Window

    width = 1280, -- Window width
    height = 1080, -- Window height
    title = "Modit Demo", -- Window title
    icon = "assets/modit_icon_32x32.png", -- Window icon path
    root = ".", -- Project root directory

    vsync = true, -- VSync enabled
    fullscreen = false, -- Fullscreen mode
    borderless = false, -- Borderless window
    resizable = true, -- Resizable window
    undecorated = false, -- No window decorations
    transparent = false, -- Transparent background
    hidden = false, -- Start hidden
    minimized = false, -- Start minimized
    maximized = true, -- Start maximized
    unfocused = false, -- Start without focus
    topmost = false, -- Always on top
    always_run = false, -- Run when unfocused
    highdpi = true, -- High-DPI support
    mouse_passthrough = false, -- Mouse clicks pass through
    msaa_4x = false, -- 4x MSAA anti-aliasing
    interlaced = false, -- Interlaced mode

    draw_fps = false, -- Draw FPS counter
    target_fps = 500, -- Target frame rate limit
    clear_color = { 22, 22, 22, 255 }, -- Background clear color (RGBA)

    --- @section Scenes

    scene = "main", -- Initial active scene name
    scenes = { 
        main = "scenes.demo" -- Registered scene paths
    },

    --- @section Modules

    audio = false -- Enables both Raylibs InitAudioDevice and modit audio module
}