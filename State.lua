-- LootWishlist State Management
-- Centralized pub/sub pattern for UI updates

local addonName, ns = ...

local debugstack = debugstack

local function errorHandler(err)
    return err .. "\n" .. debugstack(2, 20, 0)
end

-------------------------------------------------------------------------------
-- State Events
-------------------------------------------------------------------------------

ns.StateEvents = {
    ITEMS_CHANGED = "ITEMS_CHANGED",           -- Item added/removed from wishlist
    ITEM_COLLECTED = "ITEM_COLLECTED",         -- Item marked as collected
}

-------------------------------------------------------------------------------
-- State Manager
-------------------------------------------------------------------------------

ns.State = {
    listeners = {},
}

-- Subscribe to a state event
-- Returns a handle that can be used to unsubscribe
function ns.State:Subscribe(event, callback)
    if not self.listeners[event] then
        self.listeners[event] = {}
    end

    local handle = {}
    self.listeners[event][handle] = callback
    return handle
end

-- Unsubscribe from a state event
function ns.State:Unsubscribe(event, handle)
    if self.listeners[event] then
        self.listeners[event][handle] = nil
    end
end

-- Notify all subscribers of an event
function ns.State:Notify(event, data)
    if not self.listeners[event] then return end

    if ns.Debug and ns.Debug:IsEnabled() then
        ns.Debug:Log("state", "State: " .. event, data)
    end

    for _, callback in pairs(self.listeners[event]) do
        -- Protected call with stack trace to prevent one bad listener from breaking others
        local ok, err = xpcall(callback, errorHandler, data)
        if not ok then
            if ns.Debug then
                ns.Debug:Log("state", "State callback error: " .. tostring(err))
            end
        end
    end
end
