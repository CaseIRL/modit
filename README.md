# MODIT

![Status](https://img.shields.io/badge/Status-Alpha-e4ad29?style=flat-square&labelColor=0E0E0E)
![Platforms](https://img.shields.io/badge/Platforms-Windows-green?style=flat-square&labelColor=0E0E0E)
![Language](https://img.shields.io/badge/Language-LuaJIT-blue?style=flat-square&labelColor=0E0E0E)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square&labelColor=0E0E0E)

<a href="https://modit.dev"><img src="https://img.shields.io/badge/🌐_Website-modit.dev-4dcbc2?style=for-the-badge&logoColor=white" alt="Website" /></a>
<a href="https://discord.gg/QQ7yarSE5U"><img src="https://img.shields.io/badge/_Discord-Join-4dcbc2?style=for-the-badge&logo=discord&logoColor=white" alt="Discord" /></a>
<a href="https://ko-fi.com/case"><img src="https://img.shields.io/badge/_Ko--fi-Support-4dcbc2?style=for-the-badge&logo=kofi&logoColor=white" alt="Ko-fi" /></a>

## About MODIT

MODIT is a lightweight, code-first 2D and 3D game framework built with **LuaJIT, Raylib, Box3D and Enet**.

Designed from the ground up for moddable games, MODIT focuses on providing the core systems needed to build games while keeping the framework small, flexible and easy to work with.

Rather than becoming an all-purpose game engine, MODIT aims to stay focused on practical features and give developers control over how their games are built.

## Getting Started

Every MODIT game requires a configuration file and at least one scene. The configuration defines your project and registers its scenes, while scenes contain your game's logic.

### Project Configuration

A minimal example of a project configuration:

```lua
return {
    title = "My Game",
    width = 1280,
    height = 720,

    scene = "main",
    scenes = {
        main = "scenes.main"
    },

    modules = {
        input = true,
        graphics = true
    }
}
```

### Scene

Create a scene at the path registered in your configuration. For the example above, that would be `scenes/main.lua`.

```lua
local scene = {}

function scene:load()

end

function scene:update(dt)

end

function scene:frame()

end

function scene:unload()

end

return scene
```

These examples are intentionally minimal. MODIT provides additional configuration options and APIs for graphics, input, audio, modding and other game systems.

## Why MODIT?

I wanted to make my own moddable games in Lua, and building the framework around that idea sounded fun.

The goal is to keep MODIT entirely in Lua, relying on external libraries only where needed through FFI.

I'm aware that this approach could introduce performance bottlenecks down the road, particularly with Raylib's immediate-mode rendering running on a single Lua thread. However, I don't expect to make games that push those limits. If that changes, I'll look into alternatives when the need arises.

MODIT isn't intended to compete with large, feature-heavy engines.

It's a framework for building the games I want to make, with enough flexibility to grow when those games demand it.

The first game will help establish what the framework needs to be. Anything beyond that can wait until there's a reason to build it.

The plans simple:

**Build what is needed. Keep it focused. Let the games drive the framework.**

## Core Ideas

- **Small and focused** - Avoid unnecessary systems and features.
- **Code-first** - Keep development straightforward and give developers control.
- **Data-driven and object-oriented** - Build systems around reusable data and objects.
- **LuaJIT performance** - Use LuaJIT as the scripting foundation, keeping performance in mind.
- **Mod-first design** - Treat modding as a core part of the framework, not an afterthought.
- **Practical development** - Prioritise features that solve actual problems during game development.

## Built Around Lua

Lua is at the centre of MODIT's development workflow.

With LuaJIT providing the scripting runtime, the aim is to make game logic easy to write, extend and modify.

The framework is designed with modding in mind, including sandboxed mod loading, exports and an event system. This gives games built with MODIT a foundation for exposing functionality to mods without giving them unrestricted access to everything.

## Contributions

I'm not currently looking for contributions, as MODIT is primarily a personal project built around making my own games.

That said, I'm a big supporter of open source. You're more than welcome to fork the project, experiment with it, and make it your own.

## License & Credits

MODIT is released under the [MIT License](https://github.com/CaseIRL/modit/blob/main/LICENSE).

You're free to use MODIT in your own projects, modify it and build on top of it.

Just keep in mind that the framework is intentionally focused around my own development needs. It may not aim to support every workflow or feature you might expect from a general-purpose engine.

### Third-Party Libraries & Tech

* **[raylib](https://raylib.com)** (zlib License) - Copyright (c) 2013-2026 Ramon Santamaria (@raysan5)
* **[LuaJIT](https://luajit.org)** (MIT License) - Copyright (c) 2005-2026 Mike Pall
* **[Box3D](https://box2d.org)** (MIT License) - Copyright (c) 2026 Erin Catto
* **[Enet](http://enet.bespin.org)** (MIT License) - Copyright (c) 2002-2024 Lee Salzman
