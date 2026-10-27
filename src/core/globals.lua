--- @file src/core/globals.lua
--- @description Handles initialising global functions nothing more

--- @section Logging

local log = require("src.core.log")

_G.log = log.print
_G.log_history = log.log_history

--- @section JSON

_G.json = require("src.core.json")

--- @section Registries

local RenderList = require("src.renderer.render_list")
_G.render_list = RenderList.new()

local ShapesRegistry = require("src.renderer.shapes_registry")
_G.shapes_registry = ShapesRegistry.new()

local TextRegistry = require("src.renderer.text_registry")
_G.text_registry = TextRegistry.new()

local ImageRegistry = require("src.renderer.image_registry")
_G.image_registry = ImageRegistry.new()

local AudioRegistry = require("src.audio.audio_registry")
_G.audio_registry = AudioRegistry.new()
