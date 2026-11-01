--- @module mods
--- @file src/framework/core/mods.lua
--- @description Finds, starts, stops and hot-reloads mods.

--- @section Imports

local _log = require("src.framework.core.log")
local _fs = require("src.framework.core.filesystem")
local _sandbox = require("src.framework.core.sandbox")
local _event = require("src.api.event")
local _mods = require("src.api.mods")

--- @section Constants

local API_VERSION = "0.1.0"
local REALMS = { client = true, server = true }
local POLL_INTERVAL = 0.25
local SCALARS = { "modit_api", "name", "label", "description", "author", "version", "license" }
local LISTS = { "depends", "provides", "assets", "shared", "client", "server" }
local REQUIRED = { "modit_api", "name", "version" }
local FILE_LISTS = { "shared", "client", "server" }

--- @section Initialisation

local m = {
    root = nil,
    config = {},
    enabled = false,
}

local log = _log.scoped("mods")
local mods = {}
local pending = {}
local last_poll = 0

--- @section Helpers

--- Checks that a name is safe to use as a folder and identifier.
--- @param id any
--- @return boolean
local function is_valid_id(id)
    if type(id) ~= "string" then
        return false
    end

    return id:match("^[%a_][%w_%-]*$") ~= nil
end

--- Converts a manifest file entry ("lib/util.lua") into a module name ("lib.util").
--- @param file any
--- @return string|nil Module name, or nil if the entry is not a plain relative .lua path
local function file_to_module(file)
    if type(file) ~= "string" then
        return nil
    end

    local stem = file:match("^(.+)%.lua$")
    if not stem or stem:find(".", 1, true) then
        return nil
    end

    stem = stem:gsub("/", ".")

    for segment in (stem .. "."):gmatch("([^%.]*)%.") do
        if not segment:match("^[%a_][%w_]*$") then
            return nil
        end
    end

    return stem
end

--- Checks that a path stays inside the mod folder.
--- @param path any
--- @return boolean
local function is_safe_relative_path(path)
    if type(path) ~= "string" or path == "" then
        return false
    end

    if path:find("\\", 1, true) or path:sub(1, 1) == "/" or path:match("^%a:") then
        return false
    end

    for segment in path:gmatch("[^/]+") do
        if segment == ".." then
            return false
        end
    end

    return true
end

--- Copies a list so shared tables cant be changed by other code.
--- @param list table
--- @return table
local function copy_list(list)
    local out = {}

    for index, value in ipairs(list) do
        out[index] = value
    end

    return out
end

