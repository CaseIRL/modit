--- @file src/framework/core/globals_shared.lua
--- @description Handles initialising global functions nothing more

--- @section Logging

local log = require("src.framework.core.log")

_G.log = log.print
_G.log_history = log.log_history

--- @section JSON

_G.json = require("src.framework.core.json")

--- @section Registries

_G.physics_registry = require("src.framework.physics.physics_registry").new()

_G.network_registry = require("src.framework.network.network_registry").new()