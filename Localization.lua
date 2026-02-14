-- LootWishlist Localization
-- Metatable fallback pattern: ns.L["key"] returns key if no translation exists
-- This enables community translations without requiring all strings upfront

local _, ns = ...

ns.L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
