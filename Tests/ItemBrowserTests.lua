-- WoWUnit Adapter for Shared Item Browser Tests
-- Thin wrapper that maps shared tests to WoWUnit assertions

local _, ns = ...

if not WoWUnit then return end

local suite = WoWUnit('LootWishlist')

local T = {
    IsTrue = function(val) WoWUnit.IsTrue(val) end,
    IsFalse = function(val) WoWUnit.IsFalse(val) end,
    AreEqual = function(expected, actual) WoWUnit.AreEqual(expected, actual) end,
}

local tests = ns._sharedTests.ItemBrowser(T)

-- Suppress ns.Debug:Log during tests to avoid chat spam
local originalLog = ns.Debug.Log
local noop = function() end

for name, fn in pairs(tests) do
    suite[name] = function()
        ns.Debug.Log = noop
        fn()
        ns.Debug.Log = originalLog
    end
end
