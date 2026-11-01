# Building Projects

How to package a modit project into a standalone `.exe` using `build.lua`.

## Usage

From the repo root:

```
luajit build.lua <project> [options]
```

Example:

```
luajit build.lua projects/fps_game --target client
luajit build.lua projects/fps_game --target server
```

## Options

| Flag | Description |
|---|---|
| `--target <client\|server>` | Build target (default: `client`) |
| `--name <name>` | Executable name (default: project folder name) |
| `--out <folder>` | Output folder (default: `<project>/build/<name>`) |
| `--console` | Keep the terminal attached (default: windowed, output goes to `game_output.log`) |
| `--no-console` | Hide the console window explicitly |
| `--bytecode` | Embed engine code as LuaJIT bytecode (project code and `src/api` always stay source) |
| `--no-mods` | Don't copy the project's `mods` folder |
| `--loose-assets` | Copy `assets/` next to the exe instead of embedding them |
| `--rebuild-stub` | Recompile the launcher stub (needs VS C++ tools) |
| `--stub <path>` | Use a specific launcher stub instead of the cached one |
| `--log <file>` | Also write build output to a file |

## Requirements

- **Windows**, for now.
- **First build only:** compiling the launcher stub needs Visual Studio's C++ Build Tools (`cl.exe`, found via `vcvars64.bat`), plus LuaJIT's `lua.h` and a matching `.lib`. Point the compiler at them with `LUA_INCLUDE` / `LUA_LIB` env vars if they're not in the default locations. Once built, the stub is cached at `src/bin/modit_stub.exe` and reused — you won't need the compiler again unless you pass `--rebuild-stub`.
- **Runtime DLLs** must exist under `vendor/windows/`, `vendor/<name>/`, or `vendor/`: `luajit.dll`, `box3d.dll`, `enet.dll` for both targets, plus `raylib.dll` for client builds.

## Project requirements

- Every project needs a `config.lua` at its root.
- A **server** build additionally needs `server/init.lua` (the project's `require("server")` entry point `load`, `update(dt)`, `quit`, called as plain functions, not methods).

## Client vs server builds

- **Client** builds embed the project's `assets/` folder and copy `raylib.dll` alongside the other runtime DLLs.
- **Server** builds skip `assets/` entirely and leave out client-only engine code (renderer, audio, input, the raylib binding, `globals_client.lua`) so nothing can accidentally pull in raylib. They don't get `raylib.dll` copied either.

## Output

The built exe (and copied DLLs, icon, and any non-embedded project files) land in `<project>/build/<name>/`, or wherever `--out` points.

An empty `mods/` folder is created next to the exe automatically whenever the project's `config.lua` has `modding.enabled = true` — there's no build flag to opt in, it just follows the config:

```lua
modding = {
    enabled = true, -- mods/ gets created next to the built exe
    blacklisted_modules = {
        -- "audio"
    }
},
```

`--no-mods` is the only flag involved, and it only opts *out* use it to skip creating `mods/` even when `modding.enabled` is true.