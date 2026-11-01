--[[
    
    Modit - Config Template
    -----------------------

    All options are commented, you don't need to use them all.
    Everything operates on a "opt-in" pattern not "opt-out".

    Important stuff:
    
    icon: is relative to your project, not to the api
    root: can be skipped unless you want to put files somewhere specific
    draw_fps: draws with default raylib settings
    target_fps: works like a FPS cap it's the target your game should reach; false = uncapped
    
    scene: **required** at least one scene is required along with the config
    modding: enable this to allow your game to be "modded", you still have to provide the events through `modit.event` for them
    modules: opt-in, anything you dont want to use just dont enable it and build your own version
]]

return {

    --- @section Window

    width = 1280, -- Window width
    height = 720, -- Window height
    title = "Modit Project", -- Window title
    icon = "", -- Window icon path relative to your project
    root = ".", -- Project root directory

    vsync = false, -- VSync enabled
    fullscreen = false, -- Fullscreen mode
    borderless = false, -- Borderless window
    resizable = false, -- Resizable window
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

    draw_fps = false, -- Draw FPS counter
    target_fps = 500, -- Target frame rate limit; false = uncapped
    clear_colour = { 0, 0, 0, 255 }, -- Background clear color (RGBA)

    --- @section Scenes

    scene = "main", -- Initial active scene name
    scenes = { 
        main = "scenes.main" -- Registered scene path; you can put your scenes anywhere it does not have to be in a "scenes/" folder
    },

    --- @section Mod support

    modding = {
        enabled = false, -- Enabled modding support for project; make sure to enable & use `modit.event` so mods can communicate with game
        blacklisted_modules = {
            -- List any API modules you want to restrict from mods here, e.g.:
            -- "audio"
        }
    },

    --- @section Console

    console = {
        enabled = false, -- Enables client side console opened with F8 by default; used for logs + commands
        font = "" -- Path to your font, falls back to default if not included
    },

    --- @section Network

    network = {
        console = true, -- Enable the headless server console
        tick_rate = 30, -- Server tick rate
        port = 7777 -- Server port
    },

    --- @section Modules

    modules = {
        audio = true, -- Enables both Raylibs InitAudioDevice and modit audio module 
        input = true, -- Enables mouse, keyboard, gamepad and action bindings
        graphics = true, -- Enables 2D/3D graphics; shapes, models, lighting, shadows
        event = true, -- Enabled event system so games can register events to communicate with itself or mods
        command = true, -- Enables command system to register/run console commands
        physics = true, -- Enables physics system make sure to create a physics world
        network = true -- Enables the network module, mostly basic just wraps Enet
    },
}