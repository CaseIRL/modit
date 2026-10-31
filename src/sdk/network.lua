--- @module sdk.network
--- @file src/sdk/network.lua
--- @description Networking: servers and clients over ENet, with named reliable and unreliable channels.
--- @default_access game
--- @default_realm shared

--- @section Initialisation

local m = {}

local function get_registry()
    if not _G.network_registry then
        log("warn", "NetworkRegistry not initialized")
        return nil
    end
    return _G.network_registry
end

--- @section Hosts

--- Starts listening for clients. Poll it once per tick, then send with host:send / host:broadcast.
--- @param config table|nil { port = number, max_peers = 32, channels = { {name, reliable, raw}, ... } }
--- @return table|nil Host
--- @return string|nil error
function m.host(config)
    local registry = get_registry()
    if not registry then return nil end

    config = config or {}
    if not config.port then return nil, "network.host needs a port" end

    return registry:add(config)
end

--- Creates a client and begins connecting. The connect event arrives from host:poll().
--- @param ip string Hostname or IPv4
--- @param port number Server port
--- @param config table|nil Same channel config as the server
--- @return table|nil Host
--- @return number|string peer_id, or error message when Host is nil
function m.connect(ip, port, config)
    local registry = get_registry()
    if not registry then return nil end

    config = config or {}
    config.port = nil -- clients never bind

    local host, err = registry:add(config)
    if not host then return nil, err end

    local peer, connect_err = host:connect(ip, port)
    if not peer then return nil, connect_err end

    return host, peer
end

--- Destroys every host. Called automatically on shutdown.
function m.cleanup_hosts()
    local registry = get_registry()
    if registry then registry:cleanup() end
end

return m