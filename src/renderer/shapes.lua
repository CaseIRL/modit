--- @module shapes
--- @file src/renderer/shapes.lua
--- @description Handles 2D shapes, does not cover everything supplied by raylib but does most.

--- @section Imports

local _raylib = require("src.bindings.raylib")
local _ffi = _raylib.ffi
local _rl = _raylib.lib

--- @section Initialisation

local m = {}

local colours = {
    white = _ffi.new("Color", 255, 255, 255, 255),
    black = _ffi.new("Color", 0, 0, 0, 255),
    red = _ffi.new("Color", 230, 41, 55, 255),
    green = _ffi.new("Color", 0, 228, 48, 255),
    blue = _ffi.new("Color", 0, 121, 241, 255),
    yellow = _ffi.new("Color", 253, 249, 0, 255),
    gray = _ffi.new("Color", 130, 130, 130, 255),
    blank = _ffi.new("Color", 0, 0, 0, 0),
}

--- @section Helpers

--- Helper to convert a Lua table of coordinate tables into an FFI Vector2 array.
--- @param points table
--- @param count number
--- @return cdata
local function resolve_vector_array(points, count)
    local arr = _ffi.new("Vector2[?]", count)
    for i = 1, count do
        local p = points[i]
        if type(p) == "table" then
            arr[i - 1].x = p.x or p[1] or 0
            arr[i - 1].y = p.y or p[2] or 0
        elseif _ffi.istype("Vector2", p) then
            arr[i - 1] = p
        end
    end
    return arr
end

--- Resolves a colour input into a native FFI Color.
--- @param c string|table|cdata
--- @return cdata
local function resolve_colour(c)
    if type(c) == "string" then
        return colours[c] or colours.white
    elseif type(c) == "table" then
        return _ffi.new("Color", c[1] or 255, c[2] or 255, c[3] or 255, c[4] or 255)
    end
    return c
end

--- Helper to convert a Lua table into a native FFI Vector2.
--- @param v table|cdata
--- @return cdata
local function resolve_vector2(v)
    if type(v) == "table" then
        return _ffi.new("Vector2", v.x or v[1] or 0, v.y or v[2] or 0)
    end
    return v
end

--- Helper to convert a Lua table into a native FFI Rectangle.
--- @param r table|cdata
--- @return cdata
local function resolve_rectangle(r)
    if type(r) == "table" then
        return _ffi.new("Rectangle", r.x or r[1] or 0, r.y or r[2] or 0, r.width or r[3] or 0, r.height or r[4] or 0)
    end
    return r
end

--- @section Basic Shapes & Pixels

--- Draw a pixel using geometry.
--- @param pos_x number
--- @param pos_y number
--- @param colour string|table|cdata
function m.draw_pixel(pos_x, pos_y, colour)
    _rl.DrawPixel(pos_x, pos_y, resolve_colour(colour))
end

--- Draw a pixel using geometry.
--- @param position cdata|table Vector2
--- @param colour string|table|cdata
function m.draw_pixel_v(position, colour)
    _rl.DrawPixelV(resolve_vector2(position), resolve_colour(colour))
end

--- @section Lines & Splines

--- Draw a line.
--- @param start_pos_x number
--- @param start_pos_y number
--- @param end_pos_x number
--- @param end_pos_y number
--- @param colour string|table|cdata
function m.draw_line(start_pos_x, start_pos_y, end_pos_x, end_pos_y, colour)
    _rl.DrawLine(start_pos_x, start_pos_y, end_pos_x, end_pos_y, resolve_colour(colour))
end

--- Draw a line.
--- @param start_pos cdata|table Vector2
--- @param end_pos cdata|table Vector2
--- @param colour string|table|cdata
function m.draw_line_v(start_pos, end_pos, colour)
    _rl.DrawLineV(resolve_vector2(start_pos), resolve_vector2(end_pos), resolve_colour(colour))
end

--- Draw a line.
--- @param start_pos cdata|table Vector2
--- @param end_pos cdata|table Vector2
--- @param thick number
--- @param colour string|table|cdata
function m.draw_line_ex(start_pos, end_pos, thick, colour)
    _rl.DrawLineEx(resolve_vector2(start_pos), resolve_vector2(end_pos), thick, resolve_colour(colour))
end

--- Draw line segment cubic-bezier in-out interpolation.
--- @param start_pos cdata|table Vector2
--- @param end_pos cdata|table Vector2
--- @param thick number
--- @param colour string|table|cdata
function m.draw_line_bezier(start_pos, end_pos, thick, colour)
    _rl.DrawLineBezier(resolve_vector2(start_pos), resolve_vector2(end_pos), thick, resolve_colour(colour))
