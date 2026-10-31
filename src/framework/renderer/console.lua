--- @class Console
--- @file src/renderer/console.lua
--- @description In-game console: F8 toggle, shows the logs, runs commands.

--- @section Imports

local _raylib = require("src.framework.bindings.raylib")
local _ffi = _raylib.ffi
local _rl = _raylib.lib

local _text = require("src.framework.renderer.text")
local _shapes = require("src.framework.renderer.shapes")
local _camera = require("src.framework.renderer.camera")
local _command = require("src.framework.core.command")
local _log = require("src.framework.core.log")
local _fs = require("src.framework.core.filesystem")

--- @section Constants

local KEY = {
    toggle = 297, escape = 256, enter = 257, tab = 258, backspace = 259, delete = 261,
    right = 262, left = 263, down = 264, up = 265, page_up = 266, page_down = 267,
    home = 268, end_ = 269, ctrl = 341, v = 86,
}

local FONT_PATH = nil
if _G.console and _G.console.enabled and type(_G.console.font) == "string" and _G.console.font ~= "" then
    FONT_PATH = _G.console.font
end

local FONT_SIZE = 16
local FONT_SPACING = 0
local LINE_HEIGHT = 20
local INPUT_HEIGHT = 30
local PANEL_RATIO = 0.30
local MAX_HISTORY = 50
local MAX_LINES = 500
local WRAP_INDENT = 16

local COLOUR = {
    background = _text.resolve_colour({ 22, 22, 22, 235 }),
    input = _text.resolve_colour({ 17, 17, 17, 245 }),
    text = _text.resolve_colour({ 255, 255, 255, 255 }),
}

local LEVEL_COLOUR = {
    debug = _text.resolve_colour({ 190, 120, 220, 255 }),
    info = _text.resolve_colour({ 90, 200, 220, 255 }),
    success = _text.resolve_colour({ 120, 230, 150, 255 }),
    warn = _text.resolve_colour({ 255, 200, 90, 255 }),
    error = _text.resolve_colour({ 255, 110, 110, 255 }),
    fatal = _text.resolve_colour({ 255, 70, 70, 255 }),
}

--- @section Helpers

local position = _text.new_vector2(0, 0)

--- True on the frame a key goes down and on every auto-repeat after.
local function pressed(key)
    return _rl.IsKeyPressed(key) or _rl.IsKeyPressedRepeat(key)
end

