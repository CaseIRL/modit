# Event SDK Reference

The Event SDK provides an extension and messaging system, allowing games to register, listen to, fire, and manage custom events.

---

## Event Management

Functions to register, subscribe to, trigger, and clean up events.

### `modit.event.register(name, description, owner)`

Registers a new available event type.

* **Parameters:**
    * `name` (string): Event identifier.
    * `description` (string|nil): Optional description of the event.
    * `owner` (string|nil): Optional owner namespace.

```lua
modit.event.register("player_spawned", "Fires when a player spawns into the world")
```

### `modit.event.listen(name, callback, owner)`

Subscribes a callback function to an event.

* **Parameters:**
    * `name` (string): Event identifier.
    * `callback` (function): Callback handler function.
    * `owner` (string|nil): Optional owner namespace.

* **Returns:**
    * `function`: The callback handler.

```lua
modit.event.listen("player_spawned", function(player_id)
    print("Player spawned:", player_id)
end)
```

### `modit.event.fire(name, ...)`

Fires an event, invoking all registered listener callbacks.

* **Parameters:**
    * `name` (string): Event identifier.
    * `...` (any): Arguments passed through to listeners.

```lua
modit.event.fire("player_spawned", 42)
```

### `modit.event.unlisten(name, callback, owner)`

Unsubscribes a callback function from an event.

* **Parameters:**
    * `name` (string): Event identifier.
    * `callback` (function): The callback handler to remove.
    * `owner` (string|nil): Optional owner namespace filter.

```lua
modit.event.unlisten("player_spawned", my_callback)
```

### `modit.event.clear(name)`

Clears all listeners for a specific event.

* **Parameters:**
    * `name` (string): Event identifier.

```lua
modit.event.clear("player_spawned")
```

### `modit.event.list()`

Lists all available registered event names.

* **Returns:**
    * `table`: Sorted array of event name strings.

```lua
for _, name in ipairs(modit.event.list()) do
    print("Registered event:", name)
end
```

---

## Scoped Events

Create namespaced event APIs bound to a specific mod owner.

### `modit.event.scoped(owner)`

Creates a scoped event API table for a given owner namespace.

* **Parameters:**
    * `owner` (string): Non-empty owner namespace string (must not contain `.`).

* **Returns:**
    * `table`: Scoped event API (`register`, `listen`, `unlisten`, `fire`, `list`).

```lua
local my_events = modit.event.scoped("my_mod")

my_events.register("my_mod.custom_event", "A custom scoped event")

my_events.listen("my_mod.custom_event", function()
    print("Scoped event triggered!")
end)

my_events.fire("my_mod.custom_event")
```