end

--- Draw a dashed line.
--- @param start_pos cdata|table Vector2
--- @param end_pos cdata|table Vector2
--- @param dash_size number
--- @param space_size number
--- @param colour string|table|cdata
function m.draw_line_dashed(start_pos, end_pos, dash_size, space_size, colour)
    _rl.DrawLineDashed(resolve_vector2(start_pos), resolve_vector2(end_pos), dash_size, space_size, resolve_colour(colour))
end

--- @section Triangles

--- Draw a colour-filled triangle, counter-clockwise vertex order.
--- @param v1 cdata|table Vector2
--- @param v2 cdata|table Vector2
--- @param v3 cdata|table Vector2
--- @param colour string|table|cdata
function m.draw_triangle(v1, v2, v3, colour)
    _rl.DrawTriangle(resolve_vector2(v1), resolve_vector2(v2), resolve_vector2(v3), resolve_colour(colour))
end

--- Draw triangle outline, counter-clockwise vertex order.
--- @param v1 cdata|table Vector2
--- @param v2 cdata|table Vector2
--- @param v3 cdata|table Vector2
--- @param colour string|table|cdata
function m.draw_triangle_lines(v1, v2, v3, colour)
    _rl.DrawTriangleLines(resolve_vector2(v1), resolve_vector2(v2), resolve_vector2(v3), resolve_colour(colour))
end

--- Draw triangle outline with line thickness, counter-clockwise vertex order.
--- @param v1 cdata|table Vector2
--- @param v2 cdata|table Vector2
--- @param v3 cdata|table Vector2
--- @param thick number
--- @param colour string|table|cdata
function m.draw_triangle_lines_ex(v1, v2, v3, thick, colour)
    _rl.DrawTriangleLinesEx(resolve_vector2(v1), resolve_vector2(v2), resolve_vector2(v3), thick, resolve_colour(colour))
end

--- @section Rectangles

--- Draw a colour-filled rectangle.
--- @param pos_x number
--- @param pos_y number
--- @param width number
--- @param height number
--- @param colour string|table|cdata
function m.draw_rectangle(pos_x, pos_y, width, height, colour)
    _rl.DrawRectangle(pos_x, pos_y, width, height, resolve_colour(colour))
end

--- Draw a colour-filled rectangle.
--- @param position cdata|table Vector2
--- @param size cdata|table Vector2
--- @param colour string|table|cdata
function m.draw_rectangle_v(position, size, colour)
    _rl.DrawRectangleV(resolve_vector2(position), resolve_vector2(size), resolve_colour(colour))
end

--- Draw a colour-filled rectangle.
--- @param rec cdata|table Rectangle
--- @param colour string|table|cdata
function m.draw_rectangle_rec(rec, colour)
    _rl.DrawRectangleRec(resolve_rectangle(rec), resolve_colour(colour))
end

--- Draw a colour-filled rectangle with pro parameters.
--- @param rec cdata|table Rectangle
--- @param origin cdata|table Vector2
--- @param rotation number
--- @param colour string|table|cdata
function m.draw_rectangle_pro(rec, origin, rotation, colour)
    _rl.DrawRectanglePro(resolve_rectangle(rec), resolve_vector2(origin), rotation, resolve_colour(colour))
end

--- Draw rectangle outline.
--- @param pos_x number
--- @param pos_y number
--- @param width number
--- @param height number
--- @param colour string|table|cdata
function m.draw_rectangle_lines(pos_x, pos_y, width, height, colour)
    _rl.DrawRectangleLines(pos_x, pos_y, width, height, resolve_colour(colour))
end

--- Draw rectangle outline with line thickness.
--- @param rec cdata|table Rectangle
--- @param thick number
--- @param colour string|table|cdata
function m.draw_rectangle_lines_ex(rec, thick, colour)
    _rl.DrawRectangleLinesEx(resolve_rectangle(rec), thick, resolve_colour(colour))
end

--- Draw rectangle with rounded edges.
--- @param rec cdata|table Rectangle
--- @param roundness number
--- @param segments number
--- @param colour string|table|cdata
function m.draw_rectangle_rounded(rec, roundness, segments, colour)
    _rl.DrawRectangleRounded(resolve_rectangle(rec), roundness, segments, resolve_colour(colour))
end

--- Draw rectangle lines with rounded edges.
--- @param rec cdata|table Rectangle
--- @param roundness number
--- @param segments number
--- @param colour string|table|cdata
function m.draw_rectangle_rounded_lines(rec, roundness, segments, colour)
    _rl.DrawRectangleRoundedLines(resolve_rectangle(rec), roundness, segments, resolve_colour(colour))
