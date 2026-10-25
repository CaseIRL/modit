--- @module window
--- @file src/engine/render/window.lua
--- @description Handles window creation, runtime flags and window properties.
--- @class Window

--- @section Imports

local _bit = require("bit")
local raylib = require("src.engine.bindings.raylib")
local _ffi = raylib.ffi
local _rl = raylib.lib

local _fs = require("src.engine.core.filesystem")
local _Scenes = require("src.engine.core.scenes")

--- @section Constants

local FLAG_MAP = {
    vsync = _ffi.C.FLAG_VSYNC_HINT,
    fullscreen = _ffi.C.FLAG_FULLSCREEN_MODE,
    borderless = _ffi.C.FLAG_BORDERLESS_WINDOWED_MODE,
    resizable = _ffi.C.FLAG_WINDOW_RESIZABLE,
    undecorated = _ffi.C.FLAG_WINDOW_UNDECORATED,
    transparent = _ffi.C.FLAG_WINDOW_TRANSPARENT,
    hidden = _ffi.C.FLAG_WINDOW_HIDDEN,
    minimized = _ffi.C.FLAG_WINDOW_MINIMIZED,
    unfocused = _ffi.C.FLAG_WINDOW_UNFOCUSED,
    topmost = _ffi.C.FLAG_WINDOW_TOPMOST,
    always_run = _ffi.C.FLAG_WINDOW_ALWAYS_RUN,
    highdpi = _ffi.C.FLAG_WINDOW_HIGHDPI,
    mouse_passthrough = _ffi.C.FLAG_WINDOW_MOUSE_PASSTHROUGH,
    msaa_4x = _ffi.C.FLAG_MSAA_4X_HINT,
    interlaced = _ffi.C.FLAG_INTERLACED_HINT,
}

local INIT_ONLY = {
    transparent = true,
    highdpi = true,
    msaa_4x = true,
    interlaced = true,
}

local DEFAULTS = {
    -- Window
    width = 1280,
    height = 1080,
    title = "Modit Editor",
    icon = "",
    root = ".",
    exit_key = 0,
    audio = false,

    -- Flags
    vsync = true,
    fullscreen = false,
    borderless = false,
    resizable = true,
    undecorated = false,
    transparent = false,
    hidden = false,
    minimized = false,
    maximized = true,
    unfocused = false,
    topmost = false,
    always_run = false,
    highdpi = true,
    mouse_passthrough = false,
    msaa_4x = false,
    interlaced = false,

    -- Rendering
    draw_fps = true,
    target_fps = 144,
    clear_color = { 22, 22, 22, 255 },

    -- Scenes
    scene = "",
    scenes = {}
}

--- @section Helpers

--- Builds the config flag bitmask from the window's current settings.
--- @param self table Window instance
--- @return number
local function compute_bits(self)
    local bits = 0
    for key, flag in pairs(FLAG_MAP) do
        if self[key] == true then
            bits = _bit.bor(bits, flag)
        end
    end
    return bits
end

--- @section Initialisation

local Window = {}
Window.__index = Window

local window_flags = {}
for name, flag in pairs(FLAG_MAP) do
    window_flags[name] = flag
end
window_flags.maximized = _ffi.C.FLAG_WINDOW_MAXIMIZED

--- @section Lifecycle

--- Creates a new window object.
--- @param config table Window settings, flags and scenes
--- @return table Window instance
function Window.new(config)
    config = config or {}
    local self = setmetatable({}, Window)

    for k, v in pairs(DEFAULTS) do
        if config[k] ~= nil then
            self[k] = config[k]
        else
            self[k] = v
        end
    end

    self.flag_bits = compute_bits(self)
    self.running = false

    self.scenes = _Scenes.new(self)
    for name, scene in pairs(config.scenes or {}) do
        self.scenes:add(name, scene)
    end
    self.start_scene = config.scene

    log("debug", "Window configured", {
        width = self.width,
        height = self.height,
        title = self.title,
        target_fps = self.target_fps,
    })

    return self
end

