-- LootWishlist State Management
-- Centralized pub/sub pattern for UI updates

local addonName, ns = ...

-------------------------------------------------------------------------------
-- State Events
-------------------------------------------------------------------------------

ns.StateEvents = {
    WISHLIST_CHANGED = "WISHLIST_CHANGED",     -- Wishlist created/renamed/deleted
    ITEMS_CHANGED = "ITEMS_CHANGED",           -- Item added/removed from wishlist
    ITEM_COLLECTED = "ITEM_COLLECTED",         -- Item marked as collected
    BROWSER_STATE_CHANGED = "BROWSER_STATE_CHANGED", -- Browser filter/selection changed
}

-------------------------------------------------------------------------------
-- State Manager
-------------------------------------------------------------------------------

ns.State = {
    listeners = {},
}

-------------------------------------------------------------------------------
-- Notification Guidelines
-------------------------------------------------------------------------------
-- Notify(event, data):
--   Use for immediate, single-shot notifications where UI must update instantly.
--   Examples: item collected, wishlist switched, single item removed.
--
-- ThrottledNotify(event, data, delay):
--   Use when rapid successive updates are expected (e.g., bulk operations,
--   rapid user input). Batches notifications within the delay window (default 0.1s).
--   Only the last notification in the window fires.
--   Examples: search text changes, bulk item additions, rapid checkbox toggling.
-------------------------------------------------------------------------------

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

    for _, callback in pairs(self.listeners[event]) do
        -- Protected call to prevent one bad listener from breaking others
        pcall(callback, data)
    end
end

-------------------------------------------------------------------------------
-- Throttled Notifications (Phase 3.2)
-------------------------------------------------------------------------------

local refreshTimers = {}

-- Notify with throttling to batch rapid updates
function ns.State:ThrottledNotify(event, data, delay)
    delay = delay or 0.1

    -- If timer already pending for this event, skip (will use existing timer)
    if refreshTimers[event] then return end

    refreshTimers[event] = C_Timer.After(delay, function()
        refreshTimers[event] = nil
        self:Notify(event, data)
    end)
end
