--- @module sdk.graphics
--- @file src/sdk/graphics.lua
--- @description Graphics and environment handling.
--- @default_access mod
--- @default_realm client

--- @section Initialisation

local _camera = require("src.renderer.camera")
local m = {}

--- Helper to get the global environment container.
local function get_environment()
    if not _G.environment then
        log("warn", "Environment not initialized")
        return nil
    end
    return _G.environment
end

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
    if not _G.render_list then
        log("warn", "RenderList not initialized")
        return
    end
    _G.render_list:set_camera(camera)
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

--- @section Models

--- Loads a model from the project, or retrieves it from cache via the global model registry.
--- @param path string Model file path
--- @return table|nil ModelAsset handle or nil if invalid
function m.load_model(path)
    if not _G.model_registry then
        log("warn", "ModelRegistry not initialized")
        return nil
    end
    return _G.model_registry:load_model(path)
end

--- Unloads every cached model. Instances still using one stop drawing.
function m.cleanup_models()
    if _G.model_registry then
        _G.model_registry:cleanup_models()
    end
end

--- Creates a new retained model in the active scene.
--- Draws through the scene camera, so set a `mode = "3d"` camera with set_camera first.
--- Rotation is euler degrees { pitch, yaw, roll }.
--- Scale is a number or { x, y, z }.
--- Primitives are unit sized ("cube", "sphere", "plane", "cylinder"), size them with scale.
--- @param config table { path|primitive|model, x, y, z, position, rotation, scale, colour, cast_shadow, unlit, shader, owner }
--- @return table|nil ModelObjectHandle
function m.new_model(config)
    if not _G.model_registry then
        log("warn", "ModelRegistry not initialized")
        return nil
    end
    return _G.model_registry:add(config)
end

--- @section Shaders

--- Loads a shader from vertex and fragment files, or retrieves it from cache via the global shader registry.
--- @param vs_path string|nil Vertex shader file path
--- @param fs_path string|nil Fragment shader file path
--- @return table|nil ShaderAsset handle or nil if invalid
function m.load_shader(vs_path, fs_path)
    if not _G.shader_registry then
        log("warn", "ShaderRegistry not initialized")
        return nil
    end
    return _G.shader_registry:load_shader(vs_path, fs_path)
end

--- Loads a shader from code strings in memory.
--- @param vs_code string Vertex shader code string
--- @param fs_code string Fragment shader code string
--- @param cache_key string|nil Optional custom cache key
--- @return table|nil ShaderAsset handle or nil if invalid
function m.load_shader_from_memory(vs_code, fs_code, cache_key)
    if not _G.shader_registry then
        log("warn", "ShaderRegistry not initialized")
        return nil
    end
    return _G.shader_registry:load_shader_from_memory(vs_code, fs_code, cache_key)
end

--- Unloads every cached shader from VRAM.
function m.cleanup_shaders()
    if _G.shader_registry then
        _G.shader_registry:cleanup_shaders()
    end
end

--- @section Lighting, Sky & Environment

--- Turns lighting on or off. Off draws models with their own flat materials.
--- Only applies to scenes with a `mode = "3d"` camera.
--- @param enabled boolean
function m.set_lighting(enabled)
    local env = get_environment()
    if env then env:set_lighting(enabled) end
end

--- Sets the sun direction (the way the light travels) and colour.
--- The direction is normalised and kept pointing downward.
--- @param dx number Direction X
--- @param dy number Direction Y, should be negative
--- @param dz number Direction Z
--- @param r number|nil Red 0-255 (default 255)
--- @param g number|nil Green 0-255 (default 255)
--- @param b number|nil Blue 0-255 (default 255)
function m.set_sun(dx, dy, dz, r, g, b)
    local env = get_environment()
    if env then env:set_sun(dx, dy, dz, r, g, b) end
end

--- Sets the ambient light colour, the light on faces the sun doesn't reach.
--- @param r number Red 0-255
--- @param g number Green 0-255
--- @param b number Blue 0-255
function m.set_ambient(r, g, b)
    local env = get_environment()
    if env then env:set_ambient(r, g, b) end
end

--- Sets distance fog. Without a colour the fog follows the sky horizon.
--- @param near number Distance where fog starts
--- @param far number Distance where fog is solid
--- @param r number|nil Red 0-255
--- @param g number|nil Green 0-255
--- @param b number|nil Blue 0-255
function m.set_fog(near, far, r, g, b)
    local env = get_environment()
    if env then env:set_fog(near, far, r, g, b) end
end

--- Sets the sky gradient: top colour fading to the horizon colour, solid below the horizon.
--- @param tr number Top red 0-255
--- @param tg number Top green 0-255
--- @param tb number Top blue 0-255
--- @param hr number Horizon red 0-255
--- @param hg number Horizon green 0-255
--- @param hb number Horizon blue 0-255
function m.set_sky(tr, tg, tb, hr, hg, hb)
    local env = get_environment()
    if env then env:set_sky(tr, tg, tb, hr, hg, hb) end
end

--- Removes the sky, the window clear colour shows instead.
function m.clear_sky()
    local env = get_environment()
    if env then env:clear_sky() end
end

--- Sets the shadow mode and its options. Models opt out with `cast_shadow = false`.
--- "map" is the best looking and also receives shadows on lit models, "projected" flattens casters onto the ground plane, "blob" draws a soft disc under each caster.
--- @param config table { mode = "off" | "blob" | "projected" | "map", strength = 0-1, range = world units covered by "map", size = shadow map pixels, ground = world Y for "projected" and "blob" }
function m.set_shadows(config)
    local env = get_environment()
    if env then env:set_shadows(config) end
end

--- Restores every environment setting to its default.
function m.reset_environment()
    local env = get_environment()
    if env then env:reset() end
end

return m