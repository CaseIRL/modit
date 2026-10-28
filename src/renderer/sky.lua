--- @module sky
--- @file src/renderer/sky.lua
--- @description Sky backdrop: vertical gradient above the horizon, solid colour below.

--- @section Imports

local _raylib = require("src.bindings.raylib")
local _ffi = _raylib.ffi
local _rl = _raylib.lib

--- @section Initialisation

local m = {}

local top_colour = _ffi.new("Color", 0, 0, 0, 255)
local horizon_colour = _ffi.new("Color", 0, 0, 0, 255)

--- @section Functions

--- Draws the sky over the whole target. Call before the camera mode begins.
--- @param width number Target width in pixels
--- @param height number Target height in pixels
--- @param horizon_y number Horizon Y in pixels (0 to height)
--- @param top table { r, g, b } 0-255
--- @param horizon table { r, g, b } 0-255
function m.draw(width, height, horizon_y, top, horizon)
    top_colour.r, top_colour.g, top_colour.b = top.r, top.g, top.b
    horizon_colour.r, horizon_colour.g, horizon_colour.b = horizon.r, horizon.g, horizon.b

    horizon_y = math.floor(horizon_y)
    if horizon_y > 0 then
        _rl.DrawRectangleGradientV(0, 0, width, horizon_y, top_colour, horizon_colour)
    end
    if horizon_y < height then
        _rl.DrawRectangle(0, horizon_y, width, height - horizon_y, horizon_colour)
    end
end

return m