--- @module server_console
--- @file src/framework/network/server_console.lua
--- @description Native Windows server console window backend.

--- @section Imports

local _ffi = require("ffi")

--- @section Constants

local WM_DESTROY = 0x0002
local WM_CLOSE = 0x0010
local WM_KEYDOWN = 0x0100
local WM_CTLCOLOREDIT = 0x0133
local WM_CTLCOLORSTATIC = 0x0138
local WM_SIZE = 0x0005
local WM_QUIT = 0x0012
local VK_RETURN = 0x0D
local VK_UP = 0x26
local VK_DOWN = 0x28
local EM_SETSEL = 0x00B1
local EM_REPLACESEL = 0x00C2
local EM_SCROLLCARET = 0x00B7
local EM_SETFONT = 0x0030
local EM_SETREADONLY = 0x00CF
local EM_GETSEL = 0x00B0
local EM_SETRECT = 0x00B3
local EM_SETEVENTMASK = 0x0445
local EM_SETBKGNDCOLOR = 0x0443
local EM_SETCHARFORMAT = 0x0444
local EM_EXLIMITTEXT = 0x0435
local SCF_SELECTION = 0x0001
local CFM_BOLD = 0x00000001
local CFM_COLOR = 0x40000000
local CFM_FACE = 0x20000000
local CFM_SIZE = 0x80000000
local CFE_BOLD = 0x00000001
local ES_MULTILINE = 0x0004
local ES_AUTOVSCROLL = 0x0040
local ES_AUTOHSCROLL = 0x0080
local ES_READONLY = 0x0800
local WS_CHILD = 0x40000000
local WS_VISIBLE = 0x10000000
local WS_VSCROLL = 0x00200000
local WS_TABSTOP = 0x00010000
local WS_OVERLAPPEDWINDOW = 0x00CF0000
local SW_SHOW = 5
local PM_REMOVE = 0x0001
local OPAQUE = 2
local DEFAULT_CHARSET = 1
local FW_NORMAL = 400
local DWMWA_USE_IMMERSIVE_DARK_MODE = 20
local CP_UTF8 = 65001
local IMAGE_ICON = 1
local LR_LOADFROMFILE = 0x0010
local SM_CXICON = 11
local SM_CXSMICON = 49

local DEFAULT_WINDOW_TITLE = "Modit Server"

--- @section FFI

