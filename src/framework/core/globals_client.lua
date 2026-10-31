--- @file src/framework/core/globals_client.lua
--- @description Handles initialising global functions nothing more

--- @section Logging

local log = require("src.framework.core.log")

_G.log = log.print
_G.log_history = log.log_history

--- @section JSON

_G.json = require("src.framework.core.json")

--- @section Registries

_G.render_list = require("src.framework.renderer.render_list").new()
_G.shapes_registry = require("src.framework.renderer.shapes_registry").new()
_G.text_registry = require("src.framework.renderer.text_registry").new()
_G.image_registry = require("src.framework.renderer.image_registry").new()
_G.model_registry = require("src.framework.renderer.model_registry").new()
_G.shader_registry = require("src.framework.renderer.shader_registry").new()
_G.environment = require("src.framework.renderer.environment").new()

_G.audio_registry = require("src.framework.audio.audio_registry").new()

--- @section Game Console

_G.console = require("src.framework.renderer.console").new()