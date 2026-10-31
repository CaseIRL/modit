--- @module network_registry
--- @file src/framework/network/network_registry.lua
--- @description Tracks live network hosts, initialises ENet and shuts it down.

--- @section Initialisation

local Registry = {}
Registry.__index = Registry

--- @section Functions

--- Creates the registry
--- @return table registry
function Registry.new()
    return setmetatable({ hosts = {}, initialised = false }, Registry)
end

--- Creates and tracks a host
--- @param opts table|nil See network_host.new
--- @return table|nil host
--- @return string|nil error
function Registry:add(opts)
    local _enet = require("src.framework.bindings.enet")
    local _host = require("src.framework.network.network_host")

    if not self.initialised then
        if _enet.lib.enet_initialize() ~= 0 then return nil, "enet_initialize failed" end
        self.initialised = true
    end

    local host, err = _host.new(opts)
    if not host then return nil, err end

    self.hosts[#self.hosts + 1] = host
    return host
end

--- Destroys every host and shuts ENet down
function Registry:cleanup()
    for _, host in ipairs(self.hosts) do host:destroy() end
    self.hosts = {}

    if self.initialised then
        require("src.framework.bindings.enet").lib.enet_deinitialize()
        self.initialised = false
    end
end

return Registry