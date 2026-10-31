--- @class AudioRegistry
--- @file src/framework/audio/audio_registry.lua
--- @description Audio resource caching and playback management.

--- @section Imports

local _audio = require("src.framework.audio.audio")
local _fs = require("src.framework.core.filesystem")

--- @section Methods

local AudioAssetMethods = {}
AudioAssetMethods.__index = AudioAssetMethods

--- Unloads the audio asset from memory and clears it from cache.
function AudioAssetMethods:unload()
    if self.handle then
        if self.type == "sound" then
            _audio.unload_sound(self.handle)
        elseif self.type == "music" then
            _audio.unload_music_stream(self.handle)
        end
        self.handle = nil
    end
    if self.registry and self.registry.cache[self.cache_key] == self then
        self.registry.cache[self.cache_key] = nil
    end
end

--- Plays the audio asset.
--- @param loop boolean|nil Only applies to music streams
function AudioAssetMethods:play(loop)
    if not self.handle then return end
    if self.type == "sound" then
        _audio.play_sound(self.handle)
    elseif self.type == "music" then
        if loop ~= nil then
            self.handle.looping = loop
        end
        _audio.play_music_stream(self.handle)
    end
end

--- Stops the audio asset.
function AudioAssetMethods:stop()
    if not self.handle then return end
    if self.type == "sound" then
        _audio.stop_sound(self.handle)
    elseif self.type == "music" then
        _audio.stop_music_stream(self.handle)
    end
end

--- Sets the volume of the audio asset (0.0 to 1.0).
--- @param volume number
function AudioAssetMethods:set_volume(volume)
    if not self.handle then return end
    if self.type == "sound" then
        _audio.set_sound_volume(self.handle, volume)
    elseif self.type == "music" then
        _audio.set_music_volume(self.handle, volume)
    end
end

--- Sets the pitch of the audio asset.
--- @param pitch number
function AudioAssetMethods:set_pitch(pitch)
    if not self.handle then return end
    if self.type == "sound" then
        _audio.set_sound_pitch(self.handle, pitch)
    elseif self.type == "music" then
        _audio.set_music_pitch(self.handle, pitch)
    end
end

--- @section Constructor

local AudioRegistry = {}
AudioRegistry.__index = AudioRegistry

--- Creates a new AudioRegistry instance.
--- @return AudioRegistry
function AudioRegistry.new()
    local self = setmetatable({}, AudioRegistry)
    self.cache = {}
    self.active_streams = {}
    self.root = "."
    return self
end

--- @section Methods

--- Updates active music streams (needed for Raylib streaming).
--- @param dt number
function AudioRegistry:update(dt)
    for _, asset in pairs(self.active_streams) do
        if asset.handle and asset.type == "music" then
            _audio.update_music_stream(asset.handle)
        end
    end
end

--- Loads an audio asset (sound or music) with caching.
--- @param audio_type string "sound" or "music"
--- @param path string File path
--- @return table|nil AudioAsset
function AudioRegistry:load(audio_type, path)
    if not path or path == "" then return nil end
    audio_type = audio_type or "sound"

    local cache_key = audio_type .. ":" .. path
    if self.cache[cache_key] then
        return self.cache[cache_key]
    end

    local resolved_path = _fs.resolve(path, { self.root, "." })
    if not resolved_path then
        log("warn", "Failed to resolve audio path", { path = path, root = self.root })
        return nil
    end

    local handle = nil
    if audio_type == "sound" then
        handle = _audio.load_sound(resolved_path)
        if not handle or not _audio.is_sound_valid(handle) then
            log("warn", "Failed to load sound", { path = resolved_path })
            return nil
        end
    elseif audio_type == "music" then
        handle = _audio.load_music_stream(resolved_path)
        if not handle or not _audio.is_music_valid(handle) then
            log("warn", "Failed to load music stream", { path = resolved_path })
            return nil
        end
    else
        log("warn", "Unknown audio type", { type = audio_type })
        return nil
    end

    local asset = setmetatable({
        handle = handle,
        type = audio_type,
        path = resolved_path,
        cache_key = cache_key,
        registry = self,
    }, AudioAssetMethods)

    self.cache[cache_key] = asset
    if audio_type == "music" then
        table.insert(self.active_streams, asset)
    end

    return asset
end

--- Unloads all cached audio assets.
function AudioRegistry:cleanup()
    for _, asset in pairs(self.cache) do
        if asset.handle then
            if asset.type == "sound" then
                _audio.unload_sound(asset.handle)
            elseif asset.type == "music" then
                _audio.unload_music_stream(asset.handle)
            end
            asset.handle = nil
        end
    end
    self.cache = {}
    self.active_streams = {}
end

return AudioRegistry