--- Opens the window and runs the loop until it closes.
function Window:run()
    _rl.SetConfigFlags(self.flag_bits)
    _rl.InitWindow(self.width, self.height, self.title)

    if not _rl.IsWindowReady() then
        log("fatal", "Window failed to open")
    end
    log("info", "Window opened", { width = self.width, height = self.height })

    _rl.SetExitKey(self.exit_key)

    if self.maximized then
        _rl.MaximizeWindow()
    end

    _rl.SetTargetFPS(self.target_fps)
    self:set_icon()

    if self.audio then
        _rl.InitAudioDevice()
        log("debug", "Audio device started")
    end

    self.running = true
    if self.start_scene then
        self.scenes:switch(self.start_scene)
    end

    while self.running and not _rl.WindowShouldClose() do
        self.scenes:update(_rl.GetFrameTime())

        _rl.BeginDrawing()
        _rl.ClearBackground(self.clear_color)

        self.scenes:draw()
        if self.draw_fps then _rl.DrawFPS(10, 10) end

        _rl.EndDrawing()
    end

    self.scenes:unload()

    if self.audio then
        _rl.CloseAudioDevice()
    end
    _rl.CloseWindow()
    log("info", "Window closed")
end

--- Stops the loop after the current frame.
function Window:quit()
    self.running = false
end

--- @section Runtime Flags

--- Reads the live state of a flag straight from raylib.
--- @param name string Flag name (e.g. "vsync", "topmost")
--- @return boolean|nil State, or nil if the flag name is unknown
function Window:get_flag(name)
    local flag = window_flags[name]
    if not flag then return nil end

    if not _rl.IsWindowReady() then
        return self[name] == true
    end

    if name == "fullscreen" then
        return _rl.IsWindowFullscreen()
    end
    return _rl.IsWindowState(flag)
end

--- Sets a flag before the window opens it only updates the config
--- @param name string Flag name
--- @param enabled boolean
--- @return boolean ok
function Window:set_flag(name, enabled)
    enabled = enabled and true or false

    local flag = window_flags[name]
    if not flag then
        log("warn", "Unknown window flag", { flag = name })
        return false
    end

    if not _rl.IsWindowReady() then
        self[name] = enabled
        self.flag_bits = compute_bits(self)
        return true
    end

    if INIT_ONLY[name] then
        log("warn", "Window flag can only be set before the window opens", { flag = name })
        return false
    end

    if name == "fullscreen" then
        if enabled and _rl.IsWindowState(window_flags.borderless) then
            _rl.ToggleBorderlessWindowed()
            self.borderless = false
        end
        if enabled ~= _rl.IsWindowFullscreen() then
            _rl.ToggleFullscreen()
        end

    elseif name == "borderless" then
        if enabled and _rl.IsWindowFullscreen() then
            _rl.ToggleFullscreen()
            self.fullscreen = false
        end
        if enabled ~= _rl.IsWindowState(flag) then
            _rl.ToggleBorderlessWindowed()
        end

    elseif name == "maximized" then
        if enabled then
            if not _rl.IsWindowState(window_flags.resizable) then
                log("warn", "Cannot maximize a non-resizable window")
                return false
            end
            _rl.MaximizeWindow()
        else
            _rl.RestoreWindow()
        end

    elseif name == "minimized" then
        if enabled then
            _rl.MinimizeWindow()
        else
            _rl.RestoreWindow()
        end

    else
        if enabled then
            _rl.SetWindowState(flag)
        else
            _rl.ClearWindowState(flag)
        end
    end

    self[name] = enabled
    return true
end

--- Flips a flag.
--- @param name string Flag name
--- @return boolean ok
function Window:toggle_flag(name)
    local current = self:get_flag(name)
    if current == nil then
        log("warn", "Unknown window flag", { flag = name })
        return false
    end
    return self:set_flag(name, not current)
end

--- Sets several flags at once, e.g. window:set_flags({ vsync = false, topmost = true })
--- @param flags table name -> boolean
function Window:set_flags(flags)
    for name, enabled in pairs(flags) do
        self:set_flag(name, enabled)
    end
end

--- Returns a table of all flag states.
--- @return table name -> boolean
function Window:get_flags()
    local out = {}
    for name in pairs(window_flags) do
        out[name] = self:get_flag(name)
    end
    return out
