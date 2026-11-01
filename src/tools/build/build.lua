--- @script build
--- @file src/tools/build/build.lua
--- @description Packages a project into a standalone game or server folder.

--- @section Constants

local IS_WINDOWS = package.config:sub(1, 1) == "\\"
local MAGIC = "MODITPK1"
local STUB_NAME = "modit_stub.exe"

local SHARED_DLLS = { "luajit.dll", "box3d.dll", "enet.dll" }
local CLIENT_DLLS = { "raylib.dll" }
local SERVER_DLLS = {}

local CLIENT_ONLY = {
    "^src/framework/renderer/",
    "^src/framework/audio/",
    "^src/framework/input/",
    "^src/framework/bindings/raylib%.lua$",
    "^src/framework/.*globals_client%.lua$",
}

local LUA_SKIP = { build = true, mods = true, saves = true, save = true, assets = true }

local BYTECODE_PREFIXES = { "src/framework/", "src/main.lua" }
local ENGINE_FONTS_DIR = "/src/assets/fonts"
local SERVER_ICON = "src/assets/branding/modit_icon.ico"

local USAGE = [[
usage: luajit build.lua <project> [options]

  --target <target>  build target: client or server (default: client)
  --name <name>      executable name (default: project folder name)
  --out <folder>     output folder (default: <project>/build/<name>)
  --console          keep the terminal attached (default: windowed, output goes to game_output.log)
  --no-console       hide the console window
  --bytecode         embed LuaJIT bytecode for engine code (project code and src/api stay source)
  --no-mods          do not copy the project's mods folder
  --loose-assets     copy assets/ next to the exe instead of embedding them
  --rebuild-stub     recompile the launcher stub (needs Visual Studio C++ tools)
  --stub <path>      use this launcher stub instead of src/bin/modit_stub.exe
  --log <file>       also write build output to a file
]]

--- @section Paths

local this_source = debug.getinfo(1, "S").source:match("^@(.*)$") or ""
local script_dir = this_source:match("^(.*)[/\\][^/\\]*$") or "."
local ROOT = script_dir .. "/../../.."
local RCEDIT_PATH = ROOT .. "/vendor/tools/rcedit-x64.exe"

--- @section Options

local opts = { target = "client" }

do
    local index = 1
    local function value_of(flag)
        index = index + 1
        local value = arg[index]
        if not value then print("missing value for " .. flag); os.exit(1) end
        return value
    end

    while index <= #arg do
        local flag = arg[index]
        if flag == "--target" then opts.target = value_of(flag)
        elseif flag == "--name" then opts.name = value_of(flag)
        elseif flag == "--out" then opts.out = value_of(flag)
        elseif flag == "--console" then opts.console = true
        elseif flag == "--no-console" then opts.console = false
        elseif flag == "--bytecode" then opts.bytecode = true
        elseif flag == "--no-mods" then opts.mods = false
        elseif flag == "--loose-assets" then opts.loose_assets = true
        elseif flag == "--rebuild-stub" then opts.rebuild_stub = true
        elseif flag == "--stub" then opts.stub = value_of(flag)
        elseif flag == "--log" then opts.log = value_of(flag)
        elseif flag:sub(1, 2) == "--" then print("unknown option: " .. flag); print(USAGE); os.exit(1)
        elseif not opts.project then opts.project = flag end
        index = index + 1
    end
end

if not opts.project then print(USAGE); os.exit(1) end
if opts.target ~= "client" and opts.target ~= "server" then
    print("invalid target '" .. tostring(opts.target) .. "' (expected client or server)")
    print(USAGE)
    os.exit(1)
end

local project = opts.project:gsub("[/\\]+$", "")

--- @section Logging

local log_file = opts.log and io.open(opts.log, "w")
if log_file then log_file:setvbuf("line") end

local function emit(level, text)
    print("[BUILD] " .. text)
    if log_file then
        for line in (text .. "\n"):gmatch("(.-)\n") do
            log_file:write(level, "\t", os.date("%H:%M:%S"), "\t", line, "\n")
        end
        log_file:flush()
    end
end

local function fail(text)
    emit("error", text)
    if log_file then log_file:close() end
    os.exit(1)
end

--- @section File Helpers

