--- @module renderer.audio
--- @file src/audio/audio.lua
--- @description Handles audio stuff, mostly just wraps raylib.

--- @section Imports

local _raylib = require("src.bindings.raylib")
local _rl = _raylib.lib

local m = {}

--- @section Audio Device

--- Initialize audio device and context.
function m.init()
    if _rl.InitAudioDevice then
        _rl.InitAudioDevice()
    end
end

--- Close audio device and context.
function m.close()
    if _rl.CloseAudioDevice then
        _rl.CloseAudioDevice()
    end
end

--- Check if audio device is currently ready.
--- @return boolean
function m.is_ready()
    if _rl.IsAudioDeviceReady then
        return _rl.IsAudioDeviceReady()
    end
    return false
end

--- @section Sound Primitives

--- Loads a sound effect from file.
--- @param path string
--- @return cdata|nil sound
function m.load_sound(path)
    if not _rl.LoadSound then return nil end
    local sound = _rl.LoadSound(path)
    return sound
end

--- Unloads a sound effect from GPU/CPU memory.
--- @param sound cdata
function m.unload_sound(sound)
    if _rl.UnloadSound and sound then
        _rl.UnloadSound(sound)
    end
end

--- Checks if a sound handle is valid.
--- @param sound cdata
--- @return boolean
function m.is_sound_valid(sound)
    if _rl.IsSoundValid and sound then
        return _rl.IsSoundValid(sound)
    end
    return false
end

--- Plays a sound effect.
--- @param sound cdata
function m.play_sound(sound)
    if _rl.PlaySound and sound then
        _rl.PlaySound(sound)
    end
end

--- Stops a sound effect.
--- @param sound cdata
function m.stop_sound(sound)
    if _rl.StopSound and sound then
        _rl.StopSound(sound)
    end
end

--- Sets sound volume (0.0 to 1.0).
--- @param sound cdata
--- @param volume number
function m.set_sound_volume(sound, volume)
    if _rl.SetSoundVolume and sound then
        _rl.SetSoundVolume(sound, math.max(0.0, math.min(1.0, volume)))
    end
end

--- Sets sound pitch (1.0 is normal).
--- @param sound cdata
--- @param pitch number
function m.set_sound_pitch(sound, pitch)
    if _rl.SetSoundPitch and sound then
        _rl.SetSoundPitch(sound, pitch)
    end
end

--- Checks if a sound is currently playing.
--- @param sound cdata
--- @return boolean
function m.is_sound_playing(sound)
    if _rl.IsSoundPlaying and sound then
        return _rl.IsSoundPlaying(sound)
    end
    return false
end

--- @section Music Primitives

--- Loads a music stream from file.
--- @param path string
--- @return cdata|nil music
function m.load_music_stream(path)
    if not _rl.LoadMusicStream then return nil end
    local music = _rl.LoadMusicStream(path)
    return music
end

--- Unloads a music stream.
--- @param music cdata
function m.unload_music_stream(music)
    if _rl.UnloadMusicStream and music then
        _rl.UnloadMusicStream(music)
    end
end

--- Checks if a music stream handle is valid.
--- @param music cdata
--- @return boolean
function m.is_music_valid(music)
    if _rl.IsMusicValid and music then
        return _rl.IsMusicValid(music)
    end
    return false
end

--- Plays a music stream.
--- @param music cdata
function m.play_music_stream(music)
    if _rl.PlayMusicStream and music then
        _rl.PlayMusicStream(music)
    end
end

--- Stops a music stream.
--- @param music cdata
function m.stop_music_stream(music)
    if _rl.StopMusicStream and music then
        _rl.StopMusicStream(music)
    end
end

--- Pauses a music stream.
--- @param music cdata
function m.pause_music_stream(music)
    if _rl.PauseMusicStream and music then
        _rl.PauseMusicStream(music)
    end
end

--- Resumes a music stream.
--- @param music cdata
--- @/param music cdata
function m.resume_music_stream(music)
    if _rl.ResumeMusicStream and music then
        _rl.ResumeMusicStream(music)
    end
end

--- Updates music stream buffers (must be called frequently).
--- @param music cdata
function m.update_music_stream(music)
    if _rl.UpdateMusicStream and music then
        _rl.UpdateMusicStream(music)
    end
end

--- Sets music volume (0.0 to 1.0).
--- @param music cdata
--- @param volume number
function m.set_music_volume(music, volume)
    if _rl.SetMusicVolume and music then
        _rl.SetMusicVolume(music, math.max(0.0, math.min(1.0, volume)))
    end
end

--- Sets music pitch.
--- @param music cdata
--- @param pitch number
function m.set_music_pitch(music, pitch)
    if _rl.SetMusicPitch and music then
        _rl.SetMusicPitch(music, pitch)
    end
end

--- Checks if a music stream is playing.
--- @param music cdata
--- @return boolean
function m.is_music_stream_playing(music)
    if _rl.IsMusicStreamPlaying and music then
        return _rl.IsMusicStreamPlaying(music)
    end
    return false
end

return m