end

--- @section Window Properties

--- Sets the window title.
--- @param title string
function Window:set_title(title)
    self.title = title
    _rl.SetWindowTitle(title)
end

--- Sets the window size.
--- @param width number
--- @param height number
function Window:set_size(width, height)
    self.width, self.height = width, height
    _rl.SetWindowSize(width, height)
end

--- Sets the window position on screen.
function Window:set_position(x, y)
    _rl.SetWindowPosition(x, y)
end

--- Sets the minimum size (needs the resizable flag).
function Window:set_min_size(width, height)
    _rl.SetWindowMinSize(width, height)
end

--- Sets the maximum size (needs the resizable flag).
function Window:set_max_size(width, height)
    _rl.SetWindowMaxSize(width, height)
end

--- Sets window opacity, clamped to 0..1.
--- @param opacity number
function Window:set_opacity(opacity)
    _rl.SetWindowOpacity(math.max(0, math.min(1, opacity)))
end

--- Moves the window to a monitor.
--- @param index number
function Window:set_monitor(index)
    _rl.SetWindowMonitor(index)
end

--- Requests input focus for the window.
function Window:focus()
    _rl.SetWindowFocused()
end

--- Current screen width and height.
--- @return number, number
function Window:get_size()
    return _rl.GetScreenWidth(), _rl.GetScreenHeight()
end

--- Current render width and height (accounts for HiDPI).
--- @return number, number
function Window:get_render_size()
    return _rl.GetRenderWidth(), _rl.GetRenderHeight()
end

--- Window position on the monitor.
--- @return number, number
function Window:get_position()
    local v = _rl.GetWindowPosition()
    return v.x, v.y
end

--- Window DPI scale factor.
--- @return number, number
function Window:get_dpi_scale()
    local v = _rl.GetWindowScaleDPI()
    return v.x, v.y
end

--- True if the window was resized last frame.
--- @return boolean
function Window:was_resized()
    return _rl.IsWindowResized()
end

--- @section Monitors

--- Info about a monitor (defaults to the one the window is on).
--- @param index number|nil
--- @return table
function Window:get_monitor(index)
    index = index or _rl.GetCurrentMonitor()
    local pos = _rl.GetMonitorPosition(index)
    return {
        index = index,
        name = _ffi.string(_rl.GetMonitorName(index)),
        x = pos.x,
        y = pos.y,
        width = _rl.GetMonitorWidth(index),
        height = _rl.GetMonitorHeight(index),
        refresh_rate = _rl.GetMonitorRefreshRate(index),
        physical_width = _rl.GetMonitorPhysicalWidth(index),
        physical_height = _rl.GetMonitorPhysicalHeight(index),
        count = _rl.GetMonitorCount(),
    }
end

--- @section Clipboard

--- Sets the clipboard text.
--- @param text string
function Window:set_clipboard(text)
    _rl.SetClipboardText(text)
end

--- Gets the clipboard text.
--- @return string|nil
function Window:get_clipboard()
    local str = _rl.GetClipboardText()
    if str == nil then return nil end
    return _ffi.string(str)
end

--- @section Icon

--- Finds the icon file and sets it.
function Window:set_icon()
    if not self.icon or self.icon == "" then return end

    local image
    local path = _fs.resolve(self.icon, { self.root })

    if path then
        image = _rl.LoadImage(path)
    else
        local bundle = rawget(_G, "MODIT_BUNDLE")
        if bundle then
            local key = (self.icon:gsub("\\", "/"):gsub("^%./", ""))

            if bundle.has(key) then
                local data = bundle.get(key)
                local ext = key:match("%.%w+$") or ".png"
                image = _rl.LoadImageFromMemory(ext, _ffi.cast("const unsigned char*", data), #data)
            end
        end
    end

    if not image then
        log("warn", "Window icon not found", { icon = self.icon })
        return
    end

    if _rl.IsImageValid(image) then
        _rl.SetWindowIcon(image)
    else
        log("warn", "Window icon is not a valid image", { icon = self.icon })
    end

    _rl.UnloadImage(image)
end

return Window