local function read_file(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function write_file(path, content)
    local handle = io.open(path, "wb")
    if not handle then return false end
    handle:write(content)
    handle:close()
    return true
end

local function file_exists(path)
    local handle = io.open(path, "rb")
    if not handle then return false end
    handle:close()
    return true
end

local function native(path)
    return IS_WINDOWS and path:gsub("/", "\\") or path
end

local function run(command)
    local a, _, c = os.execute(command)
    if a == true or a == 0 or c == 0 then return 0 end
    return type(a) == "number" and a or 1
end

local made_dirs = {}
local function make_dir(path)
    if made_dirs[path] then return end
    made_dirs[path] = true
    if IS_WINDOWS then os.execute('mkdir "' .. native(path) .. '" 2>nul')
    else os.execute('mkdir -p "' .. path .. '"') end
end

local function copy_file(from, to)
    local content = read_file(from)
    if not content then return false end
    local parent = to:match("^(.*)[/\\][^/\\]*$")
    if parent then make_dir(parent) end
    return write_file(to, content)
end

local function list_dir(path, folders)
    local command
    if IS_WINDOWS then
        command = ('dir %s /b "%s" 2>nul'):format(folders and "/a:d" or "/a:-d", native(path))
    else
        command = ('find "%s" -mindepth 1 -maxdepth 1 -type %s -printf "%%f\\n" 2>/dev/null')
            :format(path, folders and "d" or "f")
    end

    local names, pipe = {}, io.popen(command)
    if not pipe then return names end
    for line in pipe:lines() do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then names[#names + 1] = line end
    end
    pipe:close()
    table.sort(names)
    return names
end

local function scan_lua(dir, prefix, into, skip)
    for _, file in ipairs(list_dir(dir, false)) do
        if file:match("%.lua$") then into[prefix .. file] = dir .. "/" .. file end
    end
    for _, folder in ipairs(list_dir(dir, true)) do
        if folder:sub(1, 1) ~= "." and not (skip and skip[folder]) then
            scan_lua(dir .. "/" .. folder, prefix .. folder .. "/", into)
        end
    end
end

local function scan_assets(dir, prefix, into)
    for _, file in ipairs(list_dir(dir, false)) do
        if file:sub(1, 1) ~= "." then into[prefix .. file] = dir .. "/" .. file end
    end
    for _, folder in ipairs(list_dir(dir, true)) do
        if folder:sub(1, 1) ~= "." then scan_assets(dir .. "/" .. folder, prefix .. folder .. "/", into) end
    end
end

local function copy_tree(from, to, relative, skip, counter)
    for _, file in ipairs(list_dir(from, false)) do
        local rel = relative .. file
        if file:sub(1, 1) ~= "." and not skip(rel, false) then
            if copy_file(from .. "/" .. file, to .. "/" .. file) then counter.files = counter.files + 1
            else emit("warn", "could not copy " .. rel) end
        end
    end
    for _, folder in ipairs(list_dir(from, true)) do
        local rel = relative .. folder .. "/"
        if folder:sub(1, 1) ~= "." and not skip(rel, true) then
            copy_tree(from .. "/" .. folder, to .. "/" .. folder, rel, skip, counter)
        end
    end
end

--- @section Launcher Stub

local function find_vcvars()
    local override = os.getenv("VCVARS")
    if override then return override end

    local program_files = os.getenv("ProgramFiles(x86)") or "C:\\Program Files (x86)"
    local vswhere = program_files .. "\\Microsoft Visual Studio\\Installer\\vswhere.exe"
    local pipe = io.popen('""' .. vswhere .. '" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>nul"')
    if not pipe then return nil end

    local install = pipe:read("*l")
    pipe:close()
    if not install or install == "" then return nil end

    local vcvars = install:gsub("%s+$", "") .. "\\VC\\Auxiliary\\Build\\vcvars64.bat"
    if file_exists(vcvars) then return vcvars end
end

local function build_stub(cache_path)
    if not IS_WINDOWS then fail("the launcher stub can only be compiled on Windows. Pass --stub <path> instead.") end
    emit("info", "Compiling the launcher stub (one time only)...")

    local include = os.getenv("LUA_INCLUDE") or "C:\\luajit\\src"
    local library = os.getenv("LUA_LIB")
    local executable = (arg[-1] or ""):gsub("\\", "/")
    local install_root = executable:match("^(.*)/bin/[^/]+$")

    if install_root and not os.getenv("LUA_INCLUDE") and not file_exists(include .. "/lua.h") then
        include = install_root .. "/include"
    end

    if not library then
        local candidates = { "C:\\luajit\\src\\lua51.lib", "C:\\luajit\\lib\\lua51.lib" }
        if install_root then
            candidates[#candidates + 1] = install_root .. "/lib/lua51.lib"
            candidates[#candidates + 1] = install_root .. "/lib/luajit.lib"
        end
        for _, candidate in ipairs(candidates) do
            if file_exists(candidate) then
                library = candidate
                break
            end
        end
    end

    if not file_exists(include .. "/lua.h") then
        fail("LuaJIT headers not found. Set LUA_INCLUDE to the folder containing lua.h. Checked: " .. include)
    end
    if not library or not file_exists(library) then
        fail("LuaJIT import library not found. Set LUA_LIB to the correct MSVC-compatible .lib file (normally lua51.lib).")
    end

    local temp = (os.getenv("TEMP") or ".") .. "\\modit_build"
    make_dir(temp)

    local setup = ""
    if not os.getenv("VSCMD_VER") then
        local vcvars = find_vcvars()
        if not vcvars then
            fail("could not find Visual Studio with the C++ tools.\nInstall 'Desktop development with C++', or set VCVARS to your vcvars64.bat path.")
        end
        setup = ('call "%s" >nul 2>&1\r\nif errorlevel 1 exit /b 1\r\n'):format(vcvars)
    end

    local stub_source = loadfile(ROOT .. "/src/tools/build/stub.lua")
    if not stub_source then fail("src/tools/build/stub.lua not found") end

    local source = temp .. "\\stub.c"
    write_file(source, stub_source())

    local script = "@echo off\r\n" .. setup
        .. ('cl /nologo /O2 /MT /I"%s" "%s" /Fo"%s\\stub.obj" /Fe"%s\\stub.exe" /link /SUBSYSTEM:WINDOWS /ENTRY:mainCRTStartup "%s" user32.lib\r\n')
            :format(include, source, temp, temp, library)
        .. "exit /b %errorlevel%\r\n"

    local bat = temp .. "\\build_stub.bat"
    local log = temp .. "\\build_stub.log"
    write_file(bat, script)

    local command = ('cmd.exe /d /s /c ""%s" > "%s" 2>&1"'):format(bat, log)
    local code = run(command)

    if code ~= 0 then
        fail("compiling the stub failed:\n" .. (read_file(log) or "No compiler output was captured."))
    end

    local built = read_file(temp .. "\\stub.exe")
    if not built then fail("the compiler did not produce a stub") end

    make_dir(ROOT .. "/src/bin")
    if not write_file(cache_path, built) then fail("could not cache launcher: " .. cache_path) end

    emit("success", "Launcher stub ready: " .. cache_path)
    return built
end

local function get_stub()
    if opts.stub then
        local custom = read_file(opts.stub)
        if not custom then fail("could not read stub: " .. opts.stub) end
        return custom
    end

    local cache_path = ROOT .. "/src/bin/" .. STUB_NAME
    if not opts.rebuild_stub then
        local cached = read_file(cache_path)
        if cached then return cached end
    end
    return build_stub(cache_path)
end

local function set_subsystem(exe, console)
    if exe:sub(1, 2) ~= "MZ" then return exe, false end
    local b1, b2, b3, b4 = exe:byte(0x3D, 0x40)
    local pe = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
    if exe:sub(pe + 1, pe + 4) ~= "PE\0\0" then return exe, false end
    local at = pe + 24 + 68 + 1
    return exe:sub(1, at - 1) .. string.char(console and 3 or 2, 0) .. exe:sub(at + 2), true
end

--- @section Packing

local function u32(value)
    return string.char(value % 256, math.floor(value / 256) % 256, math.floor(value / 65536) % 256, math.floor(value / 16777216) % 256)
end

local function pack(entries)
    local keys = {}
    for key in pairs(entries) do keys[#keys + 1] = key end
    table.sort(keys)

    local parts = {}
    for _, key in ipairs(keys) do
        local data = entries[key]
        parts[#parts + 1] = u32(#key) .. key .. u32(#data) .. data
    end

    local body = table.concat(parts)
    return body .. u32(#keys) .. u32(#body) .. MAGIC
end

local function wants_bytecode(key)
    for _, prefix in ipairs(BYTECODE_PREFIXES) do
        if key:sub(1, #prefix) == prefix then return true end
    end
    return false
end

local function embed(key, path)
    local source = read_file(path)
    if not source then fail("could not read " .. path) end
    local chunk, err = loadstring(source, "@" .. key)
    if not chunk then fail(("syntax error in %s:\n%s"):format(key, tostring(err))) end
    if opts.bytecode and wants_bytecode(key) then return string.dump(chunk) end
    return source
end

local function read_config()
    local source = read_file(project .. "/config.lua")
    local chunk, err = loadstring(source, "@config.lua")
    if not chunk then return nil, err end

    setfenv(chunk, {})
    local ok, conf = pcall(chunk)
    if not ok then return nil, tostring(conf) end
    if type(conf) ~= "table" then return nil, "config.lua must return a table" end

    return conf
end

--- @section Executable Icon

local function set_executable_icon(exe_path, conf, target)
    if not IS_WINDOWS then return end

    local build = type(conf.build) == "table" and conf.build or {}
    local icons = type(build.icons) == "table" and build.icons or {}
    local windows = type(icons.windows) == "table" and icons.windows or {}

    local icon
    if target == "server" then icon = windows.server_exe
    else icon = windows.client_exe end

    if icon == nil or icon == false or icon == "" then
        emit("info", "No custom icon configured for " .. target .. " executable")
        return
    end
    if type(icon) ~= "string" then fail("configured " .. target .. " executable icon must be a path string") end

    local absolute = icon:match("^%a:[/\\]") or icon:match("^[/\\][/\\]") or icon:sub(1, 1) == "/"
    local icon_path = absolute and icon or (project .. "/" .. icon)

    if not file_exists(RCEDIT_PATH) then fail("rcedit not found: " .. RCEDIT_PATH) end
    if not file_exists(icon_path) then fail("configured " .. target .. " icon not found: " .. icon_path) end

    emit("info", "Setting " .. target .. " executable icon: " .. icon_path)
    local command = ('cmd.exe /d /s /c ""%s" "%s" --set-icon "%s""'):format(RCEDIT_PATH, exe_path, icon_path)

    local result = os.execute(command)
    if not (result == true or result == 0) then
        fail("rcedit failed for " .. target .. " executable (result=" .. tostring(result) .. ")")
    end

    emit("success", "Applied custom icon to " .. exe_path)
end

--- @section Runtime Libraries

local function find_dll(dll)
    local stem = dll:gsub("%.dll$", "")
    local candidates = {
        ROOT .. "/vendor/windows/" .. dll,
        ROOT .. "/vendor/" .. stem .. "/" .. dll,
        ROOT .. "/vendor/" .. dll,
    }

    for _, path in ipairs(candidates) do
        if file_exists(path) then return path end
    end

    return nil, ("missing %s (looked in vendor/windows, vendor/%s and vendor)"):format(dll, stem)
end

--- @section Build

if not file_exists(project .. "/config.lua") then
    fail("not a modit project (no config.lua): " .. project)
end
if opts.target == "server" and not file_exists(project .. "/server/init.lua") then
    fail("no server code (server/init.lua not found): " .. project)
end

local conf, conf_err = read_config()
if not conf then fail("config.lua: " .. tostring(conf_err)) end

local project_name = project:match("([^/\\]+)$") or "game"
if project_name == "." or project_name == ".." then project_name = "game" end

local name = opts.name or (opts.target == "server" and (project_name .. "_server") or project_name)
name = name:gsub("[^%w_%-]", "_")

local console = opts.console
if console == nil then console = false end
if opts.mods == nil then opts.mods = type(conf.modding) == "table" and conf.modding.enabled == true end

local out = (opts.out or (project .. "/build/" .. name)):gsub("[/\\]+$", "")
emit("info", ("Building '%s' target (%s mode)"):format(opts.target, console and "console" or "windowed"))

--- @section Embedded files

emit("info", "Collecting Lua files and game assets...")
local files = {}
scan_lua(ROOT .. "/src/framework", "src/framework/", files)
scan_lua(ROOT .. "/src/api", "src/api/", files)

for _, file in ipairs({ "main.lua", "version.lua" }) do
    if file_exists(ROOT .. "/src/" .. file) then files["src/" .. file] = ROOT .. "/src/" .. file end
end
if not files["src/main.lua"] then
    fail("src/main.lua not found, is the script inside the engine folder?")
end

local project_files = {}
scan_lua(project, "", project_files, LUA_SKIP)
for key, path in pairs(project_files) do
    if key:match("^src/") then fail("a project folder named 'src' is reserved for the engine: " .. key) end
    files[key] = path
end

if opts.target == "server" then
    local removed = 0
    for key in pairs(files) do
        for _, pattern in ipairs(CLIENT_ONLY) do
            if key:match(pattern) then
                files[key] = nil
                removed = removed + 1
                break
            end
        end
    end
    emit("info", ("Server build: left out %d client-only engine files"):format(removed))
end

local build_config = type(conf.build) == "table" and conf.build or {}
local engine_assets = type(build_config.engine_assets) == "table" and build_config.engine_assets or {}

local assets = {}
if opts.target == "server" then
    emit("info", "Server build: skipping assets/")
else
    scan_assets(project .. "/assets", "assets/", assets)

    if engine_assets.fonts == true then
        local source = ROOT .. ENGINE_FONTS_DIR
        local fonts = {}
        scan_assets(source, "assets/engine/fonts/", fonts)

        local font_count = 0
        for key, path in pairs(fonts) do
            assets[key] = path
            font_count = font_count + 1
        end

        if font_count == 0 then emit("warn", "No engine fonts found at " .. source)
        else emit("info", ("Collected %d engine font assets"):format(font_count)) end
    end
end

local entries, count = {}, 0
for key, path in pairs(files) do
    entries[key] = embed(key, path)
    count = count + 1
end

local asset_count = 0
for key, path in pairs(assets) do
    if not opts.loose_assets then
        local data = read_file(path)
        if not data then fail("could not read asset " .. path) end
        entries[key] = data
    end
    asset_count = asset_count + 1
end

local index = {}
for key in pairs(entries) do index[#index + 1] = ("%q"):format(key) end
table.sort(index)
entries["@index"] = "return {\n" .. table.concat(index, ",\n") .. "\n}"

local prelude = read_file(ROOT .. "/src/tools/build/prelude.lua")
if not prelude then fail("src/tools/build/prelude.lua not found") end
entries["@prelude"] = prelude
entries["@meta"] = ("return { name = %q, target = %q, console = %s }"):format(name, opts.target, tostring(console))

emit("info", ("Embedding %d Lua files%s"):format(count, opts.bytecode and " (engine code as bytecode)" or ""))
if opts.loose_assets then
    emit("info", ("Copying %d game assets next to the exe"):format(asset_count))
else
    emit("info", ("Embedding %d game assets"):format(asset_count))
end

--- @section Executable

local exe = get_stub()
local patched
exe, patched = set_subsystem(exe, console)
if not patched then emit("warn", "stub is not a Windows executable, console mode was not applied") end

make_dir(out)
local exe_path = out .. "/" .. name .. ".exe"

local temp_stub = out .. "/" .. name .. "_stub.exe"
if not write_file(temp_stub, exe) then fail("could not write temporary stub: " .. temp_stub) end
set_executable_icon(temp_stub, conf, opts.target)
exe = read_file(temp_stub)
os.remove(temp_stub)
if not exe then fail("could not read icon-patched stub") end

local packed = exe .. pack(entries)
if not write_file(exe_path, packed) then fail("could not write " .. exe_path .. " (is the game still running?)") end

--- @section Runtime files

local runtime_dlls = {}
for _, dll in ipairs(SHARED_DLLS) do runtime_dlls[#runtime_dlls + 1] = dll end

local target_dlls = opts.target == "server" and SERVER_DLLS or CLIENT_DLLS
for _, dll in ipairs(target_dlls) do runtime_dlls[#runtime_dlls + 1] = dll end

for _, dll in ipairs(runtime_dlls) do
    local found, missing = find_dll(dll)
    if not found then fail(missing) end
    if not copy_file(found, out .. "/" .. dll) then fail("could not copy " .. dll .. " from " .. found) end
    emit("info", "Copied runtime DLL: " .. dll)
end

if opts.loose_assets then
    for key, path in pairs(assets) do
        if not copy_file(path, out .. "/" .. key) then fail("could not copy asset " .. path) end
    end
end

if opts.target == "server" and file_exists(ROOT .. "/" .. SERVER_ICON) then
    copy_file(ROOT .. "/" .. SERVER_ICON, out .. "/" .. SERVER_ICON)
end

if opts.mods then
    make_dir(out .. "/mods")
    emit("info", "Initialized external mods folder: /mods")
end

--- @section Project files: everything not embedded (data files, docs, bundled mods). Lua and assets/ are already in the exe

local extras = { files = 0 }
copy_tree(project, out, "", function(relative, is_folder)
    if is_folder then
        return relative == "build/" or relative == "assets/" or relative == "saves/" or relative == "save/"
            or (relative == "mods/" and not opts.mods)
    end

    if relative:match("%.log$") or relative:match("%.modit$") then return true end

    return relative:match("%.lua$") ~= nil and not relative:match("^mods/")
end, extras)

emit("info", ("Copied %d project files"):format(extras.files))
emit("success", ("Built %s (%.1f KB)"):format(exe_path, #packed / 1024))
if log_file then log_file:close() end