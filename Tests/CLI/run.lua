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

-- Load ItemBrowser.lua (ns._test is now unconditionally exposed)
print("Loading ItemBrowser.lua...")
local chunk = loadfile(projectRoot .. "UI/ItemBrowser.lua")
if not chunk then
    print("[ERROR] Failed to load UI/ItemBrowser.lua")
    os.exit(1)
end
chunk("LootWishlist", ns)

-- Load shared test definitions
print("Loading shared tests...")
local sharedChunk = loadfile(projectRoot .. "Tests/SharedTests/ItemBrowserTests.lua")
if not sharedChunk then
    print("[ERROR] Failed to load Tests/SharedTests/ItemBrowserTests.lua")
    os.exit(1)
end
sharedChunk("LootWishlist", ns)

-- Build CLI assertion adapter (maps to assert())
local T = {
    IsTrue = function(val, msg) assert(val, msg) end,
    IsFalse = function(val, msg) assert(not val, msg) end,
    AreEqual = function(expected, actual, msg) assert(expected == actual, msg) end,
}

-- Get test table from shared definitions
local tests = ns._sharedTests.ItemBrowser(T)

print("")
print("Running tests...")
print("----------------")

local passed, failed = 0, 0
local failures = {}

-- Collect and sort test names for deterministic order
local testNames = {}
for name, fn in pairs(tests) do
    if type(fn) == "function" then
        table.insert(testNames, name)
    end
end
table.sort(testNames)

-- Run tests in sorted order
for _, name in ipairs(testNames) do
    local testFn = tests[name]
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
