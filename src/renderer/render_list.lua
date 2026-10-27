--- @class RenderList
--- @file src/graphics/render_list.lua
--- @description Draw list per scene.
--[[
    Notes:    

    Shapes, text and images all register here.
    World objects (space = "world") draw first inside the scene's camera, then screen objects.
    Each pass is sorted by (layer, creation order), re-sorted only when something changes.
]]

--- @section Helpers

local function by_layer(a, b)
    local a_rank = a.space == "world" and 0 or 1
    local b_rank = b.space == "world" and 0 or 1
    if a_rank ~= b_rank then
        return a_rank < b_rank
    end
    if a.layer ~= b.layer then
        return a.layer < b.layer
    end
    return a.order < b.order
end

--- @section Constructor

local RenderList = {}
RenderList.__index = RenderList

--- Creates a new draw list instance.
--- @return table RenderList instance
function RenderList.new()
    local self = setmetatable({}, RenderList)
    self.scenes = {}
    self.seq = 0
    self.active_scene = "default"
    return self
end

local function get_list(self, scene_name)
    local list = self.scenes[scene_name]
    if not list then
        list = { items = {}, dirty = false }
        self.scenes[scene_name] = list
    end
    return list
end

--- Sets the scene that set_camera applies to.
--- @param scene_name string
function RenderList:set_active_scene(scene_name)
    self.active_scene = scene_name or "default"
end

--- Sets (or clears, with nil) the camera used for world objects in a scene.
--- @param camera table|nil Camera from renderer.camera
--- @param scene_name string|nil defaults to the active scene
function RenderList:set_camera(camera, scene_name)
    get_list(self, scene_name or self.active_scene).camera = camera
end

--- @section Methods

--- Registers an object. It needs obj.layer, obj.active and obj:render().
--- @param scene_name string
--- @param obj table
function RenderList:add(scene_name, obj)
    local list = get_list(self, scene_name)
    self.seq = self.seq + 1
    obj.order = self.seq
    obj.removed = false

    list.items[#list.items + 1] = obj
    list.dirty = true
end

--- Flags an object as removed, it is dropped on the next draw.
--- @param scene_name string
--- @param obj table
function RenderList:remove(scene_name, obj)
    obj.removed = true
    local list = self.scenes[scene_name]
    if list then
        list.dirty = true
    end
end

--- Call after changing an objects layer.
--- @param scene_name string
function RenderList:touch(scene_name)
    local list = self.scenes[scene_name]
    if list then
        list.dirty = true
    end
end

--- Drops every object in a scene.
--- @param scene_name string
function RenderList:clear(scene_name)
    self.scenes[scene_name] = nil
end

--- Draws a scenes objects back to front.
--- @param scene_name string
function RenderList:draw(scene_name)
    local list = self.scenes[scene_name]
    if not list then return end

    local items = list.items

    if list.dirty then
        local count = #items
        local kept = 0
        for i = 1, count do
            local obj = items[i]
            if not obj.removed then
                kept = kept + 1
                items[kept] = obj
            end
        end
        for i = kept + 1, count do
            items[i] = nil
        end

        table.sort(items, by_layer)
        list.dirty = false
    end

    -- World objects sort first, so the camera mode begins and ends once.
    local camera = list.camera
    local in_world = false
    for i = 1, #items do
        local obj = items[i]
        if obj.active then
            if camera then
                local is_world = obj.space == "world"
                if is_world ~= in_world then
                    if is_world then camera:begin_mode() else camera:end_mode() end
                    in_world = is_world
                end
            end
            obj:render()
        end
    end
    if in_world then
        camera:end_mode()
    end
end

return RenderList