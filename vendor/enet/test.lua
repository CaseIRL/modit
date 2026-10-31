local registry = require("src.framework.network.network_registry").new()
local server = registry:add({ port = 30120 })
local client, peer = registry:add({}), nil
peer = client:connect("127.0.0.1", 30120)

for _ = 1, 100 do
    for _, ev in ipairs(server:poll()) do
        print("server:", ev.type, ev.peer)
        if ev.type == "connect" then server:send(ev.peer, "events", { hello = "world" }) end
    end
    for _, ev in ipairs(client:poll()) do
        print("client:", ev.type, ev.peer, ev.data and ev.data.hello)
    end
end

registry:cleanup()