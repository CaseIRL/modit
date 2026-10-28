--- @file src/core/globals.lua
--- @description Handles initialising global functions nothing more

--- @section Logging

local log = require("src.core.log")

_G.log = log.print
_G.log_history = log.log_history

--- @section JSON

_G.json = require("src.core.json")

--- @section Registries

_G.render_list = require("src.renderer.render_list").new()
_G.shapes_registry = require("src.renderer.shapes_registry").new()
_G.text_registry = require("src.renderer.text_registry").new()
_G.image_registry = require("src.renderer.image_registry").new()
_G.model_registry = require("src.renderer.model_registry").new()
_G.shader_registry = require("src.renderer.shader_registry").new()
_G.environment = require("src.renderer.environment").new()

_G.audio_registry = require("src.audio.audio_registry").new()
