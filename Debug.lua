-- LootWishlist Debug Module
-- DevTool integration and runtime inspection

local _, ns = ...

local print, tostring, type, pairs = print, tostring, type, pairs
local date = date

-------------------------------------------------------------------------------
-- Debug Module
-------------------------------------------------------------------------------

ns.Debug = {}

-- Categories for log filtering
local CATEGORIES = {
    state = true,
    event = true,
    cache = true,
    loot = true,
    ui = true,
    data = true,
}

-- Check if debug mode is enabled
local function IsDebugEnabled()
    return ns.db and ns.db.settings and ns.db.settings.debugEnabled
end

-- Check if DevTool addon is available
local function HasDevTool()
    return DevTool and DevTool.AddData
end

-- Format a value for chat output
local function FormatValue(data)
    local t = type(data)
    if t == "table" then
        local count = 0
        local parts = {}
        local tinsert = table.insert
        for k, v in pairs(data) do
            count = count + 1
            if count <= 4 then
                tinsert(parts, tostring(k) .. "=" .. tostring(v))
            end
        end
        if count > 4 then
            return "{" .. table.concat(parts, ", ") .. ", ...(" .. count .. " keys)}"
        elseif count > 0 then
            return "{" .. table.concat(parts, ", ") .. "}"
        else
            return "{}"
        end
    elseif t == "string" then
        if #data > 80 then
            return '"' .. data:sub(1, 80) .. '..."'
        end
        return '"' .. data .. '"'
    else
        return tostring(data)
    end
end

-- Public check for guarding expensive debug string construction
function ns.Debug:IsEnabled()
    return IsDebugEnabled()
end

-- Log a debug message (only when debug mode is on)
function ns.Debug:Log(category, label, data)
    if not IsDebugEnabled() then return end
    if category and not CATEGORIES[category] then return end

    local prefix = "|cff888888[LW:" .. (category or "?") .. "]|r "
    local timestamp = date("%H:%M:%S")

    if HasDevTool() then
        DevTool:AddData(data, "LW " .. timestamp .. " " .. label)
    end

    if data ~= nil then
        print(prefix .. label .. " = " .. FormatValue(data))
    else
        print(prefix .. label)
    end
end

-- Inspect data on-demand (always sends to DevTool, regardless of debug flag)
function ns.Debug:Inspect(label, data)
    if HasDevTool() then
        DevTool:AddData(data, "LW Inspect: " .. label)
        print(ns.Constants.CHAT_PREFIX .. "Sent |cff00ff00" .. label .. "|r to DevTool.")
    else
        print(ns.Constants.CHAT_PREFIX .. "DevTool not installed. Value: " .. FormatValue(data))
    end
end

-- Toggle debug mode
function ns.Debug:Toggle()
    if not ns.db or not ns.db.settings then
        print(ns.Constants.CHAT_PREFIX .. "Database not initialized.")
        return
    end

    ns.db.settings.debugEnabled = not ns.db.settings.debugEnabled
    local state = ns.db.settings.debugEnabled and "|cff00ff00ON|r" or "|cffff0000OFF|r"
    print(ns.Constants.CHAT_PREFIX .. "Debug mode " .. state)

    if ns.db.settings.debugEnabled and HasDevTool() then
        print(ns.Constants.CHAT_PREFIX .. "DevTool detected - logs will appear in DevTool panel.")
    end
end
