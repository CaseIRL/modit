--- @module sandbox
--- @file src/framework/core/sandbox.lua
--- @description Sandboxes game and mods.
--[[
    Notes:
    
    All API files should include metadata tags.

    At the top:

    --- @module [name] - Name used to expose the API module
    --- @default_access [engine | game | mod] - Sets the default access level for the file
    --- @default_realm [shared | client | server] - Sets which realm loads the file

    Per-function access can be set using:

    --- @access [engine | game | mod] - Sets the access level for the next function

    Files without the required module and realm metadata will be ignored.
    Functions without an access tag use the file's default access level.
]]

--- @file src/framework/core/sandbox.lua

local _fs = require("src.framework.core.filesystem")
local _utils = require("src.framework.core.utils")

--- @section Constants

local ROLE_RANK = { mod = 1, game = 2, engine = 3 }
local SAFE_GLOBALS = { "assert","error", "ipairs", "pairs", "next", "pcall", "xpcall", "select", "tonumber", "tostring", "type", "unpack", "setmetatable", "rawget", "rawset", "rawequal" }
local ALWAYS_ON = { window = true, log = true, json = true }
local OWNER_CLEANUP = { "remove_owner", "release_owner", "clear_owner_actions" }
local MANIFEST = { shared = {}, client = {}, server = {} }
local VALID_REALM = { shared = true, client = true, server = true }

--- @section Initialisation

local m = {}
local realm_cache = {}
local scanned = false

m.manifest = MANIFEST

local real_getmetatable = getmetatable

--- @section Helpers

--- Returns the permission rank number for a given role.
--- @param role string Role name (mod, game, engine)
--- @return number Rank integer
local function rank_of(role)
    local rank = ROLE_RANK[role]
    if not rank then
        error(("sandbox: unknown role '%s' (expected mod, game or engine)"):format(tostring(role)), 3)
    end
    return rank
end

