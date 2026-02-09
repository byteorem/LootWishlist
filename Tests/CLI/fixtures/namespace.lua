-- Namespace setup for CLI testing
-- Creates the ns namespace and loads Constants.lua

-- Create the addon namespace
ns = {}

-- Get the project root (Tests/CLI/fixtures -> project root)
local scriptDir = debug.getinfo(1, "S").source:match("@(.*/)")
if not scriptDir then scriptDir = "./" end
local projectRoot = scriptDir .. "../../../"

-- Load Constants.lua (provides ns.Constants)
local chunk = loadfile(projectRoot .. "Constants.lua")
if chunk then
    chunk("LootWishlist", ns)
end

-- Initialize browser state (tests will override as needed)
ns.browserState = {
    expansion = 1,
    instanceType = "raid",
    selectedInstance = nil,
    classFilter = 0,
    selectedDifficultyID = 14,
    selectedDifficultyIndex = 1,
    lastRaidDifficultyID = nil,
    lastDungeonDifficultyID = nil,
    slotFilter = "ALL",
    searchText = "",
    equipmentOnlyFilter = false,
}

-- Initialize browser cache
ns.BrowserCache = {
    version = 0,
    loadingState = "idle",
    bosses = {},
    searchIndex = {},
    instanceID = nil,
    classFilter = nil,
    difficultyID = nil,
    expansion = nil,
    instanceName = "",
}

-- Stub dependencies that ItemBrowser.lua needs at load time
ns.Data = {
    EnsureEJLoaded = function() return true end,
    SuppressEJEvents = function() end,
    RestoreEJEvents = function() end,
    _instanceInfo = {},
}

ns.StaticData = {
    tiers = {},
    instances = {},
}

ns.Debug = {
    Log = function() end,
}

ns.State = {
    Subscribe = function() return {} end,
    Unsubscribe = function() end,
}

ns.StateEvents = {
    ITEMS_CHANGED = "ITEMS_CHANGED",
}

ns.UI = {
    CreateBackground = function() end,
    CreateTitleBar = function(frame, title)
        local titleBar = CreateFrame("Frame", nil, frame)
        titleBar.closeBtn = CreateFrame("Button", nil, titleBar)
        return titleBar
    end,
    CreateModernDropdown = function(parent, width)
        local dropdown = CreateFrame("Frame", nil, parent)
        dropdown.width = width
        function dropdown:SetupMenu(fn) self.menuSetup = fn end
        function dropdown:SetDefaultText(text) self.defaultText = text end
        function dropdown:OverrideText(text) self.text = text end
        function dropdown:SetEnabled(enabled) self.enabled = enabled end
        return dropdown
    end,
    CreateSearchBox = function(parent, width, height)
        local box = CreateFrame("Frame", nil, parent)
        box:SetSize(width, height)
        return box
    end,
    InitInstanceScrollBoxRow = function() end,
    ResetInstanceScrollBoxRow = function() end,
    SetupInstanceRow = function() end,
    InitBrowserScrollBoxRow = function() end,
    ResetBrowserScrollBoxRow = function() end,
    SetupBrowserBossRow = function() end,
    SetupBrowserLootRow = function() end,
    GetBrowserRowExtent = function() return 24 end,
    SetGradient = function() end,
}

-- Stub functions called by ItemBrowser
function ns:GetTiers()
    return {{id = 1, name = "Test Tier"}}
end

function ns:GetInstancesForTier(tierID, isRaid)
    return {}
end

function ns:GetDifficultiesForInstance(instanceID)
    return {{id = 14, name = "Normal"}}
end

function ns:GetInstanceInfo(instanceID)
    return {shouldDisplayDifficulty = true}
end

function ns:IsItemOnWishlistWithSource(itemID, sourceText)
    return false
end

function ns:AddItemToWishlist(itemID, name, sourceText, link)
    return true
end

function ns:RefreshMainWindow() end

-- Settings stub
ns.db = {
    settings = {
        browserSize = 1,
    },
}
