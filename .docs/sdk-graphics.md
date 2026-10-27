# Graphics SDK Reference

The Graphics SDK handles rendering, camera management, textures, images, text, and geometric shapes.

---

## Camera

Manage 2D and 3D camera views and screen properties.

### `modit.graphics.new_camera(config)`

Creates a camera. Objects only draw through it when created with `space = "world"`.

* **Parameters:**
    * `config` (table|nil): Configuration options:
        * `mode` (string): Camera mode, either `"2d"` or `"3d"`.
        * `zoom` (number): Camera zoom level.
        * `rotation` (number): Camera rotation angle.
        * `offset_x`, `offset_y` (number): Screen offset coordinates.
        * `target_2d_x`, `target_2d_y` (number): 2D target coordinates.
        * `x`, `y`, `z` (number): 3D position coordinates.
        * `target_x`, `target_y`, `target_z` (number): 3D target coordinates.
        * `fov` (number): Field of view.
        * `projection` (number): Projection type.
* **Returns:**
    * `table`: Camera handle.

```lua
local cam = modit.graphics.new_camera({ mode = "2d", zoom = 1.0 })
```

### `modit.graphics.set_camera(camera)`

Sets the active scene's camera, or clears it with `nil`. Cleared automatically when the scene unloads.

* **Parameters:**
    * `camera` (table|nil): Camera object returned by `new_camera`.

```lua
modit.graphics.set_camera(cam)
```

### `modit.graphics.get_screen_size()`

Gets the current window width and height in pixels.

* **Returns:**
    * `number, number`: Width and height.

```lua
local width, height = modit.graphics.get_screen_size()
```

---

## Text & Fonts

Load custom fonts and manage text rendering objects.

### `modit.graphics.load_font(path, size)`

Loads a custom font or retrieves it from cache.

* **Parameters:**
    * `path` (string): Font file path.
    * `size` (number): Font size.

* **Returns:**
    * `table|nil`: Font object handle or `nil` if invalid.

```lua
local font = modit.graphics.load_font("assets/fonts/font.ttf", 24)
```

### `modit.graphics.cleanup_fonts()`

Unloads and cleans up all cached fonts.

```lua
modit.graphics.cleanup_fonts()
```

### `modit.graphics.new_text(config)`

Creates a new retained text object.

* **Parameters:**
    * `config` (table): Configuration options:
        * `text` (string): The text string to render.
        * `font` (table): Optional loaded font object.
        * `x`, `y` (number): Position coordinates.
        * `position` (table): Vector2 position alternative.
        * `font_size` (number): Text size.
        * `colour` or `color` (string|table): Text color.
        * `spacing` (number): Character spacing.

* **Returns:**
    * `table`: Text object handle.

```lua
local txt = modit.graphics.new_text({ text = "Hello World", x = 50, y = 50, font_size = 20 })
```

### Text Object Methods

* `text_obj:set_text(new_text)`
* `text_obj:set_font(new_font)`
* `text_obj:set_position(x, y)`
* `text_obj:set_colour(colour)`
* `text_obj:set_space(space)`
* `text_obj:set_layer(layer)`
* `text_obj:measure()`
* `text_obj:remove()`

---

## Textures & Images

Load textures and create retained image objects, sprite sheets, or animations.

### `modit.graphics.load_texture(path, opts)`

Loads a texture from the project or retrieves it from cache.

* **Parameters:**
    * `path` (string): Image file path.
    * `opts` (table|nil): Options table:
    * `filter` (string): Texture filter (`"point"`, `"bilinear"`, or `"trilinear"`, default `"point"`).

* **Returns:**
    * `table|nil`: Texture object handle or `nil` if invalid.

```lua
local tex = modit.graphics.load_texture("assets/player.png", { filter = "point" })
```

### `modit.graphics.cleanup_textures()`

Unloads every cached texture.

```lua
modit.graphics.cleanup_textures()
```

### `modit.graphics.new_image(config)`

Creates a new retained image, sprite sheet, or animation in the active scene.

* **Parameters:**
    * `config` (table): Configuration options:
    * `texture` or `path` (table|string): Texture object or image file path.
    * `filter` (string): Texture filter mode.
    * `x`, `y` (number): Position coordinates.
    * `scale` (number): Scaling factor.
    * `width`, `height` (number): Explicit dimensions.
    * `rotation` (number): Rotation angle in degrees.
    * `origin` (table): Origin point offset (`{x, y}` or `{ [1], [2] }`).
    * `tint`, `colour`, or `color` (string|table): Tint color.
    * `layer` (number): Rendering order layer.
    * `space` (string): Coordinate space (`"screen"` or `"world"`).
    * `flip_x`, `flip_y` (boolean): Flip flags.
    * `frame_width`, `frame_height` (number): Frame dimensions for sprite sheets.
    * `animations` (table): Animation definitions table.
    * `animation` (string): Initial animation name to play immediately.

* **Returns:**
    * `table|nil`: Image object handle.

```lua
local img = modit.graphics.new_image({ path = "assets/player.png", x = 100, y = 100 })
```

### Image Object Methods

* `img:set_position(x, y)`
* `img:set_scale(scale)`
* `img:set_size(width, height)`
* `img:set_rotation(degrees)`
* `img:set_origin(x, y)`
* `img:set_flip(flip_x, flip_y)`
* `img:set_colour(colour)`
* `img:set_space(space)`
* `img:set_layer(layer)`
* `img:get_size()`
* `img:set_frame(index)`
* `img:play(name, restart)`
* `img:stop()`
* `img:remove()`

---

## Shapes

Create geometric shapes, lines, and splines.

### `modit.graphics.new_shape(shape_type, config)`

Creates a new retained shape, line, or spline in the active scene pool.

* **Parameters:**
* `shape_type` (string): Primitive or spline type (e.g., `"rectangle"`, `"circle"`, `"spline_linear"`).
* `config` (table): Configuration properties (positions, points, colors, thickness).

* **Returns:**
* `table|nil`: Shape handle.

```lua
local rect = modit.graphics.new_shape("rectangle", { x = 10, y = 10, width = 100, height = 50, colour = "red" })
```

### `modit.graphics.get_shape_count()`

Gets the total number of active shapes/splines in the current scene pool.

* **Returns:**
* `number`: Shape count.

### Shape Object Methods

* `shape:set_position(x, y)`
* `shape:set_colour(colour)` / `shape:set_color(colour)`
* `shape:set_size(width, height)`
* `shape:set_space(space)`
* `shape:set_layer(layer)`
* `shape:remove()`
