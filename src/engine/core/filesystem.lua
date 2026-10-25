--- @module filesystem
--- @file src/engine/core/filesystem.lua
--- @description Raw file and directory access.

--- @section Imports

local raylib = require("src.engine.bindings.raylib")
local _ffi = raylib.ffi
local _rl = raylib.lib

--- @section Initialisation

local m = {}

--- @section Helpers

--- Joins a root and a path with a forward slash.
--- @param root string
--- @param path string
--- @return string
local function join(root, path)
    if root == "" then return path end
    return (root:gsub("[/\\]$", "")) .. "/" .. path
end

--- @section Getters

--- Gets the folder the exe is in.
--- @return string
function m.get_application_directory()
    return _ffi.string(_rl.GetApplicationDirectory())
end

--- Lists the files and folders inside a folder.
--- @param path string
--- @return string[]
function m.list_directory(path)
    local list = _rl.LoadDirectoryFiles(path)
    local result = {}

    for i = 0, list.count - 1 do
        result[#result + 1] = _ffi.string(list.paths[i])
    end

    _rl.UnloadDirectoryFiles(list)
    return result
end

--- @section Checks

--- Checks if a file exists.
--- @param path string
--- @return boolean
function m.file_exists(path)
    return _rl.FileExists(path)
end

--- Checks if a folder exists.
--- @param path string
--- @return boolean
function m.directory_exists(path)
    return _rl.DirectoryExists(path)
end

--- @section Resolving

--- Looks for a file in each root, in order. Returns the first full path found.
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

--- Reads a whole file into a Lua string.
--- @param path string
--- @return string|nil Contents, or nil if the file doesnt exist or cant be read
function m.read_file(path)
    if not _rl.FileExists(path) then return nil end

    local size = _ffi.new("int[1]")
    local data = _rl.LoadFileData(path, size)
    if data == nil then return nil end

    local content = _ffi.string(data, size[0])
    _rl.UnloadFileData(data)
    return content
end

return m