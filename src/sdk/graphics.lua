--- @module sdk.graphics
--- @file src/sdk/graphics.lua
--- @description Graphics handling; shapes, splines, and visual primitives.
--- @default_access mod
--- @default_realm client

--- @section Initialisation

local _camera = require("src.renderer.camera")
local m = {}

--- @section Camera

--- Creates a camera. Nothing uses it until you pass it to set_camera.
--- Objects only draw through it when created with `space = "world"`.
--- @param config table|nil { mode = "2d" | "3d", zoom, rotation, offset_x, offset_y, target_2d_x, target_2d_y, x, y, z, target_x, target_y, target_z, fov, projection }
--- @return table Camera
function m.new_camera(config)
    return _camera.new(config)
end

--- Sets the active scene's camera, or clears it with nil. Cleared automatically when the scene unloads.
--- @param camera table|nil Camera from new_camera
function m.set_camera(camera)
    if not _G.draw_list then
        log("warn", "DrawList not initialized")
        return
    end
    _G.draw_list:set_camera(camera)
end

--- Current window width and height in pixels.
--- @return number, number
function m.get_screen_size()
    return _camera.get_screen_size()
end

--- @section Text & Fonts

--- Loads a custom font or retrieves it from cache via the global text registry.
--- @param path string Font file path
--- @param size number Font size
--- @return table|nil FontObject handle or nil if invalid
function m.load_font(path, size)
    if not _G.text_registry then
        log("warn", "TextRegistry not initialized")
        return nil
    end
    return _G.text_registry:load_font(path, size)
end

--- Cleans up and unloads all cached fonts from the global text registry.
function m.cleanup_fonts()
    if _G.text_registry then
        _G.text_registry:cleanup_fonts()
    end
end

--- Creates a new retained text object managed by the global text registry.
--- @param config table Configuration table ({ text, font, x, y, position, font_size, colour, spacing })
--- @return table TextObjectHandle Text object handle
function m.new_text(config)
    if not _G.text_registry then
        log("warn", "TextRegistry not initialized")
        return nil
    end
    return _G.text_registry:add(config)
end

--- @section Textures & Images

--- Loads a texture from the project, or retrieves it from cache via the global image registry.
--- @param path string Image file path
--- @param opts table|nil { filter = "point" | "bilinear" | "trilinear" } (default "point")
--- @return table|nil TextureObject handle or nil if invalid
function m.load_texture(path, opts)
    if not _G.image_registry then
        log("warn", "ImageRegistry not initialized")
        return nil
    end
    return _G.image_registry:load_texture(path, opts and opts.filter)
end

--- Unloads every cached texture.
function m.cleanup_textures()
    if _G.image_registry then
        _G.image_registry:cleanup_textures()
    end
end

--- Creates a new retained image in the active scene: a single image, sprite sheet or animation.
--- @param config table { texture|path, filter, x, y, scale, rotation, origin, tint, layer, flip_x, flip_y, frame = {x,y,w,h}, frame_width, frame_height, animations, animation }
--- @return table|nil ImageObjectHandle
function m.new_image(config)
    if not _G.image_registry then
        log("warn", "ImageRegistry not initialized")
        return nil
    end
    return _G.image_registry:add(config)
end

--- @section Shapes

--- Creates a new retained shape, line, or spline in the active scene pool.
--- @param shape_type string The primitive or spline type (e.g. "rectangle", "circle", "spline_linear")
--- @param config table Configuration properties (positions, points, colors, thickness)
--- @return table|nil Shape handle
function m.new_shape(shape_type, config)
    if not _G.shapes_registry then
        log("warn", "Cannot create shape: ShapesRegistry not initialized")
        return nil
    end
    return _G.shapes_registry:add(shape_type, config)
end

--- Gets the total number of active shapes/splines in the current scene pool.
--- @return number count
function m.get_shape_count()
    if not _G.shapes_registry or not _G.shapes_registry.active_scene then
        return 0
    end
    local pool = _G.shapes_registry.scenes[_G.shapes_registry.active_scene]
    if not pool then return 0 end
    
    local count = 0
    for _ in pairs(pool) do
        count = count + 1
    end
    return count
end

return m