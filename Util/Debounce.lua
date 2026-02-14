-- LootWishlist Debounce/Throttle Utilities
-- Timer-based flow control using C_Timer

local _, ns = ...

local C_Timer = C_Timer

---@param fn function The function to debounce
---@param delay number Delay in seconds
---@return function debounced A function that delays execution until `delay` seconds after the last call
function ns.Debounce(fn, delay)
    local timer = nil
    return function(...)
        if timer then
            timer:Cancel()
        end
        local args = {...}
        timer = C_Timer.NewTimer(delay, function()
            timer = nil
            fn(unpack(args))
        end)
    end
end

---@param fn function The function to throttle
---@param interval number Minimum interval in seconds between executions
---@return function throttled A function that executes at most once per `interval` seconds
function ns.Throttle(fn, interval)
    local lastCall = 0
    local pending = nil
    return function(...)
        local now = GetTime()
        if now - lastCall >= interval then
            lastCall = now
            fn(...)
        else
            -- Schedule trailing call
            if pending then
                pending:Cancel()
            end
            local args = {...}
            pending = C_Timer.NewTimer(interval - (now - lastCall), function()
                pending = nil
                lastCall = GetTime()
                fn(unpack(args))
            end)
        end
    end
end
