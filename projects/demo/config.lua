--- @module config
--- @file config.lua
--- @description Demo configuration file for games.

return {

    --- @section Window

    width = 1280, -- Window width
    height = 720, -- Window height
    title = "Modit Demo", -- Window title
    icon = "assets/images/modit_icon_32x32.png", -- Window icon path
    root = ".", -- Project root directory

    vsync = true, -- VSync enabled
    fullscreen = false, -- Fullscreen mode
    borderless = false, -- Borderless window
    resizable = true, -- Resizable window
    undecorated = false, -- No window decorations
    transparent = false, -- Transparent background
    hidden = false, -- Start hidden
    minimized = false, -- Start minimized
    maximized = false, -- Start maximized
    unfocused = false, -- Start without focus
    topmost = false, -- Always on top
    always_run = false, -- Run when unfocused
    highdpi = false, -- High-DPI support
    mouse_passthrough = false, -- Mouse clicks pass through
    msaa_4x = false, -- 4x MSAA anti-aliasing
    interlaced = false, -- Interlaced mode

    draw_fps = true, -- Draw FPS counter
    target_fps = 500, -- Target frame rate limit
    clear_colour = { 0, 0, 0, 255 }, -- Background clear color (RGBA)

    --- @section Scenes

    scene = "main", -- Initial active scene name
    scenes = { 
        main = "scenes.demo" -- Registered scene paths
    },

    --- @section Mod support

    modding = {
        enabled = true, -- Enabled modding support for project; make sure to enable & use `modit.event` so mods can communicate with game
        blacklisted_modules = {
            -- List any SDK modules you want to restrict from mods here, e.g.:
            -- "audio"
        }
    },

    --- @section Modules

    modules = {
        audio = true, -- Enables both Raylibs InitAudioDevice and modit audio module 
        input = true, -- Enables mouse, keyboard, gamepad and action bindings
        graphics = true, -- Enables 2D/3D graphics; shapes, models, lighting, shadows
        event = true, -- Enabled event system so games can register events to communicate with itself or mods
    },
}