end

--- Draw rectangle lines with rounded edges outline and line thickness.
--- @param rec cdata|table Rectangle
--- @param roundness number
--- @param segments number
--- @param thick number
--- @param colour string|table|cdata
function m.draw_rectangle_rounded_lines_ex(rec, roundness, segments, thick, colour)
    _rl.DrawRectangleRoundedLinesEx(resolve_rectangle(rec), roundness, segments, thick, resolve_colour(colour))
end

--- @section Circles & Ellipses

--- Draw a colour-filled circle.
--- @param center_x number
--- @param center_y number
--- @param radius number
--- @param colour string|table|cdata
function m.draw_circle(center_x, center_y, radius, colour)
    _rl.DrawCircle(center_x, center_y, radius, resolve_colour(colour))
end

--- Draw a colour-filled circle.
--- @param center cdata|table Vector2
--- @param radius number
--- @param colour string|table|cdata
function m.draw_circle_v(center, radius, colour)
    _rl.DrawCircleV(resolve_vector2(center), radius, resolve_colour(colour))
end

--- Draw circle outline.
--- @param center_x number
--- @param center_y number
--- @param radius number
--- @param colour string|table|cdata
function m.draw_circle_lines(center_x, center_y, radius, colour)
    _rl.DrawCircleLines(center_x, center_y, radius, resolve_colour(colour))
end

--- Draw circle outline.
--- @param center cdata|table Vector2
--- @param radius number
--- @param colour string|table|cdata
function m.draw_circle_lines_v(center, radius, colour)
    _rl.DrawCircleLinesV(resolve_vector2(center), radius, resolve_colour(colour))
end

--- Draw circle outline with line thickness.
--- @param center cdata|table Vector2
--- @param radius number
--- @param thick number
--- @param colour string|table|cdata
function m.draw_circle_lines_ex(center, radius, thick, colour)
    _rl.DrawCircleLinesEx(resolve_vector2(center), radius, thick, resolve_colour(colour))
end

--- Draw a piece of a circle.
--- @param center cdata|table Vector2
--- @param radius number
--- @param start_angle number
--- @param end_angle number
--- @param segments number
--- @param colour string|table|cdata
function m.draw_circle_sector(center, radius, start_angle, end_angle, segments, colour)
    _rl.DrawCircleSector(resolve_vector2(center), radius, start_angle, end_angle, segments, resolve_colour(colour))
end

--- Draw circle sector outline.
--- @param center cdata|table Vector2
--- @param radius number
--- @param start_angle number
--- @param end_angle number
--- @param segments number
--- @param colour string|table|cdata
function m.draw_circle_sector_lines(center, radius, start_angle, end_angle, segments, colour)
    _rl.DrawCircleSectorLines(resolve_vector2(center), radius, start_angle, end_angle, segments, resolve_colour(colour))
end

--- Draw ellipse.
--- @param center_x number
--- @param center_y number
--- @param radius_h number
--- @param radius_v number
--- @param colour string|table|cdata
function m.draw_ellipse(center_x, center_y, radius_h, radius_v, colour)
    _rl.DrawEllipse(center_x, center_y, radius_h, radius_v, resolve_colour(colour))
end

--- Draw ellipse outline.
--- @param center_x number
--- @param center_y number
--- @param radius_h number
--- @param radius_v number
--- @param colour string|table|cdata
function m.draw_ellipse_lines(center_x, center_y, radius_h, radius_v, colour)
    _rl.DrawEllipseLines(center_x, center_y, radius_h, radius_v, resolve_colour(colour))
end

--- Draw ellipse outline with line thickness.
--- @param center cdata|table Vector2
--- @param radius_h number
--- @param radius_v number
--- @param thick number
--- @param colour string|table|cdata
function m.draw_ellipse_lines_ex(center, radius_h, radius_v, thick, colour)
    _rl.DrawEllipseLinesEx(resolve_vector2(center), radius_h, radius_v, thick, resolve_colour(colour))
end

--- Draw ring.
--- @param center cdata|table Vector2
--- @param inner_radius number
--- @param outer_radius number
--- @param start_angle number
--- @param end_angle number
--- @param segments number
--- @param colour string|table|cdata
function m.draw_ring(center, inner_radius, outer_radius, start_angle, end_angle, segments, colour)
    _rl.DrawRing(resolve_vector2(center), inner_radius, outer_radius, start_angle, end_angle, segments, resolve_colour(colour))
end

