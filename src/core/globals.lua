--- @file src/core/globals.lua
--- @description Handles initialising global functions nothing more

--- @section Logging

local log = require("src.core.log")

_G.log = log.print
_G.log_history = log.log_history

--- @section JSON

_G.json = require("src.core.json")

--- @section Registries

local ShapesRegistry = require("src.graphics.shapes_registry")
_G.shapes_registry = ShapesRegistry.new()

local TextRegistry = require("src.graphics.text_registry")
_G.text_registry = TextRegistry.new()

local ImageRegistry = require("src.graphics.image_registry")
_G.image_registry = ImageRegistry.new()

local DrawList = require("src.graphics.draw_list")
_G.draw_list = DrawList.new()