_ffi.cdef[[
typedef void* HWND;
typedef void* HINSTANCE;
typedef void* HMENU;
typedef void* HBRUSH;
typedef void* HICON;
typedef void* HCURSOR;
typedef void* HFONT;
typedef void* HGDIOBJ;
typedef unsigned long DWORD;
typedef unsigned int UINT;
typedef unsigned long long WPARAM;
typedef long long LPARAM;
typedef long long LRESULT;
typedef int BOOL;
typedef const char* LPCSTR;

typedef LRESULT (__stdcall *WNDPROC)(HWND, UINT, WPARAM, LPARAM);

typedef struct {
    UINT cbSize;
    UINT style;
    WNDPROC lpfnWndProc;
    int cbClsExtra;
    int cbWndExtra;
    HINSTANCE hInstance;
    HICON hIcon;
    HCURSOR hCursor;
    HBRUSH hbrBackground;
    LPCSTR lpszMenuName;
    LPCSTR lpszClassName;
    HICON hIconSm;
} WNDCLASSEXA;

typedef struct {
    int left;
    int top;
    int right;
    int bottom;
} RECT;

typedef struct {
    HWND hwnd;
    UINT message;
    WPARAM wParam;
    LPARAM lParam;
    DWORD time;
    long pt_x;
    long pt_y;
} MSG;

typedef struct {
    UINT cbSize;
    UINT dwMask;
    UINT dwEffects;
    int yHeight;
    int yOffset;
    UINT crTextColor;
    unsigned char bCharSet;
    unsigned char bPitchAndFamily;
    wchar_t szFaceName[32];
    unsigned short wWeight;
    short sSpacing;
    UINT crBackColor;
    UINT lcid;
    UINT dwReserved;
    short sStyle;
    unsigned short wKerning;
    unsigned char bUnderlineType;
    unsigned char bAnimation;
    unsigned char bRevAuthor;
    unsigned char bUnderlineColor;
} CHARFORMAT2W;

HINSTANCE GetModuleHandleA(LPCSTR lpModuleName);
DWORD GetLastError(void);
int MultiByteToWideChar(UINT CodePage, UINT dwFlags, LPCSTR lpMultiByteStr, int cbMultiByte, wchar_t* lpWideCharStr, int cchWideChar);

unsigned short RegisterClassExA(const WNDCLASSEXA* lpwcx);
BOOL UnregisterClassA(LPCSTR lpClassName, HINSTANCE hInstance);
HWND CreateWindowExA(DWORD dwExStyle, LPCSTR lpClassName, LPCSTR lpWindowName, DWORD dwStyle, int X, int Y, int nWidth, int nHeight, HWND hWndParent, HMENU hMenu, HINSTANCE hInstance, void* lpParam);
HWND CreateWindowExW(DWORD dwExStyle, const wchar_t* lpClassName, const wchar_t* lpWindowName, DWORD dwStyle, int X, int Y, int nWidth, int nHeight, HWND hWndParent, HMENU hMenu, HINSTANCE hInstance, void* lpParam);
LRESULT DefWindowProcA(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam);
BOOL ShowWindow(HWND hWnd, int nCmdShow);
BOOL UpdateWindow(HWND hWnd);
BOOL TranslateMessage(const MSG* lpMsg);
LRESULT DispatchMessageA(const MSG* lpMsg);
BOOL PeekMessageA(MSG* lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg);
LRESULT SendMessageA(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam);
LRESULT SendMessageW(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam);
BOOL SetWindowTextA(HWND hWnd, LPCSTR lpString);
int GetWindowTextA(HWND hWnd, char* lpString, int nMaxCount);
int GetWindowTextLengthA(HWND hWnd);
BOOL DestroyWindow(HWND hWnd);
void PostQuitMessage(int nExitCode);
BOOL GetClientRect(HWND hWnd, RECT* lpRect);
BOOL MoveWindow(HWND hWnd, int X, int Y, int nWidth, int nHeight, BOOL bRepaint);
HWND SetFocus(HWND hWnd);
void* LoadImageA(HINSTANCE hInst, LPCSTR name, UINT type, int cx, int cy, UINT fuLoad);
BOOL DestroyIcon(HICON hIcon);
int GetSystemMetrics(int nIndex);

HBRUSH CreateSolidBrush(unsigned long color);
BOOL DeleteObject(HGDIOBJ hObject);
int SetBkMode(void* hdc, int mode);
unsigned long SetTextColor(void* hdc, unsigned long color);
unsigned long SetBkColor(void* hdc, unsigned long color);
HFONT CreateFontA(int nHeight, int nWidth, int nEscapement, int nOrientation, int fnWeight, unsigned int fdwItalic, unsigned int fdwUnderline, unsigned int fdwStrikeOut, unsigned int fdwCharSet, unsigned int fdwOutputPrecision, unsigned int fdwClipPrecision, unsigned int fdwQuality, unsigned int fdwPitchAndFamily, LPCSTR lpszFace);

int SetWindowTheme(HWND hwnd, const wchar_t* pszSubAppName, const wchar_t* pszSubIdList);
long DwmSetWindowAttribute(HWND hwnd, DWORD dwAttribute, const void* pvAttribute, DWORD cbAttribute);
]]

--- @section Initialisation

local _user32 = _ffi.load("user32")
local _kernel32 = _ffi.load("kernel32")
local _gdi32 = _ffi.load("gdi32")
local _uxtheme = _ffi.load("uxtheme")
local _dwmapi = _ffi.load("dwmapi")
local _msftedit = _ffi.load("msftedit")

local m = {
    window = nil,
    output = nil,
    input = nil,
    command = nil,
    closed = false,
    window_proc = nil,
    background_brush = nil,
    input_brush = nil,
    font = nil,
    icon_big = nil,
    icon_small = nil,
    rich = true,
    version = nil,
    warned = false,
    keepalive = nil,
}

m.msftedit = _msftedit

--- @section Constants & State

