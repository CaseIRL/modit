# Command SDK Reference

The Command SDK provides methods for registering, scoping, and managing console commands.

---

## Command Registration

Functions to register commands for games and mods.

### `modit.command.register(opts)`

Registers a new command using an options table.

* **Parameters:**
    * `opts` (table): Command options table containing:
        * `name` (string): Command identifier used to execute it.
        * `handler` (function): Callback function executed when the command is called.
        * `help` (string|nil): Optional description and usage information.
        * `args` (table|nil): Optional list or description of expected arguments.

```lua
modit.command.register({
    name = "teleport",
    help = "Teleports the player to coordinates",
    handler = function(x, y, z)
        print("Teleporting to:", x, y, z)
    end
})
```

---

## Scoped Commands

Create namespaced command APIs bound to a specific mod owner.

### `modit.command.scoped(owner)`

Creates a scoped command API table for a given owner namespace. Commands registered via scoped instances automatically append the mod's owner tag.

* **Parameters:**
    * `owner` (string): Mod owner namespace.

* **Returns:**
    * `table`: Scoped command API (`register`).

```lua
local my_commands = modit.command.scoped("my_mod")

my_commands.register({
    name = "give_coins",
    help = "Gives coins to the player",
    handler = function(amount)
        print("Gave coins:", amount)
    end
})
```

---

## Command Cleanup

Functions to clean up registered commands when unbinding or unloading mods.

### `modit.command.remove_owner(owner)`

Removes every command registered by a specific owner namespace.

* **Parameters:**
    * `owner` (string): Mod owner namespace.

```lua
modit.command.remove_owner("my_mod")
```