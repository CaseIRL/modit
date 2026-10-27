--- @class ShapesRegistry
--- @file src/graphics/shapes_registry.lua
--- @description Shape registry managing shape pools per scene.

--- @section Imports

local _shapes = require("src.renderer.shapes")

--- @section Shape Drawing Strategies

local draw_strategies = {
    -- Basic Shapes & Pixels
    pixel = function(s) _shapes.draw_pixel(s.x, s.y, s.colour) end,
    pixel_v = function(s) _shapes.draw_pixel_v(s.position, s.colour) end,

    -- Lines & Splines
    line = function(s) _shapes.draw_line(s.start_x, s.start_y, s.end_x, s.end_y, s.colour) end,
    line_v = function(s) _shapes.draw_line_v(s.start_pos, s.end_pos, s.colour) end,
    line_ex = function(s) _shapes.draw_line_ex(s.start_pos, s.end_pos, s.thick, s.colour) end,
    line_bezier = function(s) _shapes.draw_line_bezier(s.start_pos, s.end_pos, s.thick, s.colour) end,
    line_dashed = function(s) _shapes.draw_line_dashed(s.start_pos, s.end_pos, s.dash_size, s.space_size, s.colour) end,

    -- Triangles
    triangle = function(s) _shapes.draw_triangle(s.v1, s.v2, s.v3, s.colour) end,
    triangle_lines = function(s) _shapes.draw_triangle_lines(s.v1, s.v2, s.v3, s.colour) end,
    triangle_lines_ex = function(s) _shapes.draw_triangle_lines_ex(s.v1, s.v2, s.v3, s.thick, s.colour) end,

    -- Rectangles
    rectangle = function(s) _shapes.draw_rectangle(s.x, s.y, s.width, s.height, s.colour) end,
    rectangle_v = function(s) _shapes.draw_rectangle_v(s.position, s.size, s.colour) end,
    rectangle_rec = function(s) _shapes.draw_rectangle_rec(s.rec, s.colour) end,
    rectangle_pro = function(s) _shapes.draw_rectangle_pro(s.rec, s.origin, s.rotation, s.colour) end,
    rectangle_lines = function(s) _shapes.draw_rectangle_lines(s.x, s.y, s.width, s.height, s.colour) end,
    rectangle_lines_ex = function(s) _shapes.draw_rectangle_lines_ex(s.rec, s.thick, s.colour) end,
    rectangle_rounded = function(s) _shapes.draw_rectangle_rounded(s.rec, s.roundness, s.segments, s.colour) end,
    rectangle_rounded_lines = function(s) _shapes.draw_rectangle_rounded_lines(s.rec, s.roundness, s.segments, s.colour) end,
    rectangle_rounded_lines_ex = function(s) _shapes.draw_rectangle_rounded_lines_ex(s.rec, s.roundness, s.segments, s.thick, s.colour) end,

    -- Circles & Ellipses
    circle = function(s) _shapes.draw_circle(s.center.x, s.center.y, s.radius, s.colour) end,
    circle_v = function(s) _shapes.draw_circle_v(s.center, s.radius, s.colour) end,
    circle_lines = function(s) _shapes.draw_circle_lines(s.center.x, s.center.y, s.radius, s.colour) end,
    circle_lines_v = function(s) _shapes.draw_circle_lines_v(s.center, s.radius, s.colour) end,
    circle_lines_ex = function(s) _shapes.draw_circle_lines_ex(s.center, s.radius, s.thick, s.colour) end,
    circle_sector = function(s) _shapes.draw_circle_sector(s.center, s.radius, s.start_angle, s.end_angle, s.segments, s.colour) end,
    circle_sector_lines = function(s) _shapes.draw_circle_sector_lines(s.center, s.radius, s.start_angle, s.end_angle, s.segments, s.colour) end,
    
    ellipse = function(s) _shapes.draw_ellipse(s.x, s.y, s.radius_h, s.radius_v, s.colour) end,
    ellipse_lines = function(s) _shapes.draw_ellipse_lines(s.x, s.y, s.radius_h, s.radius_v, s.colour) end,
    ellipse_lines_ex = function(s) _shapes.draw_ellipse_lines_ex(s.center, s.radius_h, s.radius_v, s.thick, s.colour) end,

    ring = function(s) _shapes.draw_ring(s.center, s.inner_radius, s.outer_radius, s.start_angle, s.end_angle, s.segments, s.colour) end,
    ring_lines = function(s) _shapes.draw_ring_lines(s.center, s.inner_radius, s.outer_radius, s.start_angle, s.end_angle, s.segments, s.colour) end,
    ring_lines_ex = function(s) _shapes.draw_ring_lines_ex(s.center, s.inner_radius, s.outer_radius, s.start_angle, s.end_angle, s.segments, s.thick, s.colour) end,

    -- Polygons
    poly = function(s) _shapes.draw_poly(s.center, s.sides, s.radius, s.rotation, s.colour) end,
    poly_lines = function(s) _shapes.draw_poly_lines(s.center, s.sides, s.radius, s.rotation, s.colour) end,
    poly_lines_ex = function(s) _shapes.draw_poly_lines_ex(s.center, s.sides, s.radius, s.rotation, s.thick, s.colour) end,

    -- Splines
    spline_linear = function(s) _shapes.draw_spline_linear(s.points, s.point_count, s.thick, s.colour) end,
    spline_basis = function(s) _shapes.draw_spline_basis(s.points, s.point_count, s.thick, s.colour) end,
    spline_catmull_rom = function(s) _shapes.draw_spline_catmull_rom(s.points, s.point_count, s.thick, s.colour) end,
    spline_bezier_quadratic = function(s) _shapes.draw_spline_bezier_quadratic(s.points, s.point_count, s.thick, s.colour) end,
    spline_bezier_cubic = function(s) _shapes.draw_spline_bezier_cubic(s.points, s.point_count, s.thick, s.colour) end
}

