-- CLI Test Mock Initialization
-- Loads all mocks in correct order before addon code

-- Determine the base path for mock files
-- This handles both direct dofile() and require() scenarios
local function getScriptDir()
    local info = debug.getinfo(1, "S")
    if info and info.source then
        local path = info.source:match("@(.*/)")
        if path then return path end
    end
    -- Fallback: assume running from project root
    return "Tests/CLI/mocks/"
end

local scriptDir = getScriptDir()

-- Load mocks in dependency order
dofile(scriptDir .. "globals.lua")
dofile(scriptDir .. "wow_utilities.lua")
dofile(scriptDir .. "enums.lua")
dofile(scriptDir .. "frames.lua")
