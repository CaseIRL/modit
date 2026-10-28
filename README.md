# Modit SDK

A small lightweight game framework built with LuaJIT + Raylib + Box3D.

A lot of code for project has already been completed in a multitude of other builds and test projects.
However I have decided to go for a rebuild on this and just keep it focused to what I need to build games I want to make. 

I am planning to use the engine/sdk to make my own game, then when I come to game 2 if Modit needs anything adding it will be added then.
This is to try keep the project more focused into whats needed instead of building features because it sounds cool to build.

My first plan is a fps arena shooter multiplayer with mod support. 
That should give a large amount of features already.

## The Idea

- Build small, and build focused.
- OOP data-driven approach
- Optimised for luajit performance

## Features

- [x] Window Loading
- [x] Scenes
- [x] Modding Support: sandboxed loading, `exports()` & `modit.event`
- [x] Camera functions
- [x] Graphics registries: image, text, shapes
- [x] Layered render list
- [x] Graphics API: Covers what currently works, nothing more
- [x] Input controls: keyboard, mouse, gamepade & action bindings
- [x] Audio basic but works
- [] Physics: basic at first only need rigid bodies to explode
- [] Fps Controller 
- [] Networking
- [] Headless server support
- [] Ingame console

## License

Project is licensed under [MIT](https://github.com/CaseIRL/modit/blob/main/LICENSE)

You are free to use it to build your own projects just remember its focused around what I personally want. 