--- @section Helpers

--- Draws one shape. Registered with the draw list as obj:render().
--- @param shape table Shape object
local function render_shape(shape)
    if shape.draw_fn then
        shape:draw_fn()
        return
    end

    local strategy = draw_strategies[shape.type]
    if strategy then
        strategy(shape)
    else
        log("warn", "Missing draw strategy for shape type during render pass", { type = shape.type, id = shape.id })
    end
end

--- @section Constructor

local ShapesRegistry = {}
ShapesRegistry.__index = ShapesRegistry

--- Creates a new central shape registry instance.
--- @return table ShapesRegistry instance
function ShapesRegistry.new()
    local self = setmetatable({}, ShapesRegistry)
    self.scenes = {}
    self.active_scene = "default"
    self.next_id = 1
    log("debug", "ShapesRegistry initialized successfully")
    return self
end

--- @section Methods

--- Sets the active scene context for shape additions.
--- @param scene_name string
function ShapesRegistry:set_active_scene(scene_name)
    self.active_scene = scene_name or "default"
    if not self.scenes[self.active_scene] then
        self.scenes[self.active_scene] = {}
        log("debug", "Created new scene shape pool", { scene = self.active_scene })
    else
        log("debug", "Switched active scene context", { scene = self.active_scene })
    end
end

