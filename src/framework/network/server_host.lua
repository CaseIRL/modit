--- @module server_host
--- @file src/framework/network/server_host.lua
--- @description Loads game server code and runs it on a fixed timestep.

--- @section Imports

local _ffi = require("ffi")
local _log = require("src.framework.core.log")

--- @section Constants

local DEFAULT_TICK_RATE = 30
local MAX_FRAME = 0.25

--- @section Initialisation

local ServerHost = {}
ServerHost.__index = ServerHost

local sleep_ms
local now

if _ffi.os == "Windows" then
    pcall(_ffi.cdef, "void Sleep(unsigned long ms);")
    sleep_ms = function(ms) _ffi.C.Sleep(ms) end

    pcall(function()
        _ffi.cdef("unsigned int timeBeginPeriod(unsigned int ms); unsigned int timeEndPeriod(unsigned int ms);")
        _ffi.load("winmm").timeBeginPeriod(1)
    end)

    local ok = pcall(function()
        _ffi.cdef("int QueryPerformanceCounter(int64_t *count); int QueryPerformanceFrequency(int64_t *freq);")
        local value = _ffi.new("int64_t[1]")
        _ffi.C.QueryPerformanceFrequency(value)
        local freq = tonumber(value[0])
        now = function()
            _ffi.C.QueryPerformanceCounter(value)
            return tonumber(value[0]) / freq
        end
    end)
    if not ok then now = nil end
else
    pcall(_ffi.cdef, "int usleep(unsigned int usec);")
    sleep_ms = function(ms) _ffi.C.usleep(ms * 1000) end

    local ok = pcall(function()
        _ffi.cdef("typedef struct { long tv_sec; long tv_nsec; } modit_timespec_t; int clock_gettime(int clk_id, void *tp);")
        local ts = _ffi.new("modit_timespec_t[1]")
        now = function()
            _ffi.C.clock_gettime(1, ts)
            return tonumber(ts[0].tv_sec) + tonumber(ts[0].tv_nsec) / 1e9
        end
    end)
    if not ok then now = nil end
end

now = now or os.clock

--- @section Functions

--- Creates a server host
--- @param opts table { require = function (sandboxed require for the server project), tick_rate = number, crash_log = string|nil }
--- @return table host
function ServerHost.new(opts)
    local rate = tonumber(opts.tick_rate)
    if not rate or rate <= 0 then
        if opts.tick_rate ~= nil then
            _log.print("warn", ("network.tick_rate must be a positive number, using %d"):format(DEFAULT_TICK_RATE))
        end
        rate = DEFAULT_TICK_RATE
    end

    return setmetatable({
        require = opts.require or require,
        crash_log = opts.crash_log,
        tick_rate = rate,
        tick = 1 / rate,
        accumulated = 0,
        running = false,
        crashed = false,
        quit_done = false,
        game = nil,
    }, ServerHost)
end

--- Logs a server failure, writes the crash log and stops the server
--- @param stage string load | update | quit
--- @param err any Error value
function ServerHost:fail(stage, err)
    local text = ("server %s failed:\n%s"):format(stage, tostring(err))
    _log.print("error", text)

    self.crashed = true
    self.running = false

    if self.crash_log then
        local handle = io.open(self.crash_log, "a")
        if handle then
            handle:write(os.date("%Y-%m-%d %H:%M:%S"), "  ", text, "\n\n")
            handle:close()
        end
    end
end

--- Requires the projects server module and calls its load
--- @return boolean ok
function ServerHost:load()
    local ok, result = xpcall(self.require, debug.traceback, "server")
    if not ok then
        self:fail("load", result)
        return false
    end

    self.game = type(result) == "table" and result or {}

    local init = self.game.load or self.game.init
    if init then
        local ok_init, err = xpcall(init, debug.traceback)
        if not ok_init then
            self:fail("load", err)
            return false
        end
    end

    self.running = true
    _log.print("info", ("server running at %d ticks per second"):format(self.tick_rate))
    return true
end

--- Advances the server by real elapsed time, running as many fixed ticks as fit
--- @param dt number Seconds since the last call
function ServerHost:step(dt)
    if not self.running then return end

    self.accumulated = math.min(self.accumulated + dt, MAX_FRAME)

    while self.running and self.accumulated >= self.tick do
        self.accumulated = self.accumulated - self.tick

        if self.game.update then
            local ok, err = xpcall(self.game.update, debug.traceback, self.tick)
            if not ok then
                self:fail("update", err)
                return
            end
        end
    end
end

--- Stops ticking quit is still called by ServerHost:quit
function ServerHost:stop()
    self.running = false
end

--- Calls the servers quit once, then shuts down networking and physics
function ServerHost:quit()
    self.running = false
    if self.quit_done then return end
    self.quit_done = true

    if self.game and self.game.quit then
        local ok, err = xpcall(self.game.quit, debug.traceback)
        if not ok then self:fail("quit", err) end
    end

    if _G.network_registry then _G.network_registry:cleanup() end
    if _G.physics_registry then _G.physics_registry:cleanup_worlds() end
end

--- Blocking loop for headless servers.
--- @param opts table|nil { should_stop = function|nil }
function ServerHost:run(opts)
    opts = opts or {}
    local last = now()

    while self.running do
        local current = now()
        self:step(current - last)
        last = current

        if opts.should_stop and opts.should_stop() then
            self.running = false
        end

        local wait = math.floor((self.tick - self.accumulated) * 1000)
        sleep_ms(math.max(1, wait))
    end
end

return ServerHost