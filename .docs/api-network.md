# Network API Reference

The Network API handles low-level and high-level networking over ENet, allowing games and mods to create servers, connect clients, and manage named reliable or unreliable communication channels.

---

## Hosts & Connections

Functions to initialize servers, connect clients, and manage network host instances.

### `modit.network.host(config)`

Starts listening for incoming client connections as a server host. Must be polled each frame to handle incoming messages and events.

* **Parameters:**
    * `config` (table): Server configuration options:
        * `port` (number): The port number to bind and listen on (required).
        * `max_peers` (number|nil): Maximum allowed peer connections (default: `32`).
        * `channels` (table|nil): Channel definition list containing channel metadata (`{ {name, reliable, raw}, ... }`).

* **Returns:**
    * `table|nil`: Host object handle, or `nil` on failure.
    * `string|nil`: Error message if initialization fails.

```lua
local server, err = modit.network.host({
    port = 7777,
    max_peers = 16,
    channels = {
        { name = "chat", reliable = true },
        { name = "position", reliable = false }
    }
})

if not server then
    print("Failed to start server:", err)
end
```

### `modit.network.connect(ip, port, config)`

Creates a client network host and initiates a connection to a target server IP address and port.

* **Parameters:**
    * `ip` (string): Target server hostname or IPv4 address.
    * `port` (number): Target server port.
    * `config` (table|nil): Optional channel configuration table matching the host channel layout.

* **Returns:**
    * `table|nil`: Host object handle, or `nil` on failure.
    * `number|string`: Connected peer ID handle on success, or error message on failure.

```lua
local client, peer_id = modit.network.connect("127.0.0.1", 7777, {
    channels = {
        { name = "chat", reliable = true },
        { name = "position", reliable = false }
    }
})

if not client then
    print("Connection failed:", peer_id)
end
```

### `modit.network.cleanup_hosts()`

Destroys and cleans up all active network host instances and connections.

```lua
modit.network.cleanup_hosts()
```

---

## Host Methods

Methods available on returned host handles.

### `host:poll()`

Polls events, incoming messages, and network state changes. Should be invoked once per frame tick.

```lua
local events = host:poll()
```

### `host:send(peer_id, channel_name, data)`

Sends a payload packet to a specific connected peer.

* **Parameters:**
    * `peer_id` (number): Target peer identifier.
    * `channel_name` (string): Name of the channel to transmit through.
    * `data` (string|table): Data payload to transmit.

```lua
host:send(peer_id, "chat", "Hello Peer!")
```

### `host:broadcast(channel_name, data)`

Broadcasts a payload packet to all connected peers.

* **Parameters:**
    * `channel_name` (string): Name of the channel to transmit through.
    * `data` (string|table): Data payload to transmit.

```lua
host:broadcast("position", { x = 100, y = 200 })
```