--- Splits one line into rows that fit a pixel width, breaking at spaces.
--- @param line string
--- @param max_width number
--- @return table rows
local function wrap(line, max_width, measure)
    local rows, current = {}, ""

    for word in line:gmatch("%S+%s*") do
        local candidate = current .. word
        if current ~= "" and measure(candidate) > max_width then
            rows[#rows + 1] = current
            current = word
        else
            current = candidate
        end

        while #current > 1 and measure(current) > max_width do
            local cut = #current
            while cut > 1 and measure(current:sub(1, cut)) > max_width do
                cut = cut - 1
            end
            rows[#rows + 1] = current:sub(1, cut)
            current = current:sub(cut + 1)
        end
    end

    if current ~= "" or #rows == 0 then rows[#rows + 1] = current end
    return rows
end

--- @section Constructor

local Console = {}
Console.__index = Console

--- Creates the console and registers its own commands.
--- @return Console
function Console.new()
    local self = setmetatable({}, Console)
    self.enabled = true
    self.open = false
    self.input = ""
    self.cursor = 0
    self.history = {}
    self.history_index = 0
    self.scroll = 0
    self.lines = {}
    self.font = nil
    self.font_tried = false
    self.measure_fn = function(text) return self:measure(text) end

    for _, entry in ipairs(_log.log_history()) do
        self:push(entry.level, entry.line or ("[" .. entry.level:upper() .. "]: " .. entry.text))
    end

    local previous = _log.sink
    _log.sink = function(level, text, line)
        if previous then previous(level, text, line) end
        self:push(level, line)
    end

    -- Updated to use the new options-table command style
    _command.register_engine({
        name = "clear",
        help = "Clear the console",
        handler = function()
            self.lines = {}
            self.scroll = 0
        end
    })

    return self
end

--- @section Font

--- Loads the console font.
function Console:load_font()
    if self.font_tried then return end
    self.font_tried = true

    if not FONT_PATH then return end

    local root = _G.text_registry and _G.text_registry.root or "."
    local path = _fs.resolve(FONT_PATH, { root, "." })
    local font = path and _text.load_font_ex(path, FONT_SIZE, nil, 0)

    if font and type(font) ~= "string" and _text.is_font_valid(font) then
        _text.set_font_filter(font)
        self.font = font
    else
        self.font = nil
        log("warn", "Console font not found or invalid, using the default font", { path = FONT_PATH })
    end
end

--- Pixel width of a string in the console font.
--- @param text string
--- @return number
function Console:measure(text)
    if self.font and type(self.font) ~= "string" then
        return _text.measure_text_ex(self.font, text, FONT_SIZE, FONT_SPACING).x
    end
    return _text.measure_text(text, FONT_SIZE)
end

--- Draws a string in the console font.
--- @param text string
--- @param x number
--- @param y number
--- @param colour cdata
function Console:print(text, x, y, colour)
    if self.font and type(self.font) ~= "string" then
        position.x, position.y = x, y
        _text.draw_text_ex(self.font, text, position, FONT_SIZE, FONT_SPACING, colour)
    else
        _text.draw_text(text, x, y, FONT_SIZE, colour)
    end
end

--- Releases the font from VRAM.
function Console:free()
    if self.font and type(self.font) ~= "string" then
        _text.unload_font(self.font)
        self.font = nil
    end
end

--- @section Log

--- Adds one formatted log line to the console buffer.
--- @param level string
--- @param line string Full line, "[03:14:04] [INFO]: text"
function Console:push(level, line)
    local lines = self.lines
    lines[#lines + 1] = { level = level, line = line }
    if #lines > MAX_LINES then table.remove(lines, 1) end
end

--- @section State

--- Opens or closes the console.
--- @param open boolean
function Console:set_open(open)
    self.open = open
    _G.console_open = open

    while _rl.GetCharPressed() ~= 0 do end
    self.scroll = 0
end

--- Runs the current line and clears the input.
function Console:submit()
    local line = self.input
    self.input, self.cursor, self.history_index, self.scroll = "", 0, 0, 0
    if line:match("^%s*$") then return end

    if self.history[#self.history] ~= line then
        self.history[#self.history + 1] = line
        if #self.history > MAX_HISTORY then table.remove(self.history, 1) end
    end

    log("info", "> " .. line)
    _command.run(line)
end

--- Completes the command name being typed, or lists the matches.
function Console:complete()
    local prefix = self.input:match("^(%S+)$")
    if not prefix then return end
    prefix = prefix:lower()

    local matches = {}
    for _, command in ipairs(_command.list()) do
        if command.name:sub(1, #prefix) == prefix then
            matches[#matches + 1] = command.name
        end
    end

    if #matches == 1 then
        self.input = matches[1] .. " "
        self.cursor = #self.input
    elseif #matches > 1 then
        log("info", table.concat(matches, "  "))
    end
end

--- Puts text at the cursor.
--- @param text string
function Console:insert(text)
    self.input = self.input:sub(1, self.cursor) .. text .. self.input:sub(self.cursor + 1)
    self.cursor = self.cursor + #text
end

--- Moves through sent lines, direction 1 is older and -1 is newer.
--- @param direction number
function Console:recall(direction)
    local count = #self.history
    if count == 0 then return end

    self.history_index = math.max(0, math.min(count, self.history_index + direction))
    self.input = self.history_index == 0 and "" or self.history[count - self.history_index + 1]
    self.cursor = #self.input
end

--- @section Frame

--- Reads input.
function Console:update()
    if not self.enabled then return end

    if _rl.IsKeyPressed(KEY.toggle) then
        self:set_open(not self.open)
    end
    if not self.open then return end

    if _rl.IsKeyPressed(KEY.escape) then
        self:set_open(false)
        return
    end

    while true do
        local code = _rl.GetCharPressed()
        if code == 0 then break end
        if code >= 32 and code <= 126 then self:insert(string.char(code)) end
    end

    if _rl.IsKeyDown(KEY.ctrl) and _rl.IsKeyPressed(KEY.v) then
        local clip = _rl.GetClipboardText()
        if clip ~= nil then
            self:insert((_ffi.string(clip):gsub("[^\32-\126]", "")))
        end
    end

    if pressed(KEY.backspace) and self.cursor > 0 then
        self.input = self.input:sub(1, self.cursor - 1) .. self.input:sub(self.cursor + 1)
        self.cursor = self.cursor - 1
    end
    if pressed(KEY.delete) then
        self.input = self.input:sub(1, self.cursor) .. self.input:sub(self.cursor + 2)
    end
    if pressed(KEY.left) then self.cursor = math.max(0, self.cursor - 1) end
    if pressed(KEY.right) then self.cursor = math.min(#self.input, self.cursor + 1) end
    if _rl.IsKeyPressed(KEY.home) then self.cursor = 0 end
    if _rl.IsKeyPressed(KEY.end_) then self.cursor = #self.input end

    if pressed(KEY.up) then self:recall(1) end
    if pressed(KEY.down) then self:recall(-1) end
    if _rl.IsKeyPressed(KEY.tab) then self:complete() end
    if _rl.IsKeyPressed(KEY.enter) then self:submit() end

    if pressed(KEY.page_up) then self.scroll = self.scroll + 5 end
    if pressed(KEY.page_down) then self.scroll = self.scroll - 5 end
    self.scroll = self.scroll + math.floor(_rl.GetMouseWheelMove() * 3)
end

--- Draws the console over the scene.
function Console:draw()
    if not self.open then return end
    self:load_font()

    local width, height = _camera.get_screen_size()
    local panel = math.floor(height * PANEL_RATIO)
    local total_rows = math.floor((panel - 10) / LINE_HEIGHT)
    local max_rows = total_rows - 1

    _shapes.draw_rectangle(0, 0, width, panel, COLOUR.background)
    _shapes.draw_rectangle(0, panel, width, INPUT_HEIGHT, COLOUR.input)

    self:print("Type 'help' for available commands", 10, panel - 6 - LINE_HEIGHT, COLOUR.text)

    local max_width = width - 20 - WRAP_INDENT
    local skipped, drawn = 0, 0

    for i = #self.lines, 1, -1 do
        local entry = self.lines[i]
        if entry.width ~= max_width then
            entry.rows, entry.width = wrap(entry.line, max_width, self.measure_fn), max_width
        end

        local colour = LEVEL_COLOUR[entry.level] or LEVEL_COLOUR.info
        for r = #entry.rows, 1, -1 do
            if skipped < self.scroll then
                skipped = skipped + 1
            else
                local x = r == 1 and 10 or 10 + WRAP_INDENT
                self:print(entry.rows[r], x, panel - 6 - (drawn + 2) * LINE_HEIGHT, colour)
                drawn = drawn + 1
                if drawn >= max_rows then
                    break
                end
            end
        end
        if drawn >= max_rows then
            break
        end
    end

    if drawn < max_rows and self.scroll > 0 then
        self.scroll = math.max(0, self.scroll - (max_rows - drawn))
    end

    local prompt = "> " .. self.input
    self:print(prompt, 10, panel + 7, COLOUR.text)

    if math.floor(os.clock() * 2) % 2 == 0 then
        local x = 10 + self:measure("> " .. self.input:sub(1, self.cursor))
        _shapes.draw_rectangle(x, panel + 7, 2, FONT_SIZE, COLOUR.text)
    end
end

return Console