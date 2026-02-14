#!/usr/bin/env lua
-- CLI Test Runner for LootWishlist
-- Run from project root: lua5.1 Tests/CLI/run.lua

-- Determine script directory for relative paths
local scriptPath = debug.getinfo(1, "S").source:match("@(.*/)")
if not scriptPath then
    -- Running from project root
    scriptPath = "Tests/CLI/"
end

-- Change to project root if needed
local projectRoot = scriptPath:gsub("Tests/CLI/$", "")
if projectRoot == "" then projectRoot = "./" end

print("LootWishlist CLI Test Runner")
print("============================")
print("")

-- Load mocks FIRST (before any addon code)
print("Loading mocks...")
dofile(scriptPath .. "mocks/init.lua")

-- Load namespace setup (creates ns, loads Constants.lua)
print("Loading namespace fixtures...")
dofile(scriptPath .. "fixtures/namespace.lua")

-- Load addon source files needed for tests
print("Loading addon source files...")

local function loadAddonFile(path, label)
    local chunk = loadfile(projectRoot .. path)
    if not chunk then
        print("[ERROR] Failed to load " .. path)
        os.exit(1)
    end
    chunk("LootWishlist", ns)
end

-- Load core files in dependency order
loadAddonFile("Core/Database.lua", "Database")
loadAddonFile("Core/ItemCache.lua", "ItemCache")
loadAddonFile("Core/WishlistIndex.lua", "WishlistIndex")
loadAddonFile("Core/WishlistManager.lua", "WishlistManager")
loadAddonFile("UI/ItemBrowser.lua", "ItemBrowser")

-- Load shared test definitions
print("Loading shared tests...")
loadAddonFile("Tests/SharedTests/ItemBrowserTests.lua", "ItemBrowserTests")
loadAddonFile("Tests/SharedTests/WishlistTests.lua", "WishlistTests")
loadAddonFile("Tests/SharedTests/DatabaseTests.lua", "DatabaseTests")

-- Build CLI assertion adapter (maps to assert())
local T = {
    IsTrue = function(val, msg) assert(val, msg) end,
    IsFalse = function(val, msg) assert(not val, msg) end,
    AreEqual = function(expected, actual, msg)
        assert(expected == actual,
            (msg or "AreEqual") .. " (expected: " .. tostring(expected) .. ", got: " .. tostring(actual) .. ")")
    end,
}

-- Collect all test suites
local allTests = {}
local suiteNames = {"ItemBrowser", "Wishlist", "Database"}

for _, suiteName in ipairs(suiteNames) do
    if ns._sharedTests[suiteName] then
        local tests = ns._sharedTests[suiteName](T)
        for name, fn in pairs(tests) do
            if type(fn) == "function" then
                allTests[suiteName .. "." .. name] = fn
            end
        end
    end
end

print("")
print("Running tests...")
print("----------------")

local passed, failed = 0, 0
local failures = {}

-- Collect and sort test names for deterministic order
local testNames = {}
for name in pairs(allTests) do
    table.insert(testNames, name)
end
table.sort(testNames)

-- Run tests in sorted order
for _, name in ipairs(testNames) do
    local testFn = allTests[name]
    local ok, err = pcall(testFn)
    if ok then
        passed = passed + 1
        print("[PASS] " .. name)
    else
        failed = failed + 1
        print("[FAIL] " .. name .. ": " .. tostring(err))
        table.insert(failures, {name = name, error = err})
    end
end

print("")
print("================")
print(string.format("Results: %d passed, %d failed", passed, failed))

if #failures > 0 then
    print("")
    print("Failures:")
    for _, f in ipairs(failures) do
        print("  - " .. f.name .. ": " .. tostring(f.error))
    end
end

os.exit(failed > 0 and 1 or 0)
