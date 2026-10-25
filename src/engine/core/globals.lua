--- @file src/engine/globals.lua
--- @description Handles initialising global functions nothing more

--- @section Logging

local log = require("src.engine.core.log")

_G.log = log.print
_G.log_history = log.log_history