--- Draw ring outline.
--- @param center cdata|table Vector2
--- @param inner_radius number
--- @param outer_radius number
--- @param start_angle number
--- @param end_angle number
--- @param segments number
--- @param colour string|table|cdata
function m.draw_ring_lines(center, inner_radius, outer_radius, start_angle, end_angle, segments, colour)
    _rl.DrawRingLines(resolve_vector2(center), inner_radius, outer_radius, start_angle, end_angle, segments, resolve_colour(colour))
end

--- Draw ring outline with line thickness.
--- @param center cdata|table Vector2
--- @param inner_radius number
--- @param outer_radius number
--- @param start_angle number
--- @param end_angle number
--- @param segments number
--- @param thick number
--- @param colour string|table|cdata
function m.draw_ring_lines_ex(center, inner_radius, outer_radius, start_angle, end_angle, segments, thick, colour)
    _rl.DrawRingLinesEx(resolve_vector2(center), inner_radius, outer_radius, start_angle, end_angle, segments, thick, resolve_colour(colour))
end

--- @section Polygons

--- Draw a polygon of n sides.
--- @param center cdata|table Vector2
--- @param sides number
--- @param radius number
--- @param rotation number
--- @param colour string|table|cdata
function m.draw_poly(center, sides, radius, rotation, colour)
    _rl.DrawPoly(resolve_vector2(center), sides, radius, rotation, resolve_colour(colour))
end

--- Draw a polygon outline of n sides.
--- @param center cdata|table Vector2
--- @param sides number
--- @param radius number
--- @param rotation number
--- @param colour string|table|cdata
function m.draw_poly_lines(center, sides, radius, rotation, colour)
    _rl.DrawPolyLines(resolve_vector2(center), sides, radius, rotation, resolve_colour(colour))
end

--- Draw a polygon outline of n sides with line thickness.
--- @param center cdata|table Vector2
--- @param sides number
--- @param radius number
--- @param rotation number
--- @param thick number
--- @param colour string|table|cdata
function m.draw_poly_lines_ex(center, sides, radius, rotation, thick, colour)
    _rl.DrawPolyLinesEx(resolve_vector2(center), sides, radius, rotation, thick, resolve_colour(colour))
end

--- @section Splines

--- Draw spline: Linear, minimum 2 points.
--- @param points cdata|table Vector2* or table of coordinates
--- @param point_count number
--- @param thick number
--- @param colour string|table|cdata
function m.draw_spline_linear(points, point_count, thick, colour)
    local ptr = type(points) == "table" and resolve_vector_array(points, point_count) or points
    _rl.DrawSplineLinear(ptr, point_count, thick, resolve_colour(colour))
end

--- Draw spline: B-Spline, minimum 4 points.
--- @param points cdata|table Vector2* or table of coordinates
--- @param point_count number
--- @param thick number
--- @param colour string|table|cdata
function m.draw_spline_basis(points, point_count, thick, colour)
    local ptr = type(points) == "table" and resolve_vector_array(points, point_count) or points
    _rl.DrawSplineBasis(ptr, point_count, thick, resolve_colour(colour))
end

--- Draw spline: Catmull-Rom, minimum 4 points.
--- @param points cdata|table Vector2* or table of coordinates
--- @param point_count number
--- @param thick number
--- @param colour string|table|cdata
function m.draw_spline_catmull_rom(points, point_count, thick, colour)
    local ptr = type(points) == "table" and resolve_vector_array(points, point_count) or points
    _rl.DrawSplineCatmullRom(ptr, point_count, thick, resolve_colour(colour))
end

--- Draw spline: Quadratic Bezier, minimum 3 points.
--- @param points cdata|table Vector2* or table of coordinates
--- @param point_count number
--- @param thick number
--- @param colour string|table|cdata
function m.draw_spline_bezier_quadratic(points, point_count, thick, colour)
    local ptr = type(points) == "table" and resolve_vector_array(points, point_count) or points
    _rl.DrawSplineBezierQuadratic(ptr, point_count, thick, resolve_colour(colour))
end

--- Draw spline: Cubic Bezier, minimum 4 points.
--- @param points cdata|table Vector2* or table of coordinates
--- @param point_count number
--- @param thick number
--- @param colour string|table|cdata
function m.draw_spline_bezier_cubic(points, point_count, thick, colour)
    local ptr = type(points) == "table" and resolve_vector_array(points, point_count) or points
    _rl.DrawSplineBezierCubic(ptr, point_count, thick, resolve_colour(colour))
end

--- @section Utility

--- Resolves a colour input into a native FFI Color.
--- @param c string|table|cdata
--- @return cdata
function m.resolve_colour(c)
    return resolve_colour(c)
end

return m