--- Recursively collects every .lua file under a directory, sorted.
--- @param dir string
--- @param out string[]
--- @return string[]
local function collect_lua_files(dir, out)
    local entries = {}

    for _, entry in ipairs(_fs.list_directory(dir) or {}) do
        if type(entry) == "string" then
            entries[#entries + 1] = entry
        end
    end

    table.sort(entries)

    for _, entry in ipairs(entries) do
        if entry:match("%.lua$") then
            out[#out + 1] = entry
        elseif _fs.directory_exists(entry) then
            collect_lua_files(entry, out)
        end
    end

    return out
end

--- Snapshots the modification times of a mods files for change detection.
--- @param mod table
--- @return table path -> modification time
local function signature_of(mod)
    local sig = {}

    for _, path in ipairs(collect_lua_files(mod.dir, {})) do
        sig[path] = _fs.get_file_mod_time(path)
    end

    return sig
end

--- Compares two signatures.
--- @param a table
--- @param b table
--- @return boolean True if identical
local function same_signature(a, b)
    for path, time in pairs(a) do
        if b[path] ~= time then
            return false
        end
    end

    for path in pairs(b) do
        if a[path] == nil then
            return false
        end
    end

    return true
end

--- Publishes read-only mod info to the public mods API.
local function sync_public_registry()
    local registry = {}

    for name, mod in pairs(mods) do
        local manifest = mod.manifest

        registry[name] = {
            label = manifest.label,
            description = manifest.description,
            version = manifest.version,
            author = manifest.author or "Unknown",
            license = manifest.license,
            provides = copy_list(manifest.provides),
            realm = mod.realm,
            state = mod.state,
        }
    end

    _mods.set_registry(registry)
end

--- Joins print arguments into one tab separated string.
--- @param ... any
--- @return string
local function join_args(...)
    local parts = {}

    for index = 1, select("#", ...) do
        parts[index] = tostring((select(index, ...)))
    end

    return table.concat(parts, "\t")
end

--- Sorted list of all mod names.
--- @param descending boolean|nil
--- @return string[]
local function sorted_names(descending)
    local names = {}

    for name in pairs(mods) do
        names[#names + 1] = name
    end

    if descending then
        table.sort(names, function(a, b)
            return a > b
        end)
    else
        table.sort(names)
    end

    return names
end

--- @section Manifest

--- Builds the function behind one manifest declaration.
--- @param manifest table Table the value is stored in
--- @param declared table Keys already declared
--- @param key string Declaration name
--- @param expected string Lua type the value must have
--- @return function
local function make_declaration(manifest, declared, key, expected)
    return function(value)
        if declared[key] then
            error(key .. " declared more than once", 2)
        end

        if type(value) ~= expected then
            error(("%s must be a %s"):format(key, expected == "table" and "list" or expected), 2)
        end

        declared[key] = true
        manifest[key] = value
    end
end

--- Runs manifest.lua in a declarations-only environment.
--- @param source string Manifest text
--- @param chunkname string Name used in error messages
--- @return table|nil Manifest, or nil plus an error message
local function parse_manifest(source, chunkname)
    local manifest = {}
    local declared = {}
    local env = {}

    for _, key in ipairs(LISTS) do
        manifest[key] = {}
        env[key] = make_declaration(manifest, declared, key, "table")
    end

    for _, key in ipairs(SCALARS) do
        env[key] = make_declaration(manifest, declared, key, "string")
    end

    setmetatable(env, {
        __index = function(_, key)
            error(("unknown declaration '%s'"):format(tostring(key)), 2)
        end,
    })

    local chunk, err = load(source, chunkname, "t", env)
    if not chunk then
        return nil, err
    end

    local ok, result = pcall(chunk)
    if not ok then
        return nil, tostring(result)
    end

    if result ~= nil then
        return nil, "manifest must only use declarations, not return a value"
    end

    return manifest
end

--- Checks that every entry in a list is a valid name.
--- @param list table
--- @param label string List name for the error message
--- @return string|nil Error message, or nil if valid
local function validate_names(list, label)
    for index, item in ipairs(list) do
        if not is_valid_id(item) then
            return ("%s[%d] is not a valid name"):format(label, index)
        end
    end

    return nil
end

--- Checks that every entry in a list is a lua file that can be required.
--- @param list table
--- @param label string List name for the error message
--- @return string|nil Error message, or nil if valid
local function validate_files(list, label)
    for _, file in ipairs(list) do
        if not file_to_module(file) then
            return ("bad file in %s: %s (use plain names like \"main.lua\" or \"lib/util.lua\")"):format(label, tostring(file))
        end
    end

    return nil
end

--- Checks that every asset path stays inside the mod folder.
--- @param list table
--- @return string|nil Error message, or nil if valid
local function validate_assets(list)
    for index, path in ipairs(list) do
        if not is_safe_relative_path(path) then
            return ("assets[%d] must be a relative path inside the mod folder"):format(index)
        end
    end

    return nil
end

--- Checks a parsed manifest.
--- @param manifest table
--- @param folder string Name of the mods folder
--- @return string|nil Error message, or nil if valid
local function validate_manifest(manifest, folder)
    for _, key in ipairs(REQUIRED) do
        if manifest[key] == nil or manifest[key] == "" then
            return ("missing required declaration '%s'"):format(key)
        end
    end

    if manifest.modit_api ~= API_VERSION then
        return ("unsupported modit_api %s (expected %s)"):format(manifest.modit_api, API_VERSION)
    end

    if not is_valid_id(manifest.name) then
        return "name may only use letters, digits, _ and -"
    end

    if manifest.name ~= folder then
        return ("name '%s' must match the folder name '%s'"):format(manifest.name, folder)
    end

    local err = validate_names(manifest.depends, "depends")
    if err then
        return err
    end

    err = validate_names(manifest.provides, "provides")
    if err then
        return err
    end

    err = validate_assets(manifest.assets)
    if err then
        return err
    end

    for _, list_name in ipairs(FILE_LISTS) do
        err = validate_files(manifest[list_name], list_name)
        if err then
            return err
        end
    end

    return nil
end

--- Reads, parses and validates a mods manifest.lua.
--- @param name string Mod folder name
--- @return table|nil Manifest, or nil plus an error message
local function read_manifest(name)
    local path = m.root .. "/" .. name .. "/manifest.lua"

    local source = _fs.read_file(path)
    if not source then
        return nil, "no manifest.lua"
    end

    local manifest, err = parse_manifest(source, "@" .. path)
    if not manifest then
        return nil, err
    end

    err = validate_manifest(manifest, name)
    if err then
        return nil, err
    end

    manifest.label = manifest.label or manifest.name

    return manifest
end

--- @section Lifecycle Internals

--- Runs stop handlers in reverse order and releases everything the mod owns.
--- @param mod table
local function teardown(mod)
    for index = #(mod.handlers or {}), 1, -1 do
        local ok, err = pcall(mod.handlers[index])

        if not ok then
            log.error(("%s: stop handler failed: %s"):format(mod.name, tostring(err)))
        end
    end

    if mod.env then
        _sandbox.release_owner(mod.realm, mod.name)
    end

    mod.env = nil
    mod.handlers = nil
end

--- Marks a mod as failed after cleaning it up.
--- @param mod table
--- @param err any
--- @return boolean, string
local function fail(mod, err)
    teardown(mod)

    mod.state = "failed"
    mod.signature = signature_of(mod)

    log.error(("%s: %s"):format(mod.name, tostring(err)))
    sync_public_registry()

    return false, tostring(err)
end

--- Builds the `mod` table that the mod sees as a global.
--- @param mod table
--- @return table
local function make_handle(mod)
    local manifest = mod.manifest

    return {
        name = mod.name,
        label = manifest.label,
        realm = mod.realm,
        dir = mod.dir,
        version = manifest.version,
        author = manifest.author,
        description = manifest.description,
        license = manifest.license,

        on_stop = function(callback)
            if type(callback) ~= "function" then
                error("on_stop expects a function", 2)
            end

            mod.handlers[#mod.handlers + 1] = callback
        end,
    }
end

--- @section Functions

--- Sets up the manager. Call once before scan().
--- @param config table Project config (reads config.modding and config.modules)
--- @param root string|nil Mods folder (default "mods")
function m.init(config, root)
    m.config = config or {}
    m.root = ((root or "mods"):gsub("[/\\]$", ""))
    m.enabled = type(m.config.modding) == "table" and m.config.modding.enabled == true

    _event.register("mod_started", "A mod finished starting (name, realm)")
    _event.register("mod_stopped", "A mod stopped (name)")
end

--- Finds mod folders and reads their manifests.
function m.scan()
    if not m.enabled then
        return
    end

    if not _fs.directory_exists(m.root) then
        log.warn("folder not found: " .. m.root)
        return
    end

    for _, path in ipairs(_fs.list_directory(m.root) or {}) do
        local id = type(path) == "string" and _fs.get_file_name(path)

        if id and id:sub(1, 1) ~= "." and _fs.directory_exists(path) then
            if not is_valid_id(id) then
                log.warn(id .. ": skipped, folder names may only use letters, digits, _ and -")
            else
                local existing = mods[id]

                if not existing or existing.state ~= "started" then
                    local manifest, err = read_manifest(id)

                    if manifest then
                        if existing then
                            existing.manifest = manifest
                        else
                            mods[id] = {
                                name = id,
                                dir = m.root .. "/" .. id,
                                manifest = manifest,
                                state = "stopped",
                            }
                        end
                    else
                        log.warn(("%s: skipped: %s"):format(id, tostring(err)))
                    end
                end
            end
        end
    end

    sync_public_registry()
end

--- Starts a mod (and its dependencies first) in a realm.
--- @param name string
--- @param realm string "client" or "server"
--- @return boolean, string|nil ok, error
function m.start(name, realm)
    local mod = mods[name]

    if not mod then
        return false, "unknown mod"
    end

    if not REALMS[realm] then
        return false, "realm must be client or server"
    end

    if mod.state == "started" then
        return true
    end

    if mod.state == "starting" then
        return false, "dependency cycle"
    end

    mod.state = "starting"

    for _, dependency in ipairs(mod.manifest.depends) do
        local ok, err = m.start(dependency, realm)

        if not ok then
            return fail(mod, ("dependency '%s': %s"):format(dependency, tostring(err)))
        end
    end

    mod.realm = realm
    mod.handlers = {}

    local logger = _log.scoped(name)

    local ok, env, info = pcall(_sandbox.create_env, realm, "mod", m.config, {
        root = mod.dir,
        scope = { owner = name, root = mod.dir },
        globals = { mod = make_handle(mod) },
        print = function(...)
            logger.info(join_args(...))
        end,
    })

    if not ok then
        return fail(mod, env)
    end

    if not env then
        return fail(mod, info)
    end

    mod.env = env

    local files = {}

    for _, file in ipairs(mod.manifest.shared) do
        files[#files + 1] = file
    end

    for _, file in ipairs(mod.manifest[realm]) do
        files[#files + 1] = file
    end

    for _, file in ipairs(files) do
        local loaded, err = pcall(env.require, file_to_module(file))

        if not loaded then
            return fail(mod, err)
        end
    end

    mod.state = "started"
    mod.signature = signature_of(mod)

    sync_public_registry()
    log.success(("%s started (%s)"):format(name, realm))
    _event.fire("mod_started", name, realm)

    return true
end

--- Stops a mod. Mods that depend on it are stopped first.
--- @param name string
function m.stop(name)
    local mod = mods[name]

    if not mod or (mod.state ~= "started" and mod.state ~= "starting") then
        return
    end

    local dependents = {}

    for other_name, other in pairs(mods) do
        if other.state == "started" then
            for _, dependency in ipairs(other.manifest.depends) do
                if dependency == name then
                    dependents[#dependents + 1] = other_name
                end
            end
        end
    end

    table.sort(dependents)

    for _, other_name in ipairs(dependents) do
        m.stop(other_name)
    end

    teardown(mod)

    mod.state = "stopped"
    pending[name] = nil

    sync_public_registry()
    log.info(name .. " stopped")
    _event.fire("mod_stopped", name)
end

--- Stops a mod, re-reads its manifest and starts it again in the same realm.
--- @param name string
--- @return boolean, string|nil ok, error
function m.restart(name)
    local mod = mods[name]

    if not mod then
        return false, "unknown mod"
    end

    local realm = mod.realm or "client"
    m.stop(name)

    local manifest, err = read_manifest(name)

    if not manifest then
        mod.state = "failed"

        log.error(("%s: restart failed: %s"):format(name, tostring(err)))
        sync_public_registry()

        return false, err
    end

    mod.manifest = manifest

    return m.start(name, realm)
end

--- Starts every known mod in a realm.
--- @param realm string
function m.start_all(realm)
    for _, name in ipairs(sorted_names()) do
        m.start(name, realm)
    end
end

--- Stops every mod.
function m.stop_all()
    for _, name in ipairs(sorted_names(true)) do
        m.stop(name)
    end
end

--- Checks for changed files and reloads those mods.
--- A change must be seen on two polls in a row, so half-saved files are ignored.
function m.poll()
    local now = os.clock()

    if now - last_poll < POLL_INTERVAL then
        return
    end

    last_poll = now

    for _, name in ipairs(sorted_names()) do
        local mod = mods[name]

        if mod.state == "started" or mod.state == "failed" then
            if same_signature(signature_of(mod), mod.signature or {}) then
                pending[name] = nil
            elseif pending[name] then
                pending[name] = nil

                log.info(name .. ": files changed, reloading")
                m.restart(name)
            else
                pending[name] = true
            end
        end
    end
end

return m