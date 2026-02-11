#!/usr/bin/env lua
-- StaticData Structure Test Runner
-- Run from project root: lua5.1 Tests/CLI/run_staticdata.lua

-- Determine script directory for relative paths
local scriptPath = debug.getinfo(1, "S").source:match("@(.*/)")
if not scriptPath then
    scriptPath = "Tests/CLI/"
end

local projectRoot = scriptPath:gsub("Tests/CLI/$", "")
if projectRoot == "" then projectRoot = "./" end

print("LootWishlist StaticData Test Runner")
print("====================================")
print("")

-- Create minimal namespace (no mocks needed)
local ns = {}

-- Load real StaticData.lua
print("Loading Data/StaticData.lua...")
local chunk, err = loadfile(projectRoot .. "Data/StaticData.lua")
if not chunk then
    print("[ERROR] Failed to load Data/StaticData.lua: " .. tostring(err))
    os.exit(1)
end
chunk("LootWishlist", ns)

if not ns.StaticData then
    print("[ERROR] ns.StaticData not set after loading StaticData.lua")
    os.exit(1)
end

-- Load test definitions
print("Loading StaticData tests...")
local RegisterTests = dofile(scriptPath .. "tests/StaticDataTests.lua")

-- Build CLI assertion adapter
local T = {
    IsTrue = function(val, msg) assert(val, msg) end,
    IsFalse = function(val, msg) assert(not val, msg) end,
    AreEqual = function(expected, actual, msg)
        assert(expected == actual,
            (msg or "") .. " (expected: " .. tostring(expected) .. ", got: " .. tostring(actual) .. ")")
    end,
}

local tests = RegisterTests(T, ns, projectRoot)

print("")
print("Running tests...")
print("----------------")

local passed, failed = 0, 0
local failures = {}

-- Collect and sort test names for deterministic order
local testNames = {}
for name, fn in pairs(tests) do
    if type(fn) == "function" then
        testNames[#testNames + 1] = name
    end
end
table.sort(testNames)

-- Run tests in sorted order
for _, name in ipairs(testNames) do
    local ok, testErr = pcall(tests[name])
    if ok then
        passed = passed + 1
        print("[PASS] " .. name)
    else
        failed = failed + 1
        print("[FAIL] " .. name .. ": " .. tostring(testErr))
        failures[#failures + 1] = {name = name, error = testErr}
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
