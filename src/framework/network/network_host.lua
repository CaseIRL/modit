--- @module network_host
--- @file src/framework/network/network_host.lua
--- @description Basic single Enet host.

--- @section Imports

local _ffi = require("ffi")
local _enet = require("src.framework.bindings.enet")
local _serializer = require("src.framework.network.serializer")
local _log = require("src.framework.core.log")

--- @section Constants

local C = _enet.lib
local MAX_PACKET_SIZE = 1024 * 1024
local DEFAULT_PEERS = 32
local DEFAULT_CHANNELS = {
    { name = "events", reliable = true },
    { name = "state",  reliable = false, raw = true },
}

--- @section Initialisation

local Host = {}
Host.__index = Host

local module = {}

--- @section Helpers

local function ptr_key(peer)
    return tonumber(_ffi.cast("uintptr_t", peer))
end

local function build_channels(spec)
    local list, by_name = {}, {}

    for index, channel in ipairs(spec or DEFAULT_CHANNELS) do
        list[index] = channel
        by_name[channel.name] = index - 1
    end

    return list, by_name
end

function Host:register_peer(peer)
    local id = self.next_peer_id
    self.next_peer_id = id + 1

    self.peers[id] = { ptr = peer, key = ptr_key(peer), kicked = false }
    self.by_ptr[ptr_key(peer)] = id

    return id
end

function Host:resolve_channel(channel)
    local index = type(channel) == "string" and self.channel_index[channel] or channel
    local def = index and self.channels[index + 1]

    if not def then return nil, "unknown channel '" .. tostring(channel) .. "'" end

    return index, def
end

function Host:encode(def, value)
    if def.raw then
        if type(value) ~= "string" then return nil, "raw channels need a string" end
        return value
    end

    return _serializer.encode(value)
end

