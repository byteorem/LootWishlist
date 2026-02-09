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

-- Load ItemBrowser.lua to get ns.BrowserFilter and expose test functions
print("Loading ItemBrowser.lua...")
local chunk = loadfile(projectRoot .. "UI/ItemBrowser.lua")
if not chunk then
    print("[ERROR] Failed to load UI/ItemBrowser.lua")
    os.exit(1)
end
chunk("LootWishlist", ns)

-- Expose internal functions for testing (mimic WoWUnit exposure pattern)
-- These are normally only exposed when WoWUnit is present, so we need to
-- manually extract them from the file's local scope
if not ns._test then
    ns._test = {}
end

-- The IsCacheValid, InvalidateCache, and BuildSearchIndexEntry functions are
-- local to ItemBrowser.lua and only exposed when WoWUnit is present.
-- Since WoWUnit is nil in CLI, we need to recreate them here using the same logic.

-- IsCacheValid: checks if cache matches current state
ns._test.IsCacheValid = function()
    local state = ns.browserState
    local cache = ns.BrowserCache

    return cache.loadingState == "ready"
       and cache.instanceID == state.selectedInstance
       and cache.classFilter == state.classFilter
       and cache.difficultyID == state.selectedDifficultyID
       and cache.expansion == state.expansion
end

-- InvalidateCache: resets cache to idle state
ns._test.InvalidateCache = function()
    local cache = ns.BrowserCache
    cache.version = cache.version + 1
    cache.instanceID = nil
    cache.classFilter = nil
    cache.difficultyID = nil
    cache.expansion = nil
    cache.instanceName = ""
    wipe(cache.bosses)
    wipe(cache.searchIndex)
    cache.loadingState = "idle"
end

-- BuildSearchIndexEntry: builds N-gram prefix tree for search
ns._test.BuildSearchIndexEntry = function(searchIndex, itemKey, searchable)
    local lowerSearchable = searchable:lower()
    local maxLen = math.min(#lowerSearchable, ns.Constants.MAX_NGRAM_PREFIX_LENGTH)
    for i = 1, maxLen do
        local prefix = lowerSearchable:sub(1, i)
        if not searchIndex[prefix] then
            searchIndex[prefix] = {}
        end
        searchIndex[prefix][itemKey] = true
    end
end

-- Load and run test suite
print("Loading test suite...")
local tests = dofile(scriptPath .. "suites/item_browser_test.lua")

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
    local ok, err = pcall(testFn, tests)
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
