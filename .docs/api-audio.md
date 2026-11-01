# Audio API Reference

The Audio API provides methods for loading, playing, and managing sound effects and music streams.

---

## Loading Audio

Functions to load audio assets into memory.

### `modit.audio.new_source(audio_type, path)`

Loads a sound effect or music stream.

* **Parameters:**
    * `audio_type` (string): Either `"sound"` or `"music"`.
    * `path` (string): File path to the audio asset.

* **Returns:**
    * `table|nil`: Audio asset handle, or `nil` if failed.

```lua
local my_sound = modit.audio.new_source("sound", "assets/audio/jump.wav")
```

### `modit.audio.load_sound(path)`

Convenience shorthand to load a sound effect.

* **Parameters:**
    * `path` (string): File path to the sound file.

```lua
local jump_sound = modit.audio.load_sound("assets/audio/jump.wav")
jump_sound:play()
```

### `modit.audio.load_music(path)`

Convenience shorthand to load a music track.

* **Parameters:**
    * `path` (string): File path to the music file.

```lua
local bgm = modit.audio.load_music("assets/audio/theme.ogg")
bgm:play(true) -- loops music
```

### `modit.audio.cleanup_audio()`

Unloads and cleans up all cached audio assets.

```lua
modit.audio.cleanup_audio()
```

---

## Audio Asset Methods

Methods available on returned audio asset handles.

### `asset:play(loop)`

Plays the audio asset.

* **Parameters:**
    * `loop` (boolean|nil): Optional loop flag, applies only to music streams.

```lua
music_track:play(true)
```

### `asset:stop()`

Stops playback of the audio asset.

```lua
sound_effect:stop()
```

### `asset:set_volume(volume)`

Sets the volume level of the audio asset.

* **Parameters:**
    * `volume` (number): Volume value ranging from `0.0` to `1.0`.

```lua
sound_effect:set_volume(0.5)
```

### `asset:set_pitch(pitch)`

Sets the pitch multiplier of the audio asset.

* **Parameters:**
    * `pitch` (number): Pitch value.

```lua
sound_effect:set_pitch(1.2)
```

### `asset:unload()`

Unloads the audio asset from memory and clears it from cache.

```lua
sound_effect:unload()
```
