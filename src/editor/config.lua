return {
    --- @section Window
    width = 1280,
    height = 1080,
    title = "Modit Editor",
    icon = "src/assets/modit_icon_32x32.png",
    root = ".",

    vsync = true,
    maximized = true,
    highdpi = true,

    draw_fps = false,
    target_fps = 500,
    clear_color = { 22, 22, 22, 255 },

    --- @section scenes

    scene = "main",
    scenes = { 
        main = "src.editor.main"
    },

    --- @section Modules

    audio = false
}