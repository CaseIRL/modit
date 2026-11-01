--- @module filesystem
--- @file src/framework/core/filesystem.lua
--- @description Raw file and directory access. No raylib dependency - this has to work in the
--- headless server realm too, where raylib.lua is never even embedded (see build.lua CLIENT_ONLY).

--- @section Imports

local _ffi = require("ffi")
local _bit = require("bit")

--- @section Initialisation

local m = {}
local IS_WINDOWS = _ffi.os == "Windows"

--- @section Windows FFI

local _kernel32

if IS_WINDOWS then
    _ffi.cdef[[
        typedef unsigned long DWORD;
        typedef int BOOL;

        typedef struct {
            DWORD dwLowDateTime;
            DWORD dwHighDateTime;
        } FILETIME;

        typedef struct {
            DWORD dwFileAttributes;
            FILETIME ftCreationTime;
            FILETIME ftLastAccessTime;
            FILETIME ftLastWriteTime;
            DWORD nFileSizeHigh;
            DWORD nFileSizeLow;
        } WIN32_FILE_ATTRIBUTE_DATA;

        typedef struct {
            DWORD dwFileAttributes;
            FILETIME ftCreationTime;
            FILETIME ftLastAccessTime;
            FILETIME ftLastWriteTime;
            DWORD nFileSizeHigh;
            DWORD nFileSizeLow;
            DWORD dwReserved0;
            DWORD dwReserved1;
            char cFileName[260];
            char cAlternateFileName[14];
        } WIN32_FIND_DATAA;

        void* FindFirstFileA(const char* lpFileName, WIN32_FIND_DATAA* lpFindFileData);
        BOOL FindNextFileA(void* hFindFile, WIN32_FIND_DATAA* lpFindFileData);
        BOOL FindClose(void* hFindFile);
        DWORD GetFileAttributesA(const char* lpFileName);
        BOOL GetFileAttributesExA(const char* lpFileName, int fInfoLevelId, void* lpFileInformation);
        DWORD GetCurrentDirectoryA(DWORD nBufferLength, char* lpBuffer);
    ]]
    _kernel32 = _ffi.load("kernel32")
end

local INVALID_FILE_ATTRIBUTES = 0xFFFFFFFF
local FILE_ATTRIBUTE_DIRECTORY = 0x10
local GET_FILE_EX_INFO_STANDARD = 0
local FILETIME_EPOCH_DIFF = 116444736000000000ULL -- 100ns ticks between 1601-01-01 and 1970-01-01

--- Converts a Windows FILETIME (two DWORDs) to a Unix timestamp in seconds.
--- Done in 64-bit cdata space, not Lua numbers - the raw tick count is well
--- outside what a double can represent exactly, the final seconds value isn't.
--- @param ft cdata FILETIME
--- @return number seconds
local function filetime_to_unix(ft)
    local high = _ffi.cast("uint64_t", ft.dwHighDateTime)
    local low = _ffi.cast("uint64_t", ft.dwLowDateTime)
    local ticks = high * 4294967296ULL + low
    return tonumber((ticks - FILETIME_EPOCH_DIFF) / 10000000ULL)
end

--- Reads a Windows file/directory attributes bitmask, or nil if the path doesn't exist.
--- @param path string
--- @return number|nil
local function win_attributes(path)
    local attr = tonumber(_kernel32.GetFileAttributesA(path))
    if attr == nil or attr == INVALID_FILE_ATTRIBUTES then return nil end
    return attr
end

--- @section Helpers

--- Joins a root and a path with a forward slash.
--- @param root string
--- @param path string
--- @return string
local function join(root, path)
    if root == "" then return path end
    return (root:gsub("[/\\]$", "")) .. "/" .. path
end

--- Runs a shell command and returns its first line of output, or nil.
--- @param command string
--- @return string|nil
local function shell_line(command)
    local pipe = io.popen(command)
    if not pipe then return nil end
    local line = pipe:read("*l")
    pipe:close()
    return line
