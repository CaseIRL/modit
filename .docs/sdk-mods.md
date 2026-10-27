# Mods SDK Reference

The Mods SDK handles cross-mod communication via exports and provides utility functions to query loaded mods.

---

## Exports

Expose functions from your mod for other mods to call, or invoke functions exposed by other active mods.

### `exports(name, fn)`

Registers an export function for your mod.

* **Parameters:**
    * `name` (string): The function name to export.
    * `fn` (function): The implementation function.

```lua
exports("get_score", function()
    return 42
end)
```

### `exports.mod_name.function_name(...)`

Calls an exported function from another target mod provider.

```lua
local score = exports.my_other_mod.get_score()
```

---

## Mod Queries

Check status and metadata of active mods in the engine.

### `mods.list()`

Returns a sorted list of all currently registered mods.

* **Returns:**
    * `table`: Array of mod info tables containing `name`, `version`, `author`, `realm`, and `state`.

```lua
for _, m in ipairs(mods.list()) do
    print(m.name, m.version)
end
```

### `mods.is_loaded(name)`

Checks if a specific mod is loaded and running (`"started"`).

* **Parameters:**
        * `name` (string): Target mod name.

* **Returns:**
    * `boolean`: `true` if active, otherwise `false`.

```lua
if mods.is_loaded("chat_system") then
    print("Chat system mod is running!")
end
```