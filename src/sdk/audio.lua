--- @module sdk.audio
--- @file src/sdk/audio.lua
--- @description Audio SDK for loading and playing sounds and music streams.
--- @default_access mod
--- @default_realm client

local m = {}

--- Loads a sound effect or music stream.
--- @param audio_type string "sound" or "music"
--- @param path string File path to audio asset
--- @return table|nil AudioAsset Handle
function m.new_source(audio_type, path)
    if not _G.audio_registry then
        log("warn", "AudioRegistry not initialized")
        return nil
    end
    return _G.audio_registry:load(audio_type, path)
end

--- Convenience shorthand to load a sound effect.
--- @param path string
--- @return table|nil Sound handle
function m.load_sound(path)
    return m.new_source("sound", path)
end

--- Convenience shorthand to load a music track.
--- @param path string
--- @return table|nil Music handle
function m.load_music(path)
    return m.new_source("music", path)
end

--- Cleans up and unloads all cached audio assets.
function m.cleanup_audio()
    if _G.audio_registry then
        _G.audio_registry:cleanup()
    end
end

return m