--- Adds any shape type to the active scene.
--- @param shape_type string
--- @param config table
--- @return table Shape Object handle
function ShapesRegistry:add(shape_type, config)
    config = config or {}

    if not draw_strategies[shape_type] and not config.on_draw and not config.draw then
        log("warn", "Attempted to add unsupported shape type", { type = shape_type, scene = self.active_scene })
    end
    
    local scene_pool = self.scenes[self.active_scene]
    if not scene_pool then
        scene_pool = {}
        self.scenes[self.active_scene] = scene_pool
    end

    local id = self.next_id
    self.next_id = self.next_id + 1

    local init_x = config.x or (config.center and config.center.x) or 0
    local init_y = config.y or (config.center and config.center.y) or 0
    local center_tbl = config.center or { x = init_x, y = init_y }

    local shape = {
        id = id,
        scene = self.active_scene,
        type = shape_type,
        x = init_x,
        y = init_y,
        center = center_tbl,
        width = config.width or 50,
        height = config.height or 50,
        radius = config.radius or config.width or 25,
        colour = _shapes.resolve_colour(config.colour or config.color or "white"),
        layer = config.layer or 0,
        space = config.space or "screen",
        thick = config.thick or 1,
        rotation = config.rotation or 0,
        position = config.position or center_tbl,
        size = config.size,
        rec = config.rec or { x = init_x, y = init_y, width = config.width or 50, height = config.height or 50 },
        origin = config.origin,
        start_x = config.start_x or init_x,
        start_y = config.start_y or init_y,
        end_x = config.end_x or config.width or 0,
        end_y = config.end_y or config.height or 0,
        start_pos = config.start_pos,
        end_pos = config.end_pos,
        v1 = config.v1,
        v2 = config.v2,
        v3 = config.v3,
        points = config.points,
        point_count = config.point_count,
        sides = config.sides or 3,
        inner_radius = config.inner_radius or 10,
        outer_radius = config.outer_radius or 20,
        start_angle = config.start_angle or 0,
        end_angle = config.end_angle or 360,
        segments = config.segments or 36,
        roundness = config.roundness or 0.0,
        dash_size = config.dash_size or 4,
        space_size = config.space_size or 2,
        radius_h = config.radius_h or 30,
        radius_v = config.radius_v or 20,
        active = true,
        update_fn = config.on_update,
        draw_fn = config.on_draw or config.draw,
        render = render_shape,
        registry = self
    }

    function shape:remove()
        self.registry:remove_shape(self.scene, self.id)
    end

    function shape:set_position(x, y)
        self.x = x
        self.y = y
        if self.center then
            self.center.x = x
            self.center.y = y
        end
        if self.position then
            self.position.x = x
            self.position.y = y
        end
        if self.rec then
            self.rec.x = x
            self.rec.y = y
        end
    end

    function shape:set_colour(colour)
        self.colour = _shapes.resolve_colour(colour)
    end

    function shape:set_color(colour)
        self.colour = _shapes.resolve_colour(colour)
    end

    function shape:set_size(width, height)
        self.width = width
        self.height = height
        if self.rec then
            self.rec.width = width
            self.rec.height = height
        end
    end

    function shape:set_space(space)
        self.space = space
        _G.render_list:touch(self.scene)
    end

    function shape:set_layer(layer)
        self.layer = layer
        _G.render_list:touch(self.scene)
    end

    scene_pool[id] = shape
    _G.render_list:add(self.active_scene, shape)
    log("debug", "Shape added to registry", { id = id, type = shape_type, scene = self.active_scene })
    return shape
end

--- Removes a shape from scene by its ID.
--- @param scene_name string
--- @param id number
function ShapesRegistry:remove_shape(scene_name, id)
    local pool = self.scenes[scene_name]
    local obj = pool and pool[id]
    if obj then
        pool[id] = nil
        _G.render_list:remove(scene_name, obj)
        log("debug", "Shape removed from registry", { id = id, scene = scene_name })
    end
end

--- Clears all shapes registered for scene.
--- @param scene_name string
function ShapesRegistry:clear_scene(scene_name)
    if self.scenes[scene_name] then
        local count = 0
        for _ in pairs(self.scenes[scene_name]) do count = count + 1 end
        self.scenes[scene_name] = {}
        log("info", "Scene shape pool cleared", { scene = scene_name, removed_count = count })
    end
end

--- Updates active shapes for a target scene pool.
--- @param dt number
--- @param scene_name string|nil
function ShapesRegistry:update(dt, scene_name)
    local target_scene = scene_name or self.active_scene
    local pool = self.scenes[target_scene]
    if not pool then return end

    for _, shape in pairs(pool) do
        if shape.active and shape.update_fn then
            shape:update_fn(dt)
        end
    end
end

return ShapesRegistry