local instance = _kernel32.GetModuleHandleA(nil)
local class_name = "ModitServerConsole"

local DEFAULT_ICON_PATH = "src/assets/branding/modit_icon.ico"
local FONT_FACE = "Consolas"
local FONT_HEIGHT_TWIPS = 210

local function rgb(r, g, b)
    return r + g * 256 + b * 65536
end

local BACKGROUND = 0x181818
local INPUT_BACKGROUND = 0x202020
local TEXT = 0xE0E0E0
local INPUT_TEXT = 0xFFFFFF
local INPUT_HEIGHT = 36
local PADDING_X = 16
local PADDING_Y = 8

local LEVEL_COLOURS = {
    debug = { colour = rgb(190, 110, 225) },
    info = { colour = rgb(60, 190, 215) },
    success = { colour = rgb(70, 205, 100) },
    warn = { colour = rgb(235, 200, 60) },
    error = { colour = rgb(240, 85, 85) },
    fatal = { colour = rgb(255, 60, 60), bold = true },
    command = { colour = rgb(255, 255, 255) },

    banner1 = { colour = rgb(60, 190, 215), bold = true },
    banner2 = { colour = rgb(80, 170, 230), bold = true },
    banner3 = { colour = rgb(110, 150, 235), bold = true },
    banner4 = { colour = rgb(150, 125, 230), bold = true },
    banner5 = { colour = rgb(190, 110, 225), bold = true },
    title = { colour = rgb(255, 255, 255), bold = true },
    dim = { colour = rgb(130, 130, 130) },
}


local DEFAULT_STYLE = { colour = TEXT }

local ANSI_COLOURS = {
    [31] = rgb(240, 85, 85),
    [32] = rgb(70, 205, 100),
    [33] = rgb(235, 200, 60),
    [34] = rgb(90, 140, 240),
    [35] = rgb(190, 110, 225),
    [36] = rgb(60, 190, 215),
    [37] = TEXT,
}

local char_format = _ffi.new("CHARFORMAT2W[1]")
local padding_client = _ffi.new("RECT[1]")
local padding_rect = _ffi.new("RECT[1]")
local msg = _ffi.new("MSG")
local history, history_index = {}, 0

--- @section Helpers