--- Splits a code string into individual lines.
--- @param code string Source code
--- @return table Array of lines
local function split_lines(code)
    code = code:gsub("\194\160", " "):gsub("\r", "")
    local lines = {}
    for line in (code .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

--- Parses and finds the lowest role from an access spec.
--- @param spec string Access specification
--- @param where string Location string for error context
--- @return string Role name
local function lowest_role(spec, where)
    local best
    for token in spec:gmatch("[^,%s]+") do
        local rank = ROLE_RANK[token]
        if not rank then
            error(("sandbox: %s: unknown access role '%s'"):format(where, token), 0)
        end

        if not best or rank < ROLE_RANK[best] then
            best = token
        end
    end

    if not best then
        error(("sandbox: %s: empty @access tag"):format(where), 0)
    end

    return best
end

--- Parses metadata tags from source code.
--- @param code string Source code
--- @param source string Source path
--- @return table, table, string Members table, warnings array, default role
local function parse_metadata(code, source)
    local lines = split_lines(code)
    local members, warnings = {}, {}

    local module_name
    for i = #lines, 1, -1 do
        local name = lines[i]:match("^return%s+([%a_][%w_]*)%s*$")
        if name then
            module_name = name
            break
        end
    end

    local pending, pending_line, default_role

    local function warn(line_no, text)
        warnings[#warnings + 1] = ("%s:%d: %s"):format(source, line_no, text)
    end

    for i, line in ipairs(lines) do
        local where = source .. ":" .. i
        local default_spec = line:match("^%s*%-%-+%s*@default_access%s+(.-)%s*$")
        local access_spec = line:match("^%s*%-%-+%s*@access%s+(.-)%s*$")

        if default_spec then
            default_role = lowest_role(default_spec, where)
        elseif access_spec then
            if pending then
                warn(pending_line, "@access tag replaced before reaching a definition")
            end
            pending, pending_line = lowest_role(access_spec, where), i
        else
            local obj, key = line:match("^function%s+([%a_][%w_]*)[%.:]([%a_][%w_]*)")
            if not obj then
                local o, k, rest = line:match("^([%a_][%w_]*)%.([%a_][%w_]*)%s*=(.?)")
                if o and rest ~= "=" then
                    obj, key = o, k
                end
            end

            if obj and (not module_name or obj == module_name) then
                local role = pending or default_role
                members[key] = { role = role or "engine", tagged = role ~= nil, line = i }
                pending = nil
            elseif not line:match("^%s*%-%-") and not line:match("^%s*$") then
                if pending then
                    warn(pending_line, "@access tag not followed by a module member")
                end
                pending = nil
            end
        end
    end

    return members, warnings, default_role
end

--- Converts a file path into a standard module name.
--- @param path string File path
--- @return string Module name
local function module_name_of(path)
    return (path:gsub("%.lua$", ""):gsub("[/\\]", "."))
end

--- Reads a file from disk or bundle.
--- @param path string File path
--- @return string|nil File contents or nil
local function read_file(path)
    local bundle = rawget(_G, "MODIT_BUNDLE")
    if bundle then
        local normalized = path:gsub("\\", "/")
        local key = normalized:gsub("^%./", "")
        if bundle.has(key) then
            return bundle.get(key)
        end

        key = normalized:match(".*/(src/.-)$") or normalized:match(".*/(game/.-)$") or normalized:match("^(src/.-)$") or normalized:match("^(game/.-)$")
        if key and bundle.has(key) then
            return bundle.get(key)
        end
    end

    return _fs.read_file(path)
end

--- Lists a directory's direct children from the bundle if present, falling back to disk.
--- Needed because a packaged exe has no real src/api folder on disk - only MODIT_BUNDLE
--- knows about it - so scan_api's directory walk has to go through this, not _fs directly.
--- @param path string Directory path
--- @return table Array of full child paths
local function list_directory(path)
    local bundle = rawget(_G, "MODIT_BUNDLE")
    if bundle then
        local key = path:gsub("\\", "/"):gsub("^%./", ""):gsub("/+$", "")
        if bundle.is_dir(key) then
            return bundle.list(key)
        end
    end
    return _fs.list_directory(path)
end

--- Checks whether a directory exists in the bundle if present, falling back to disk.
--- @param path string Directory path
--- @return boolean
local function directory_exists(path)
    local bundle = rawget(_G, "MODIT_BUNDLE")
    if bundle then
        local key = path:gsub("\\", "/"):gsub("^%./", ""):gsub("/+$", "")
        if bundle.is_dir(key) then
            return true
        end
    end
    return _fs.directory_exists(path)
end

--- Reads the source code for a module from path.
--- @param path string File path
--- @return string Source code
local function read_source(path)
    local code = read_file(path)
    if code then return code end

    local rel = module_name_of(path):gsub("%.", "/")
    for template in package.path:gmatch("[^;]+") do
        local candidate = template:gsub("%?", function() return rel end)
        code = read_file(candidate)
        if code then
            return code
        end
    end
    error("sandbox: failed to open module source -> " .. tostring(path), 0)
end

--- Clears the manifest table sections.
local function clear_manifest()
    for _, section in pairs(MANIFEST) do
        for key in pairs(section) do
            section[key] = nil
        end
    end
end

--- Recursively collects all Lua files in a directory.
--- @param dir string Directory path
--- @param out table Output array
--- @return table Array of file paths
local function collect_lua_files(dir, out)
    local entries = {}
    for _, entry in ipairs(list_directory(dir) or {}) do
        if type(entry) == "string" then
            entries[#entries + 1] = entry
        end
    end
    table.sort(entries)

    for _, entry in ipairs(entries) do
        if entry:match("%.lua$") then
            out[#out + 1] = entry
        elseif directory_exists(entry) then
            collect_lua_files(entry, out)
        end
    end
    return out
end

--- Scans the API directory to build the manifest.
--- @param api_dir string|nil Optional API directory path
local function scan_api(api_dir)
    api_dir = api_dir or "src/api"
    scanned = true

    if not directory_exists(api_dir) then
        return
    end

    clear_manifest()

    for _, filepath in ipairs(collect_lua_files(api_dir, {})) do
        local code = read_file(filepath)
        if code then
            local module_name = code:match("%-%-%s*@module%s+api%.([%w_]+)")
            local realm = code:match("%-%-%s*@default_realm%s+(%w+)")

            if module_name and realm then
                if not VALID_REALM[realm] then
                    log("warn", ("%s: unknown @default_realm '%s' (module skipped)"):format(filepath, realm))
                else
                    local list = MANIFEST[realm][module_name]
                    if not list then
                        list = {}
                        MANIFEST[realm][module_name] = list
                    end
                    list[#list + 1] = filepath
                end
            end
        end
    end

    m.manifest = MANIFEST
end

--- Loads a module and its metadata.
--- @param mod_name string Module name
--- @param path_or_paths string|table File path or list of paths
--- @return table Module exports and metadata
local function load_module(mod_name, path_or_paths)
    local paths = type(path_or_paths) == "table" and path_or_paths or { path_or_paths }
    local exports, meta = {}, {}

    for _, path in ipairs(paths) do
        local members, warnings, default_role = parse_metadata(read_source(path), path)
        for _, w in ipairs(warnings)do
            log("warn", w)
        end

        local part = require(module_name_of(path))
        if type(part) ~= "table" then
            error(("sandbox: module '%s' (%s) must return a table"):format(mod_name, path), 0)
        end

        for key, value in pairs(part) do
            if exports[key] ~= nil then
                log("warn", ("%s: '%s.%s' overrides an export"):format(path, mod_name, key))
            end
            exports[key] = value
            meta[key] = members[key] or { role = default_role or "engine", tagged = default_role ~= nil }
        end
    end

    return { exports = exports, meta = meta }
end

--- Loads all modules for a given realm.
--- @param realm string Realm name (client, server)
--- @return table Loaded realm modules
local function load_realm(realm)
    if realm_cache[realm] then
        return realm_cache[realm]
    end

    if realm ~= "client" and realm ~= "server" then
        error(("sandbox: unknown realm '%s'"):format(tostring(realm)), 3)
    end

    if not scanned then
        scan_api()
    end

    local modules = {}
    local function batch(section)
        for name, paths in pairs(section) do
            assert(modules[name] == nil, "sandbox: duplicate module -> " .. tostring(name))
            modules[name] = load_module(name, paths)
        end
    end

    if MANIFEST.shared then
        batch(MANIFEST.shared)
    end

    if MANIFEST[realm] then
        batch(MANIFEST[realm])
    end

    realm_cache[realm] = modules
    return modules
end

--- Checks if a module is enabled.
--- @param name string Module name
--- @param enabled_map table|nil Map of enabled modules
--- @return boolean True if enabled
local function is_enabled(name, enabled_map)
    return ALWAYS_ON[name] or not enabled_map or enabled_map[name] == true
end

--- Builds a restricted view of a module based on rank.
--- @param mod table Module table
--- @param caller_rank number Caller rank integer
--- @return table Filtered view table
local function build_view(mod, caller_rank)
    local view = {}
    for key, value in pairs(mod.exports) do
        if caller_rank >= ROLE_RANK[mod.meta[key].role] then
            view[key] = value
        end
    end

    return view
end

--- Picks specified keys from a source table.
--- @param src table Source table
--- @param keys table Array of keys to pick
--- @return table New table with picked keys
local function pick(src, keys)
    local out = {}
    for _, k in ipairs(keys) do
        out[k] = src[k]
    end

    return out
end

--- Validates a module name string.
--- @param name any Name to validate
--- @return boolean True if valid
local function valid_module_name(name)
    if type(name) ~= "string" or name == "" then
        return false
    end

    for segment in (name .. "."):gmatch("([^%.]*)%.") do
        if not segment:match("^[%a_][%w_]*$") then
            return false
        end
    end

    return true
end

--- Compiles Lua source text into a chunk that runs in env. Rejects bytecode.
--- @param code string Source text
--- @param path string Used for error messages
--- @param env table Environment the chunk runs in
--- @return function|nil Chunk, or nil plus an error message
local function compile(code, path, env)
    if code:sub(1, 1) == "\27" then
        return nil, "bytecode is not allowed, only source"
    end
    
    local chunk, err = loadstring(code, "@" .. path)
    if not chunk then
        return nil, err
    end

    return setfenv(chunk, env)
end

--- Creates a sandboxed require function.
--- @param root string Root directory path
--- @param env table Environment table
--- @return function Require function
local function make_require(root, env)
    local loaded = {}
    local LOADING = {}

    return function(name)
        if not valid_module_name(name) then
            error(("require: invalid name '%s'"):format(tostring(name)), 2)
        end

        if loaded[name] == LOADING then
            error(("require: circular dependency on '%s'"):format(name), 2)
        end

        if loaded[name] ~= nil then
            return loaded[name]
        end

        local rel = name:gsub("%.", "/")
        local path, code
        for _, candidate in ipairs({ root .. "/" .. rel .. ".lua", root .. "/" .. rel .. "/init.lua" }) do
            code = read_file(candidate)
            if code then
                path = candidate
                break
            end
        end
        if not code then
            error(("require: module '%s' not found in project"):format(name), 2)
        end

        local chunk, err = compile(code, path, env)
        if not chunk then
            error(("require: failed to load '%s': %s"):format(name, err), 2)
        end

        loaded[name] = LOADING
        local result = chunk(name)
        if result == nil then
            result = true
        end
        loaded[name] = result

        return result
    end
end

--- Loads a project's config.lua in an empty environment (it is data only).
--- @param project_path string Project folder
--- @return table|nil Config, or nil plus an error message
local function load_config(project_path)
    local path = project_path .. "/config.lua"

    local code = read_file(path)
    if not code then
        return nil, "config.lua not found in '" .. project_path .. "'"
    end

    local chunk, err = compile(code, path, {})
    if not chunk then
        return nil, err
    end

    local ok, config = pcall(chunk)
    if not ok then
        return nil, tostring(config)
    end
    if type(config) ~= "table" then
        return nil, "config.lua must return a table"
    end

    return config
end

--- Loads each scene path in config.scenes through the sandboxed require.
--- @param config table Project config (config.scenes is replaced with loaded scenes)
--- @return boolean ok
--- @return string|nil error
local function load_scenes(config)
    local env, err = m.create_env("client", "game", config, { root = config.root })
    if not env then
        return false, err
    end

    for name, path in pairs(config.scenes or {}) do
        if type(path) == "string" then
            local ok, scene = pcall(env.require, path)
            if not ok then
                return false, ("scene '%s' (%s): %s"):format(name, path, tostring(scene))
            end
            config.scenes[name] = scene
        end
    end

    return true
end

--- @section Reset

--- Resets the sandbox cache and manifest state.
function m.reset()
    realm_cache = {}
    scanned = false
    clear_manifest()
    m.manifest = MANIFEST
end

--- @section Ownership

--- Releases an owner from all realm modules.
--- @param realm string Realm name
--- @param owner any Owner object/identifier
function m.release_owner(realm, owner)
    for name, mod in pairs(load_realm(realm)) do
        for _, fname in ipairs(OWNER_CLEANUP) do
            local fn = mod.exports[fname]
            if type(fn) == "function" then
                local ok, err = pcall(fn, owner)
                if not ok then
                    log("warn", ("%s.%s('%s') failed: %s"):format(name, fname, owner, tostring(err)))
                end
            end
        end
    end
end

--- @section ENV

--- Loads and builds environment modules for a realm and role.
--- @param realm string Realm name
--- @param role string Role name
--- @param opts table|nil Options table
--- @return table Module environment table
function m.load_env(realm, role, opts)
    local caller_rank = rank_of(role)
    local enabled_map = opts and opts.enabled
    local env = {}

    for name, mod in pairs(load_realm(realm)) do
        if is_enabled(name, enabled_map) then
            local view = build_view(mod, caller_rank)
            if next(view) ~= nil then
                env[name] = view
            end
        end
    end

    return env
end

--- Creates a secure execution environment.
--- @param role string Role name
--- @param modules table Modules table
--- @param opts table|nil Options table
--- @return table Environment table
function m.make_env(role, modules, opts)
    if role == "engine" then
        error("sandbox: engine runs unsandboxed", 2)
    end
    rank_of(role)
    opts = opts or {}

    local env = {}
    for _, name in ipairs(SAFE_GLOBALS) do
        env[name] = _G[name]
    end

    env.print = opts.print or print
    env.log = _G.log
    env.log_history = _G.log_history
    env.json = _G.json
    
    env.getmetatable = function(value)
        if type(value) == "string" then
            return nil
        end
        return real_getmetatable(value)
    end

    env.string = _utils.shallow_copy(string, { dump = true })
    env.table = _utils.shallow_copy(table)
    env.math = _utils.shallow_copy(math)
    env.coroutine = _utils.shallow_copy(coroutine)
    env.os = pick(os, { "time", "clock", "date", "difftime" })
    if bit then
        env.bit = _utils.shallow_copy(bit)
    end

    env._G = env
    env[opts.global_name or "modit"] = modules

    for key, value in pairs(opts.globals or {}) do
        env[key] = value
    end

    if opts.root then
        env.require = make_require(opts.root, env)
    end

    return env
end

--- Creates an environment and loaded modules configuration.
--- @param realm string Realm name
--- @param role string Role name
--- @param conf table Configuration table
--- @param opts table|nil Options table
--- @return table|nil, table|nil Environment and modules or error
function m.create_env(realm, role, conf, opts)
    opts = opts or {}
    conf = conf or {}

    if role == "mod" then
        local modding = conf.modding
        if type(modding) ~= "table" or modding.enabled ~= true then
            return nil, "modding is disabled"
        end
    end

    local enabled_modules = {}
    if conf.modules then
        for k, v in pairs(conf.modules) do
            if v == true then
                enabled_modules[k] = true
            end
        end
    end

    if role == "mod" and conf.modding and conf.modding.blacklisted_modules then
        local blacklisted = conf.modding.blacklisted_modules
        for i = 1, #blacklisted do
            enabled_modules[blacklisted[i]] = nil
        end
    end

    local modules = m.load_env(realm, role, { enabled = enabled_modules })

    if opts.scope then
        for name, mod in pairs(load_realm(realm)) do
            local scoped = mod.exports.scoped
            if type(scoped) == "function" and is_enabled(name, enabled_modules) then
                local api = scoped(opts.scope.owner, opts.scope.root)
                if type(api) == "table" then
                    if type(modules[name]) ~= "table" then
                        modules[name] = {}
                    end
                    for k, v in pairs(api) do
                        modules[name][k] = v
                    end
                end
            end
        end
    end

    for key, value in pairs(opts.extra or {}) do
        local existing = modules[key]
        if type(existing) == "table" and type(value) == "table" then
            for k, v in pairs(value) do
                existing[k] = v
            end
        else
            modules[key] = value
        end
    end

    return m.make_env(role, modules, opts), modules
end

--- @section Projects

--- Loads a project: reads its config and loads its scenes inside the sandbox.
--- @param project_path string Project folder
--- @return table|nil Config ready for Window.new, or nil plus an error message
function m.load_project(project_path)
    local config, err = load_config(project_path)
    if not config then
        return nil, err
    end

    config.root = project_path

    local ok, scene_err = load_scenes(config)
    if not ok then
        return nil, scene_err
    end

    return config
end

--- Loads a project for a headless server: reads its config and returns a sandboxed require for the server code.
--- Client scenes are never loaded.
--- @param project_path string Project folder
--- @return table|nil Config, or nil plus an error message
--- @return function|nil Sandboxed require rooted at the project (server/init.lua is required as "server")
function m.load_server(project_path)
    local config, err = load_config(project_path)
    if not config then
        return nil, err
    end

    config.root = project_path

    local env, modules = m.create_env("server", "game", config, {
        root = project_path,
        globals = { server_config = config.network or {} },
    })
    if not env then
        return nil, modules
    end

    return config, env.require
end

return m