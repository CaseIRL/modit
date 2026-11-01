--- @module bindings.enet
--- @file src/framework/bindings/enet.lua
--- @description LuaJIT FFI bindings for ENet 1.3.x (reliable and unreliable UDP).

--- @section Imports

local _ffi = require("ffi")

--- @section FFI

_ffi.cdef[[
    typedef struct _ENetHost ENetHost;
    typedef struct _ENetPeer ENetPeer;

    typedef struct { uint32_t host; uint16_t port; } ENetAddress;

    typedef struct {
        size_t   referenceCount;
        uint32_t flags;
        uint8_t *data;
        size_t   dataLength;
        void    *freeCallback;
        void    *userData;
    } ENetPacket;

    typedef struct {
        int          type;
        ENetPeer    *peer;
        uint8_t      channelID;
        uint32_t     data;
        ENetPacket  *packet;
    } ENetEvent;

    int         enet_initialize(void);
    void        enet_deinitialize(void);

    int         enet_address_set_host(ENetAddress *address, const char *hostName);

    ENetHost   *enet_host_create(const ENetAddress *address, size_t peerCount, size_t channelLimit, uint32_t incomingBandwidth, uint32_t outgoingBandwidth);
    void        enet_host_destroy(ENetHost *host);
    ENetPeer   *enet_host_connect(ENetHost *host, const ENetAddress *address, size_t channelCount, uint32_t data);
    int         enet_host_service(ENetHost *host, ENetEvent *event, uint32_t timeout);
    void        enet_host_flush(ENetHost *host);
    void        enet_host_broadcast(ENetHost *host, uint8_t channelID, ENetPacket *packet);

    ENetPacket *enet_packet_create(const void *data, size_t dataLength, uint32_t flags);
    void        enet_packet_destroy(ENetPacket *packet);

    int         enet_peer_send(ENetPeer *peer, uint8_t channelID, ENetPacket *packet);
    void        enet_peer_disconnect(ENetPeer *peer, uint32_t data);
    void        enet_peer_disconnect_now(ENetPeer *peer, uint32_t data);
    void        enet_peer_reset(ENetPeer *peer);
    void        enet_peer_timeout(ENetPeer *peer, uint32_t limit, uint32_t minimum, uint32_t maximum);
]]

--- @section Library

local ok, lib = pcall(_ffi.load, "vendor/enet/enet.dll")
if not ok then
    local err = lib
    ok, lib = pcall(_ffi.load, "enet")
    if not ok then
        error("enet library not found (enet.dll / libenet.so next to the executable): " .. tostring(err) .. "\n" .. tostring(lib), 0)
    end
end

--- @section Constants

return {
    lib = lib,

    EVENT_NONE = 0,
    EVENT_CONNECT = 1,
    EVENT_DISCONNECT = 2,
    EVENT_RECEIVE = 3,
    EVENT_DISCONNECT_TIMEOUT = 4,

    FLAG_RELIABLE = 1,
    FLAG_UNSEQUENCED = 2,
}