end

--- @section Getters

--- Gets the folder the process is running from (trailing slash included, matching raylib's
--- GetApplicationDirectory). For packaged builds the launcher stub already chdir's to the exe's
--- folder before Lua starts, so "current directory" is the right answer in both dev and packaged runs.
--- @return string
function m.get_application_directory()
    if IS_WINDOWS then
        local size = 4096
        local buffer = _ffi.new("char[?]", size)
        local length = _kernel32.GetCurrentDirectoryA(size, buffer)
        if length == 0 or length >= size then return "./" end
        return _ffi.string(buffer, length) .. "/"
    end

    local dir = shell_line("pwd")
    return (dir or ".") .. "/"
end

--- Lists the files and folders directly inside a folder, as full joined paths.
--- @param path string
--- @return string[]
function m.list_directory(path)
    local result = {}

    if IS_WINDOWS then
        local find_data = _ffi.new("WIN32_FIND_DATAA")
        local handle = _kernel32.FindFirstFileA(path .. "/*", find_data)
        if _ffi.cast("intptr_t", handle) == -1 then return result end

        repeat
            local name = _ffi.string(find_data.cFileName)
            if name ~= "." and name ~= ".." then
                result[#result + 1] = join(path, name)
            end
        until _kernel32.FindNextFileA(handle, find_data) == 0

        _kernel32.FindClose(handle)
        return result
    end

    local pipe = io.popen('ls -a "' .. path .. '" 2>/dev/null')
    if not pipe then return result end
    for line in pipe:lines() do
        if line ~= "." and line ~= ".." then
            result[#result + 1] = join(path, line)
        end
    end
    pipe:close()
    return result
end

--- Last modified time of a file for hot reload.
--- @param path string
--- @return number
function m.get_file_mod_time(path)
    if IS_WINDOWS then
        local data = _ffi.new("WIN32_FILE_ATTRIBUTE_DATA")
        if _kernel32.GetFileAttributesExA(path, GET_FILE_EX_INFO_STANDARD, data) == 0 then return 0 end
        return filetime_to_unix(data.ftLastWriteTime)
    end

    return tonumber(shell_line('stat -c %Y "' .. path .. '" 2>/dev/null')) or 0
end

--- Last segment of a path.
--- @param path string
--- @return string
function m.get_file_name(path)
    return path:match("[^/\\]+$") or path
end

--- @section Checks

--- Checks if a file exists (false for directories, matching raylib's FileExists).
--- @param path string
--- @return boolean
function m.file_exists(path)
    if IS_WINDOWS then
        local attr = win_attributes(path)
        return attr ~= nil and _bit.band(attr, FILE_ATTRIBUTE_DIRECTORY) == 0
    end

    local handle = io.open(path, "rb")
    if not handle then return false end
    handle:close()
    return true
end

--- Checks if a folder exists.
--- @param path string
--- @return boolean
function m.directory_exists(path)
    if IS_WINDOWS then
        local attr = win_attributes(path)
        return attr ~= nil and _bit.band(attr, FILE_ATTRIBUTE_DIRECTORY) ~= 0
    end

    local ok = os.execute('test -d "' .. path .. '"')
    return ok == true or ok == 0
end

--- @section Resolving

--- Looks for a file in each root, in order.
--- @param path string File path, relative or absolute
--- @param roots string[] Folders to look in ("" means use the path as given)
--- @return string|nil
function m.resolve(path, roots)
    path = path:gsub("\\", "/"):gsub("^%./", "")

    for _, root in ipairs(roots) do
        local full = join(root, path)
        if m.file_exists(full) then
            return full
        end
    end
    return nil
end

--- @section Reading

--- Reads a whole file into a Lua string. Plain io - no platform branch needed here.
--- @param path string
--- @return string|nil Contents, or nil if the file doesn't exist or can't be read
function m.read_file(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local content = handle:read("*a")
    handle:close()
    return content
end

return m