--- @script prelude
--- @file src/tools/build/prelude.lua
--- @description Runs inside a built game before the engine. Serves the embedded files, then starts src/main.lua.

--- @section Setup

local bundle = MODIT_BUNDLE
local real_loadfile = loadfile
local ROOTS = { "" }

--- @section Path Helpers

--- Normalise a file path to use forward slashes and remove leading "./" prefixes.
--- @param path string Path to normalise.
--- @return string path Normalised path.
local function normalise(path)
    path = path:gsub("\\", "/")
    while path:sub(1, 2) == "./" do
        path = path:sub(3)
    end
    return path
end

--- Normalise a directory path: no trailing slash, and "." means the bundle root.
--- @param path string Directory path.
--- @return string key Directory key as used by the bundle tree.
local function dir_key(path)
    path = normalise(path):gsub("/+$", "")
    if path == "." then return "" end
    return path
end

--- @section Embedded File Access

--- Load a file from the embedded bundle, falling back to the filesystem.
--- @param path string File path to load.
--- @return function|nil chunk Compiled file chunk, or nil on failure.
--- @return string|nil err Error message if loading fails.
function loadfile(path, ...)
    if type(path) == "string" then
        local key = normalise(path)
        local source = bundle.get(key)
        if source then
            return loadstring(source, "@" .. key)
        end
    end

    return real_loadfile(path, ...)
end

--- Execute a file using the embedded-aware loadfile implementation.
--- @param path string File path to execute.
--- @return any ... Values returned by the executed chunk.
function dofile(path)
    local chunk, err = loadfile(path)
    if not chunk then
        error(err, 0)
    end
    return chunk()
end

--- @section Embedded Directory Access

-- The stub only knows has/get. The builder writes an "@index" entry listing every key, and from it
-- the prelude adds directory listing so the sandbox and filesystem module can scan embedded folders.

local index_source = bundle.get("@index")
local index = index_source and loadstring(index_source)() or {}

local tree = { [""] = {} } -- directory key -> { [child path] = true }

--- Register a path as a child of its parent directory, creating parents as needed.
--- @param child string Embedded file or directory path.
local function register(child)
    local parent = child:match("^(.*)/[^/]*$") or ""
    local set = tree[parent]

    if not set then
        set = {}
        tree[parent] = set
    end

    if set[child] then
        return
    end

    set[child] = true

    if parent ~= "" then
        register(parent)
    end
end

for _, key in ipairs(index) do
    register(key)
end

--- List the entries directly inside an embedded directory.
--- @param dir string Directory path, e.g. "src/api" or ".".
--- @return table paths Sorted full paths of files and folders (empty if the directory is not embedded).
function bundle.list(dir)
    local out = {}
    local set = tree[dir_key(dir)]

    if set then
        for child in pairs(set) do
            out[#out + 1] = child
        end
        table.sort(out)
    end

    return out
end

--- Check whether a path is an embedded directory.
--- @param path string Directory path.
--- @return boolean exists True if files are embedded under that path.
function bundle.is_dir(path)
    return tree[dir_key(path)] ~= nil
end

--- @section Module Resolution

--- Find a module's embedded Lua file using the configured search roots.
--- @param name string Dotted Lua module name.
--- @return string|nil path Embedded file path, or nil if not found.
local function find_module(name)
    local base = name:gsub("%.", "/")

    for _, root in ipairs(ROOTS) do
        local file = root .. base .. ".lua"
        if bundle.has(file) then
            return file
        end

        local init = root .. base .. "/init.lua"
        if bundle.has(init) then
            return init
        end
    end
end

--- Register a package loader that prioritises embedded modules over loose files.
table.insert(package.loaders, 2, function(name)
    local file = find_module(name)
    if not file then
        return "\n\tno embedded module '" .. name .. "'"
    end

    local chunk, err = loadstring(bundle.get(file), "@" .. file)
    if not chunk then
        error(
            "error loading embedded module '" .. name .. "':\n" .. tostring(err),
            0
        )
    end

    return chunk
end)

--- @section Build Metadata

local meta_source = bundle.get("@meta")
local meta = meta_source and loadstring(meta_source)()

MODIT_NAME = meta and meta.name

--- @section Console Setup

--- Detach the Windows console when unavailable and redirect output to a log file.
--- Builds made with --console keep the terminal attached.
local function setup_console()
    if meta and meta.console then
        return
    end

    local ok, ffi = pcall(require, "ffi")
    if not ok or ffi.os ~= "Windows" then
        return
    end

    pcall(ffi.cdef, [[
        void* GetConsoleWindow(void);
        void* freopen(const char* path, const char* mode, void* stream);
    ]])
    pcall(ffi.cdef, "int FreeConsole(void);")
    pcall(function() ffi.C.FreeConsole() end)
    pcall(function()
        if ffi.C.GetConsoleWindow() == nil then
            ffi.C.freopen("game_output.log", "w", io.stdout)
            ffi.C.freopen("game_output.log", "a", io.stderr)
            io.stdout:setvbuf("line")
        end
    end)
end

setup_console()

--- @section Entry Arguments

--- Point src/main.lua at the embedded project: clients run --project, servers run --headless.
--- The stub sets the working directory to the exe's folder, so "." is the embedded project root.
local function setup_args()
    local mode = (meta and meta.target == "server") and "--headless" or "--project"

    local passthrough = {}
    for i = 1, #arg do
        passthrough[i] = arg[i]
    end

    arg[1] = mode
    arg[2] = "."

    for i, value in ipairs(passthrough) do
        arg[i + 2] = value
    end
end

setup_args()

--- @section Engine Bootstrap

local main_source = bundle.get("src/main.lua")
if not main_source then
    error("the game data has no engine entry (src/main.lua)", 0)
end

local main = assert(loadstring(main_source, "@src/main.lua"))
main()