function Host:make_packet(def, data)
    local flags = def.reliable and _enet.FLAG_RELIABLE or 0
    local packet = C.enet_packet_create(data, #data, flags)

    if packet == nil then return nil, "out of memory" end
    return packet
end

--- @section Functions

--- Creates a host
--- @param opts table|nil { port = number|nil (nil = client only), max_peers = number, channels = table, in_bandwidth = number, out_bandwidth = number }
--- @return table|nil host
--- @return string|nil error
function module.new(opts)
    opts = opts or {}

    local channels, channel_index = build_channels(opts.channels)

    local address = nil
    if opts.port then
        address = _ffi.new("ENetAddress")
        address.host = 0 -- ENET_HOST_ANY
        address.port = opts.port
    end

    local handle = C.enet_host_create(
        address,
        opts.max_peers or (opts.port and DEFAULT_PEERS or 1),
        #channels,
        opts.in_bandwidth or 0,
        opts.out_bandwidth or 0
    )

    if handle == nil then
        return nil, opts.port and ("could not bind port " .. opts.port) or "could not create client host"
    end

    return setmetatable({
        handle = handle,
        event = _ffi.new("ENetEvent"),
        channels = channels,
        channel_index = channel_index,
        peers = {},
        by_ptr = {},
        next_peer_id = 1,
        destroyed = false,
    }, Host)
end

--- Starts connecting to a server. The connect event arrives later from poll
--- @param ip string Hostname or IPv4
--- @param port number Server port
--- @return number|nil peer_id
--- @return string|nil error
function Host:connect(ip, port)
    local address = _ffi.new("ENetAddress")

    if C.enet_address_set_host(address, ip) ~= 0 then
        return nil, "could not resolve '" .. tostring(ip) .. "'"
    end
    address.port = port

    local peer = C.enet_host_connect(self.handle, address, #self.channels, 0)
    if peer == nil then return nil, "no free peer slots" end

    return self:register_peer(peer)
end

--- Sends a value to one peer
--- @param peer_id number Peer id
--- @param channel string|number Channel name or 0-based index
--- @param value any Lua value (string for raw channels)
--- @return boolean ok
--- @return string|nil error
function Host:send(peer_id, channel, value)
    local peer = self.peers[peer_id]
    if not peer then return false, "unknown peer" end

    local index, def = self:resolve_channel(channel)
    if not index then return false, def end

    local data, err = self:encode(def, value)
    if not data then return false, err end

    local packet, perr = self:make_packet(def, data)
    if not packet then return false, perr end

    if C.enet_peer_send(peer.ptr, index, packet) < 0 then
        C.enet_packet_destroy(packet)
        return false, "send failed"
    end

    return true
end

--- Sends a value to every connected peer
--- @param channel string|number Channel name or index
--- @param value any Lua value (string for raw channels)
--- @return boolean ok
--- @return string|nil error
function Host:broadcast(channel, value)
    local index, def = self:resolve_channel(channel)
    if not index then return false, def end

    local data, err = self:encode(def, value)
    if not data then return false, err end

    local packet, perr = self:make_packet(def, data)
    if not packet then return false, perr end

    C.enet_host_broadcast(self.handle, index, packet) -- ENet owns the packet now
    return true
end

--- Gracefully disconnects a peer. A disconnect event follows from poll
--- @param peer_id number Peer id
--- @param code number|nil Reason code sent to the other side
function Host:disconnect(peer_id, code)
    local peer = self.peers[peer_id]
    if not peer then return end

    peer.kicked = true
    C.enet_peer_disconnect(peer.ptr, code or 0)
end

--- Sends queued packets immediately instead of waiting for the next service call
function Host:flush()
    C.enet_host_flush(self.handle)
end

--- Services the host without blocking and returns everything that happened
--- @return table events Array of { type = "connect"|"disconnect"|"message", peer = id, channel = name, data = value, code = number }
function Host:poll()
    local events = {}
    if self.destroyed then return events end

    local event = self.event

    while C.enet_host_service(self.handle, event, 0) > 0 do
        local kind = event.type

        if kind == _enet.EVENT_CONNECT then
            local id = self.by_ptr[ptr_key(event.peer)] or self:register_peer(event.peer)
            events[#events + 1] = { type = "connect", peer = id }

        elseif kind == _enet.EVENT_DISCONNECT or kind == _enet.EVENT_DISCONNECT_TIMEOUT then
            local key = ptr_key(event.peer)
            local id = self.by_ptr[key]

            if id then
                events[#events + 1] = {
                    type = "disconnect",
                    peer = id,
                    code = tonumber(event.data),
                    timed_out = kind == _enet.EVENT_DISCONNECT_TIMEOUT,
                }
                self.peers[id] = nil
                self.by_ptr[key] = nil
            end

        elseif kind == _enet.EVENT_RECEIVE then
            self:handle_receive(event, events)
        end
    end

    return events
end

function Host:handle_receive(event, events)
    local packet = event.packet
    local id = self.by_ptr[ptr_key(event.peer)]
    local peer = id and self.peers[id]
    local def = self.channels[event.channelID + 1]

    local size = tonumber(packet.dataLength)

    if peer and not peer.kicked and def and size <= MAX_PACKET_SIZE then
        local bytes = _ffi.string(packet.data, size)
        local value, err = bytes

        if not def.raw then
            value, err = _serializer.decode(bytes)
        end

        if err then
            _log.warn(("peer %d sent a malformed packet (%s), disconnecting"):format(id, err))
            self:disconnect(id)
        else
            events[#events + 1] = { type = "message", peer = id, channel = def.name, data = value }
        end
    elseif peer and not peer.kicked then
        _log.warn(("peer %d sent an invalid packet, disconnecting"):format(id))
        self:disconnect(id)
    end

    C.enet_packet_destroy(packet)
end

--- Disconnects everyone and frees the host
function Host:destroy()
    if self.destroyed then return end
    self.destroyed = true

    for _, peer in pairs(self.peers) do
        C.enet_peer_disconnect_now(peer.ptr, 0)
    end

    C.enet_host_flush(self.handle)
    C.enet_host_destroy(self.handle)

    self.peers, self.by_ptr = {}, {}
end

return module