--- Converts a UTF-8 Lua string into a null-terminated wchar_t buffer
--- @param s string UTF-8 string to convert
--- @return cdata buffer Null-terminated wchar_t buffer
--- @return number length Length in UTF-16 code units, excluding the terminator
local function wide(s)
    local length = _kernel32.MultiByteToWideChar(CP_UTF8, 0, s, #s, nil, 0)
    local buf = _ffi.new("wchar_t[?]", length + 1)
    if length > 0 then
        _kernel32.MultiByteToWideChar(CP_UTF8, 0, s, #s, buf, length)
    end
    return buf, length
end

--- Converts a pointer or array into an LPARAM value for SendMessage
--- @param ptr cdata Pointer or array to convert
--- @return cdata lparam Pointer value as an LPARAM
local function pointer_to_lparam(ptr)
    return _ffi.cast("LPARAM", _ffi.cast("const void*", ptr))
end

--- Applies colour, weight and the console font to the output selection or insertion point
--- @param style ConsoleStyle Style to apply
--- @return cdata result Non-zero if Windows accepted the format
local function apply_format(style)
    local cf = char_format[0]
    _ffi.fill(cf, _ffi.sizeof("CHARFORMAT2W"))

    cf.cbSize = _ffi.sizeof("CHARFORMAT2W")
    cf.dwMask = CFM_COLOR + CFM_BOLD + CFM_FACE + CFM_SIZE
    cf.dwEffects = style.bold and CFE_BOLD or 0
    cf.yHeight = FONT_HEIGHT_TWIPS
    cf.crTextColor = style.colour
    cf.bCharSet = DEFAULT_CHARSET

    for i = 1, #FONT_FACE do
        cf.szFaceName[i - 1] = FONT_FACE:byte(i)
    end

    return _user32.SendMessageW(m.output, EM_SETCHARFORMAT, SCF_SELECTION, pointer_to_lparam(char_format))
end

--- Insets the output text area so lines do not touch the window edges
local function apply_padding()
    if not m.output or not m.rich then return end

    _user32.GetClientRect(m.output, padding_client)
    local client = padding_client[0]
    local rect = padding_rect[0]

    rect.left = PADDING_X
    rect.top = PADDING_Y
    rect.right = math.max(PADDING_X + 1, client.right - PADDING_X)
    rect.bottom = math.max(PADDING_Y + 1, client.bottom - PADDING_Y)

    _user32.SendMessageW(m.output, EM_SETRECT, 0, pointer_to_lparam(padding_rect))
end

--- Loads an icon from an .ico file at a given pixel size
--- @param path string Path to the .ico file
--- @param size number Icon width and height in pixels
--- @return cdata|nil icon Icon handle, or nil if the file could not be loaded
local function load_icon(path, size)
    local icon = _user32.LoadImageA(nil, path, IMAGE_ICON, size, size, LR_LOADFROMFILE)
    if icon == nil then return nil end
    return icon
end

--- Window procedure for the console window
--- @param hwnd cdata Window handle
--- @param message number Window message identifier
--- @param wparam cdata Message WPARAM
--- @param lparam cdata Message LPARAM
--- @return number|cdata result Message result
local function window_proc(hwnd, message, wparam, lparam)
    if message == WM_CLOSE then
        print("[console] WM_CLOSE received\n" .. debug.traceback())
        m.closed = true
        _user32.DestroyWindow(hwnd)
        return 0
    end

    if message == WM_DESTROY then
        m.closed = true
        _user32.PostQuitMessage(0)
        return 0
    end

    if message == WM_SIZE then
        local l = tonumber(lparam)
        local width = l % 65536
        local height = math.floor(l / 65536) % 65536

        if m.output then
            _user32.MoveWindow(m.output, 0, 0, width, math.max(0, height - INPUT_HEIGHT), 1)
            apply_padding()
        end

        if m.input then
            _user32.MoveWindow(m.input, 0, math.max(0, height - INPUT_HEIGHT), width, INPUT_HEIGHT, 1)
        end

        return 0
    end

    if message == WM_CTLCOLOREDIT or message == WM_CTLCOLORSTATIC then
        local hdc = _ffi.cast("void*", wparam)

        _gdi32.SetBkMode(hdc, OPAQUE)

        if _ffi.cast("HWND", lparam) == m.input then
            _gdi32.SetTextColor(hdc, INPUT_TEXT)
            _gdi32.SetBkColor(hdc, INPUT_BACKGROUND)
            return _ffi.cast("LRESULT", m.input_brush)
        end

        _gdi32.SetTextColor(hdc, TEXT)
        _gdi32.SetBkColor(hdc, BACKGROUND)
        return _ffi.cast("LRESULT", m.background_brush)
    end

    return _user32.DefWindowProcA(hwnd, message, wparam, lparam)
end

--- Replaces the input text and moves the caret to the end
--- @param text string Text to place in the input box
local function set_input(text)
    _user32.SetWindowTextA(m.input, text)
    local length = _user32.GetWindowTextLengthA(m.input)
    _user32.SendMessageA(m.input, EM_SETSEL, length, length)
end

--- Reads the input box, clears it, stores the command, records history and echoes it to the output
local function submit()
    local buffer = _ffi.new("char[4096]")
    local length = _user32.GetWindowTextA(m.input, buffer, 4096)
    _user32.SetWindowTextA(m.input, "")
    history_index = 0

    if length > 0 then
        local line = _ffi.string(buffer, length)
        history[#history + 1] = line
        m.command = line
        m.print("> " .. line, "command")
    end
end

--- Splits text containing ANSI SGR escape sequences into coloured segments
--- @param text string Text that may contain ANSI escape sequences
--- @param base ConsoleStyle Style used at the start and after a reset code
--- @return ConsoleSegment[] segments Ordered list of coloured text segments
local function parse_ansi(text, base)
    local segments = {}
    local colour, bold = base.colour, base.bold
    local pos = 1

    while true do
        local s, e, codes = text:find("\27%[([%d;]*)m", pos)
        if not s then break end

        if s > pos then
            segments[#segments + 1] = { text = text:sub(pos, s - 1), colour = colour, bold = bold }
        end

        if codes == "" then codes = "0" end
        for code in codes:gmatch("%d+") do
            local n = tonumber(code)
            if n == 0 then
                colour, bold = base.colour, base.bold
            elseif n == 1 then
                bold = true
            elseif n == 22 then
                bold = false
            elseif n == 39 then
                colour = base.colour
            elseif ANSI_COLOURS[n] then
                colour = ANSI_COLOURS[n]
            elseif n >= 90 and n <= 97 then
                colour = ANSI_COLOURS[n - 60]
            end
        end

        pos = e + 1
    end

    if pos <= #text then
        segments[#segments + 1] = { text = text:sub(pos), colour = colour, bold = bold }
    end

    return segments
end

--- Finds a log level from a `[LEVEL]` tag near the start of a line
--- @param text string Line of text to inspect
--- @return string|nil level Lowercase level name, or nil if no tag is found
local function detect_level(text)
    local head = text:sub(1, 80):lower()
    for _, level in ipairs({ "success", "debug", "info", "warn", "error", "fatal" }) do
        if head:find("[" .. level .. "]", 1, true) then
            return level
        end
    end
    return nil
end

--- @section Lifecycle

--- Creates and shows the console window
--- @param icon_path string|nil Path to a .ico file (defaults to src/assets/branding/modit_icon.ico)
--- @param version string|nil Engine version shown in the startup banner
--- @param window_title string|nil Title of the console window (defaults to DEFAULT_WINDOW_TITLE)
function m.init(icon_path, window_title, version)
    m.version = version or m.version or "dev"
    m.closed = false
    m.command = nil
    m.window_proc = _ffi.cast("WNDPROC", window_proc)
    m.background_brush = _gdi32.CreateSolidBrush(BACKGROUND)
    m.input_brush = _gdi32.CreateSolidBrush(INPUT_BACKGROUND)
    m.font = _gdi32.CreateFontA(-14, 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, 0, 0, 0, 0, FONT_FACE)

    icon_path = icon_path or DEFAULT_ICON_PATH
    m.icon_big = load_icon(icon_path, _user32.GetSystemMetrics(SM_CXICON))
    m.icon_small = load_icon(icon_path, _user32.GetSystemMetrics(SM_CXSMICON))

    local class = _ffi.new("WNDCLASSEXA")
    class.cbSize = _ffi.sizeof(class)
    class.lpfnWndProc = m.window_proc
    class.hInstance = instance
    class.hbrBackground = m.background_brush
    class.lpszClassName = class_name
    if m.icon_big then class.hIcon = m.icon_big end
    if m.icon_small then class.hIconSm = m.icon_small end

    _user32.RegisterClassExA(class)

    window_title = window_title or DEFAULT_WINDOW_TITLE
    m.window = _user32.CreateWindowExA(0, class_name, window_title, WS_OVERLAPPEDWINDOW, 100, 100, 900, 600, nil, nil, instance, nil)

    local output_style = WS_CHILD + WS_VISIBLE + WS_VSCROLL + ES_MULTILINE + ES_AUTOVSCROLL

    m.output = _user32.CreateWindowExW(0, wide("RICHEDIT50W"), wide(""), output_style, 0, 0, 900, 564, m.window, nil, instance, nil)
    local rich_error = nil

    if m.output == nil then
        rich_error = "RICHEDIT50W failed (error " .. tostring(_kernel32.GetLastError()) .. ")"

        local loaded, lib = pcall(_ffi.load, "riched20")
        if loaded then
            m.riched20 = lib
            m.output = _user32.CreateWindowExW(0, wide("RichEdit20W"), wide(""), output_style, 0, 0, 900, 564, m.window, nil, instance, nil)
        end
    end

    if m.output == nil then
        m.rich = false
        m.output = _user32.CreateWindowExA(0, "EDIT", "", WS_CHILD + WS_VISIBLE + WS_VSCROLL + ES_MULTILINE + ES_AUTOVSCROLL + ES_READONLY, 0, 0, 900, 564, m.window, nil, instance, nil)
        _user32.SendMessageA(m.output, EM_SETFONT, _ffi.cast("WPARAM", m.font), 1)
    else
        m.rich = true
    end

    m.input = _user32.CreateWindowExA(0, "EDIT", "", WS_CHILD + WS_VISIBLE + WS_TABSTOP + ES_AUTOHSCROLL, 0, 564, 900, INPUT_HEIGHT, m.window, nil, instance, nil)

    if m.rich then
        _user32.SendMessageW(m.output, EM_SETEVENTMASK, 0, 0)
        _user32.SendMessageW(m.output, EM_EXLIMITTEXT, 0, 100000000)
        _user32.SendMessageW(m.output, EM_SETBKGNDCOLOR, 0, BACKGROUND)
        _user32.SendMessageW(m.output, EM_SETREADONLY, 1, 0)
        apply_padding()
    end

    _user32.SendMessageA(m.input, EM_SETFONT, _ffi.cast("WPARAM", m.font), 1)

    _uxtheme.SetWindowTheme(m.output, wide("DarkMode_Explorer"), nil)
    _uxtheme.SetWindowTheme(m.input, wide("DarkMode_Explorer"), nil)
    local dark = _ffi.new("int[1]", 1)
    _dwmapi.DwmSetWindowAttribute(m.window, DWMWA_USE_IMMERSIVE_DARK_MODE, dark, 4)

    _user32.ShowWindow(m.window, SW_SHOW)
    _user32.UpdateWindow(m.window)
    _user32.SetFocus(m.input)

    m.banner()

    if not m.rich then
        m.print("[console] Colours unavailable, using plain output. " .. (rich_error or ""))
    end
end

--- Reports whether the console window has been closed
--- @return boolean closed True if the window was closed
function m.is_closed()
    return m.closed
end

--- Destroys the console window and releases all native resources
function m.close()
    if m.window then
        _user32.DestroyWindow(m.window)
        m.window = nil
    end

    m.output = nil
    m.input = nil

    _user32.UnregisterClassA(class_name, instance)

    if m.icon_big then
        _user32.DestroyIcon(m.icon_big)
        m.icon_big = nil
    end

    if m.icon_small then
        _user32.DestroyIcon(m.icon_small)
        m.icon_small = nil
    end

    if m.font then
        _gdi32.DeleteObject(m.font)
        m.font = nil
    end

    if m.window_proc then
        m.window_proc:free()
        m.window_proc = nil
    end

    if m.background_brush then
        _gdi32.DeleteObject(m.background_brush)
        m.background_brush = nil
    end

    if m.input_brush then
        _gdi32.DeleteObject(m.input_brush)
        m.input_brush = nil
    end
end

--- @section Input

--- Pumps window messages and returns the next submitted command
--- @return string|nil command Submitted command line, or nil if none was entered
function m.poll()
    while _user32.PeekMessageA(msg, nil, 0, 0, PM_REMOVE) ~= 0 do
        if msg.message == WM_QUIT then
            m.closed = true
        elseif msg.message == WM_KEYDOWN and msg.hwnd == m.input and msg.wParam == VK_RETURN then
            submit()
        elseif msg.message == WM_KEYDOWN and msg.hwnd == m.input and msg.wParam == VK_UP then
            if history_index < #history then
                history_index = history_index + 1
                set_input(history[#history - history_index + 1])
            end
        elseif msg.message == WM_KEYDOWN and msg.hwnd == m.input and msg.wParam == VK_DOWN then
            if history_index > 0 then
                history_index = history_index - 1
                set_input(history_index == 0 and "" or history[#history - history_index + 1])
            end
        else
            _user32.TranslateMessage(msg)
            _user32.DispatchMessageA(msg)
        end
    end

    local command = m.command
    m.command = nil
    return command
end

--- @section Output

--- Appends a line to the output, formatted like the terminal: `[2026-10-07 04:01:14] [INFO]: text`
--- @param message any Text to print, which may contain ANSI escape sequences
--- @param level string|nil Optional style override ("debug", "info", "success", "warn", "error", "fatal", "command")
function m.print(message, level)
    if not m.output then return end

    local raw = (tostring(message):gsub("\r?\n", "\r"))
    local stripped = (raw:gsub("\27%[[%d;]*m", ""))
    local has_ansi = stripped ~= raw
    local has_timestamp = stripped:find("^%[%d%d%d%d%-%d%d%-%d%d") ~= nil

    local tag = stripped:match("^%[(%a+)%]")
    local tag_level = tag and tag:lower() or nil
    if tag_level == "command" or not LEVEL_COLOURS[tag_level or ""] then
        tag_level = nil
    end

    local segments
    if has_timestamp then
        if has_ansi then
            segments = parse_ansi(raw, DEFAULT_STYLE)
        else
            local style = LEVEL_COLOURS[level or detect_level(stripped)] or DEFAULT_STYLE
            segments = { { text = stripped, colour = style.colour, bold = style.bold } }
        end
    elseif tag_level then
        local rest = (stripped:gsub("^%[%a+%]:?%s?", ""))
        local style = LEVEL_COLOURS[tag_level]
        segments = { {
            text = os.date("[%H:%M:%S] [") .. tag:upper() .. "]: " .. rest,
            colour = style.colour,
            bold = style.bold,
        } }
    elseif has_ansi then
        segments = parse_ansi(raw, LEVEL_COLOURS[level or ""] or DEFAULT_STYLE)
    else
        local style = LEVEL_COLOURS[level or ""] or DEFAULT_STYLE
        segments = { { text = stripped, colour = style.colour, bold = style.bold } }
    end

    segments[#segments].text = segments[#segments].text .. "\r"

    if not m.rich then
        local parts = {}
        for i, segment in ipairs(segments) do parts[i] = segment.text end
        local plain = (table.concat(parts):gsub("\r", "\r\n"))
        local length = _user32.GetWindowTextLengthA(m.output)
        _user32.SendMessageA(m.output, EM_SETSEL, length, length)
        _user32.SendMessageA(m.output, EM_REPLACESEL, 0, _ffi.cast("LPARAM", _ffi.cast("const char*", plain)))
        _user32.SendMessageA(m.output, EM_SCROLLCARET, 0, 0)
        return
    end

    local to_end = 0x7FFFFFFF
    local buffers = {}
    m.keepalive = buffers

    _user32.SendMessageW(m.output, EM_SETREADONLY, 0, 0)

    local format_failed = false

    for i, segment in ipairs(segments) do
        buffers[i] = wide(segment.text)
        _user32.SendMessageW(m.output, EM_SETSEL, to_end, to_end)
        if tonumber(apply_format(segment)) == 0 then format_failed = true end
        _user32.SendMessageW(m.output, EM_REPLACESEL, 0, pointer_to_lparam(buffers[i]))
    end

    _user32.SendMessageW(m.output, EM_SETREADONLY, 1, 0)
    _user32.SendMessageW(m.output, EM_SCROLLCARET, 0, 0)

    m.keepalive = nil

    if format_failed and not m.warned then
        m.warned = true
        m.print("[console] Windows rejected the colour format (EM_SETCHARFORMAT returned 0).")
    end
end

--- Prints the startup banner
function m.banner()
    local art = {
        [[ __  __   ___   ____   ___  _____ ]],
        [[|  \/  | / _ \ |  _ \ |_ _||_   _|]],
        [[| |\/| || | | || | | | | |   | |  ]],
        [[| |  | || |_| || |_| | | |   | |  ]],
        [[|_|  |_| \___/ |____/ |___|  |_|  ]],
    }

    for i, line in ipairs(art) do
        m.print(line, "banner" .. i)
    end
    m.print("")
    m.print("Modit Engine  -  Server Console  -  v" .. tostring(m.version), "title")

    local runtime = rawget(_G, "jit")
    local details = {}
    if runtime then
        details[#details + 1] = tostring(runtime.version)
        details[#details + 1] = tostring(runtime.os) .. " " .. tostring(runtime.arch)
    end
    details[#details + 1] = os.date("%Y-%m-%d %H:%M:%S")

    m.print(table.concat(details, "  |  "), "dim")
    m.print("Type 'help' for a list of command.", "dim")
    m.print("")
end

return m