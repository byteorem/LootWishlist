-- LootWishlist Item Browser
-- Two-panel browser for instance loot
-- Architecture: Data Cache → Filter → Render

local addonName, ns = ...

-- Cache global functions
local pairs, ipairs, type, math = pairs, ipairs, type, math
local wipe, tinsert = wipe, table.insert
local CreateFrame, CreateFramePool = CreateFrame, CreateFramePool
local C_Timer, C_EncounterJournal, C_Item, C_ChallengeMode = C_Timer, C_EncounterJournal, C_Item, C_ChallengeMode
local UIDropDownMenu_Initialize, UIDropDownMenu_CreateInfo, UIDropDownMenu_AddButton, UIDropDownMenu_SetText = UIDropDownMenu_Initialize, UIDropDownMenu_CreateInfo, UIDropDownMenu_AddButton, UIDropDownMenu_SetText
local UnitClass = UnitClass
local GameTooltip = GameTooltip
local CreateDataProvider, CreateScrollBoxListLinearView, ScrollUtil = CreateDataProvider, CreateScrollBoxListLinearView, ScrollUtil

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

-- Size presets for Normal and Large modes
local SIZE_PRESETS = {
    [1] = {  -- Normal (current)
        width = 600, height = 500, leftPanel = 140,
        instanceRowHeight = 24, bossRowHeight = 28, lootRowHeight = 22,
        lootIconSize = 18,
        lootNameFont = "GameFontHighlightSmall",
        lootSlotFont = "GameFontNormalSmall",
        instanceFont = "GameFontNormalSmall",
        bossFont = "GameFontNormal",
        searchWidth = 150,
        typeDropdown = 100,
        expDropdown = 140,
        classDropdown = 120,
        slotDropdown = 100,
        diffDropdown = 100,
    },
    [2] = {  -- Large
        width = 750, height = 625, leftPanel = 175,
        instanceRowHeight = 30, bossRowHeight = 34, lootRowHeight = 28,
        lootIconSize = 24,
        lootNameFont = "GameFontNormal",
        lootSlotFont = "GameFontNormal",
        instanceFont = "GameFontNormal",
        bossFont = "GameFontNormalLarge",
        searchWidth = 175,
        typeDropdown = 120,
        expDropdown = 170,
        classDropdown = 145,
        slotDropdown = 120,
        diffDropdown = 120,
    },
}

local function GetBrowserDimensions()
    local sizeID = ns.db and ns.db.settings and ns.db.settings.browserSize or 1
    return SIZE_PRESETS[sizeID] or SIZE_PRESETS[1]
end

-- Get expansion tiers from static data (ns:GetTiers from Data/Loader.lua)
local function GetExpansionTiers()
    return ns:GetTiers()
end

-- Class data for dropdown
local CLASS_DATA = {
    {id = 0, name = "All Classes"},
    {id = 1, name = "Warrior"},
    {id = 2, name = "Paladin"},
    {id = 3, name = "Hunter"},
    {id = 4, name = "Rogue"},
    {id = 5, name = "Priest"},
    {id = 6, name = "Death Knight"},
    {id = 7, name = "Shaman"},
    {id = 8, name = "Mage"},
    {id = 9, name = "Warlock"},
    {id = 10, name = "Monk"},
    {id = 11, name = "Druid"},
    {id = 12, name = "Demon Hunter"},
    {id = 13, name = "Evoker"},
}

-- Slot data for filtering
local SLOT_DATA = {
    {id = "ALL", name = "All Slots"},
    {id = "INVTYPE_HEAD", name = "Head"},
    {id = "INVTYPE_NECK", name = "Neck"},
    {id = "INVTYPE_SHOULDER", name = "Shoulder"},
    {id = "INVTYPE_CLOAK", name = "Back"},
    {id = "INVTYPE_CHEST", name = "Chest"},
    {id = "INVTYPE_ROBE", name = "Chest"},  -- Robes count as chest
    {id = "INVTYPE_WRIST", name = "Wrist"},
    {id = "INVTYPE_HAND", name = "Hands"},
    {id = "INVTYPE_WAIST", name = "Waist"},
    {id = "INVTYPE_LEGS", name = "Legs"},
    {id = "INVTYPE_FEET", name = "Feet"},
    {id = "INVTYPE_FINGER", name = "Ring"},
    {id = "INVTYPE_TRINKET", name = "Trinket"},
    {id = "WEAPON", name = "Weapons"},
}

-- Unique slots for dropdown display (no duplicates)
local SLOT_DROPDOWN_OPTIONS = {
    {id = "ALL", name = "All Slots"},
    {id = "INVTYPE_HEAD", name = "Head"},
    {id = "INVTYPE_NECK", name = "Neck"},
    {id = "INVTYPE_SHOULDER", name = "Shoulder"},
    {id = "INVTYPE_CLOAK", name = "Back"},
    {id = "INVTYPE_CHEST", name = "Chest"},
    {id = "INVTYPE_WRIST", name = "Wrist"},
    {id = "INVTYPE_HAND", name = "Hands"},
    {id = "INVTYPE_WAIST", name = "Waist"},
    {id = "INVTYPE_LEGS", name = "Legs"},
    {id = "INVTYPE_FEET", name = "Feet"},
    {id = "INVTYPE_FINGER", name = "Ring"},
    {id = "INVTYPE_TRINKET", name = "Trinket"},
    {id = "WEAPON", name = "Weapons"},
}

-------------------------------------------------------------------------------
-- Browser State (unified on namespace)
-------------------------------------------------------------------------------

ns.browserState = {
    -- Data source filters (invalidate cache when changed)
    expansion = nil,
    instanceType = "raid",
    selectedInstance = nil,
    classFilter = 0,
    selectedDifficultyID = nil,
    selectedDifficultyIndex = nil,
    selectedTrack = nil,
    currentSeasonFilter = false,

    -- Client-side filters (don't invalidate cache)
    slotFilter = "ALL",
    searchText = "",

    -- UI state
    expandedBosses = {},
}

-------------------------------------------------------------------------------
-- Data Cache Layer
-------------------------------------------------------------------------------

ns.BrowserCache = {
    -- Cache key fields (must match to be valid)
    instanceID = nil,
    classFilter = nil,
    difficultyID = nil,
    expansion = nil,
    currentSeasonFilter = false,

    -- Version for race condition safety
    version = 0,

    -- Cached data
    instanceName = "",
    bosses = {},       -- Array: {bossID, name, loot = {lootInfo...}}

    -- Loading state: "idle" | "loading" | "ready"
    loadingState = "idle",

    -- Search index (N-gram prefix tree)
    searchIndex = {},
}

-- Get instance name from static data
local function GetCachedInstanceName(instanceID)
    local info = ns:GetInstanceInfo(instanceID)
    return info and info.name or ""
end

-- Check if cache is valid for current state
local function IsCacheValid()
    local state = ns.browserState
    local cache = ns.BrowserCache

    return cache.loadingState == "ready"
       and cache.instanceID == state.selectedInstance
       and cache.classFilter == state.classFilter
       and cache.difficultyID == state.selectedDifficultyID
       and cache.expansion == state.expansion
       and cache.currentSeasonFilter == state.currentSeasonFilter
end

-- Invalidate cache (called when data filters change)
local function InvalidateCache()
    local cache = ns.BrowserCache
    cache.version = cache.version + 1
    cache.instanceID = nil
    cache.classFilter = nil
    cache.difficultyID = nil
    cache.expansion = nil
    cache.currentSeasonFilter = false
    cache.instanceName = ""
    wipe(cache.bosses)
    wipe(cache.searchIndex)
    cache.loadingState = "idle"
end

-- Build search index entry for an item (N-gram prefix tree)
local function BuildSearchIndexEntry(searchIndex, itemKey, searchable)
    local lowerSearchable = searchable:lower()
    local prefix = ""
    local maxLen = math.min(#lowerSearchable, 20)
    for i = 1, maxLen do
        prefix = prefix .. lowerSearchable:sub(i, i)
        if not searchIndex[prefix] then
            searchIndex[prefix] = {}
        end
        searchIndex[prefix][itemKey] = true
    end
end

-- Cache instance data using Encounter Journal API for proper class/difficulty filtering
local function CacheInstanceData(onComplete)
    local state = ns.browserState
    local cache = ns.BrowserCache

    if not state.selectedInstance then
        InvalidateCache()
        if onComplete then onComplete(false) end
        return
    end

    -- Mark loading state and capture version for race condition check
    cache.loadingState = "loading"
    local cacheVersion = cache.version

    local instanceName = GetCachedInstanceName(state.selectedInstance)

    -- Set up EJ API filters before loading items
    -- Class filter: 0 = all classes, else specific class ID
    local classID = state.classFilter > 0 and state.classFilter or 0
    EJ_SetLootFilter(classID, 0)  -- 0 = all specs

    -- Select instance and set difficulty via EJ API
    EJ_SelectInstance(state.selectedInstance)
    if state.selectedDifficultyID then
        EJ_SetDifficulty(state.selectedDifficultyID)
    end

    -- Get encounters from static data (for structure/ordering)
    local encounters = ns:GetEncountersForInstance(state.selectedInstance)

    -- Collect all items from EJ API
    local bosses = {}
    local searchIndex = {}

    for _, encounter in ipairs(encounters) do
        -- Select encounter in EJ API to get its loot
        EJ_SelectEncounter(encounter.id)

        local lootList = {}
        local numLoot = EJ_GetNumLoot()

        for lootIndex = 1, numLoot do
            local info = C_EncounterJournal.GetLootInfoByIndex(lootIndex)
            if info and info.itemID then
                -- EJ API returns properly filtered items with correct difficulty links
                local lootEntry = {
                    itemID = info.itemID,
                    name = info.name or "",
                    icon = info.icon or 134400,
                    slot = info.slot or "",
                    filterType = info.filterType,
                    link = info.link,  -- Has correct bonus IDs for difficulty
                    bossName = encounter.name,
                }
                tinsert(lootList, lootEntry)

                -- Build search index
                local itemKey = info.itemID .. "_" .. encounter.id
                if info.name and info.name ~= "" then
                    BuildSearchIndexEntry(searchIndex, itemKey, info.name)
                end
                BuildSearchIndexEntry(searchIndex, itemKey, encounter.name)
            end
        end

        if #lootList > 0 then
            tinsert(bosses, {
                bossID = encounter.id,
                name = encounter.name,
                loot = lootList,
            })
        end
    end

    -- Reset loot filter when done to not affect other EJ usage
    EJ_ResetLootFilter()

    -- Race condition check: version changed during load
    if cache.version ~= cacheVersion then
        if onComplete then onComplete(false) end
        return
    end

    -- Store in cache
    cache.instanceID = state.selectedInstance
    cache.classFilter = state.classFilter
    cache.difficultyID = state.selectedDifficultyID
    cache.expansion = state.expansion
    cache.currentSeasonFilter = state.currentSeasonFilter
    cache.instanceName = instanceName
    cache.bosses = bosses
    cache.searchIndex = searchIndex
    cache.loadingState = "ready"

    if onComplete then onComplete(true) end
end

-------------------------------------------------------------------------------
-- Filter Layer
-------------------------------------------------------------------------------

ns.BrowserFilter = {}

-- Enum-based slot filter mapping
-- Maps our dropdown IDs to Enum.ItemSlotFilterType values
local SLOT_FILTER_MAP = {
    ["ALL"] = nil,  -- No filter
    ["INVTYPE_HEAD"] = {Enum.ItemSlotFilterType.Head},
    ["INVTYPE_NECK"] = {Enum.ItemSlotFilterType.Neck},
    ["INVTYPE_SHOULDER"] = {Enum.ItemSlotFilterType.Shoulder},
    ["INVTYPE_CLOAK"] = {Enum.ItemSlotFilterType.Back},
    ["INVTYPE_CHEST"] = {Enum.ItemSlotFilterType.Chest},
    ["INVTYPE_ROBE"] = {Enum.ItemSlotFilterType.Chest},
    ["INVTYPE_WRIST"] = {Enum.ItemSlotFilterType.Wrist},
    ["INVTYPE_HAND"] = {Enum.ItemSlotFilterType.Hands},
    ["INVTYPE_WAIST"] = {Enum.ItemSlotFilterType.Waist},
    ["INVTYPE_LEGS"] = {Enum.ItemSlotFilterType.Legs},
    ["INVTYPE_FEET"] = {Enum.ItemSlotFilterType.Feet},
    ["INVTYPE_FINGER"] = {Enum.ItemSlotFilterType.Finger},
    ["INVTYPE_TRINKET"] = {Enum.ItemSlotFilterType.Trinket},
    ["WEAPON"] = {
        Enum.ItemSlotFilterType.MainHand,
        Enum.ItemSlotFilterType.OffHand,
        Enum.ItemSlotFilterType.TwoHand,
        Enum.ItemSlotFilterType.OneHand,
    },
}

-- Check if filterType passes slot filter (enum-based)
function ns.BrowserFilter:PassesSlotFilter(filterType, slotFilter)
    if slotFilter == "ALL" then
        return true
    end

    local allowedTypes = SLOT_FILTER_MAP[slotFilter]
    if not allowedTypes then
        return true  -- Unknown filter, allow all
    end

    -- Check if filterType matches any allowed type
    for _, allowedType in ipairs(allowedTypes) do
        if filterType == allowedType then
            return true
        end
    end

    return false
end

-- Legacy string-based slot filter (fallback for items without filterType)
function ns.BrowserFilter:PassesSlotFilterLegacy(itemSlot, slotFilter)
    if slotFilter == "ALL" then
        return true
    end

    if slotFilter == "WEAPON" then
        return itemSlot:find("Weapon")
            or itemSlot:find("Shield")
            or itemSlot:find("Off Hand")
            or itemSlot:find("Held In Off")
    end

    -- Match slot name from SLOT_DATA
    for _, slotData in ipairs(SLOT_DATA) do
        if slotData.id == slotFilter then
            return itemSlot == slotData.name
        end
    end

    return false
end

-- Check if item passes search filter using indexed lookup
function ns.BrowserFilter:PassesSearchFilter(itemID, bossID, searchText, searchIndex)
    if not searchText or searchText == "" then
        return true
    end

    local searchLower = searchText:lower()

    -- Use search index for O(1) lookup
    if searchIndex and searchIndex[searchLower] then
        -- Check if any key containing this itemID matches
        for itemKey in pairs(searchIndex[searchLower]) do
            if itemKey:find(tostring(itemID)) then
                return true
            end
        end
    end

    return false
end

-- Legacy search filter (fallback for string matching)
function ns.BrowserFilter:PassesSearchFilterLegacy(itemName, bossName, searchText)
    if not searchText or searchText == "" then
        return true
    end
    local searchLower = searchText:lower()
    return (itemName and itemName:lower():find(searchLower, 1, true))
        or (bossName and bossName:lower():find(searchLower, 1, true))
end

-- Get filtered data ready for rendering
function ns.BrowserFilter:GetFilteredData()
    local state = ns.browserState
    local cache = ns.BrowserCache
    local result = {}

    for _, boss in ipairs(cache.bosses) do
        local filteredLoot = {}

        for _, loot in ipairs(boss.loot) do
            -- Use enum-based filter if filterType available, else legacy string
            local passesSlot
            if loot.filterType then
                passesSlot = self:PassesSlotFilter(loot.filterType, state.slotFilter)
            else
                passesSlot = self:PassesSlotFilterLegacy(loot.slot or "", state.slotFilter)
            end

            -- Use indexed search if available, else legacy string match
            local passesSearch
            if cache.searchIndex and next(cache.searchIndex) then
                passesSearch = self:PassesSearchFilter(loot.itemID, boss.bossID, state.searchText, cache.searchIndex)
                -- Fallback to legacy if index miss (in case of partial indexing)
                if not passesSearch and state.searchText ~= "" then
                    passesSearch = self:PassesSearchFilterLegacy(loot.name, boss.name, state.searchText)
                end
            else
                passesSearch = self:PassesSearchFilterLegacy(loot.name, boss.name, state.searchText)
            end

            if passesSlot and passesSearch then
                tinsert(filteredLoot, loot)
            end
        end

        -- Include boss if it has matching items
        if #filteredLoot > 0 then
            tinsert(result, {
                bossID = boss.bossID,
                name = boss.name,
                loot = filteredLoot,
            })
        end
    end

    return result
end

-- Build flattened data for DataProvider from filtered data
function ns.BrowserFilter:BuildRightPanelData(filteredData)
    local data = {}
    local cache = ns.BrowserCache

    for _, bossData in ipairs(filteredData) do
        -- Add boss header row
        tinsert(data, {
            rowType = "boss",
            bossID = bossData.bossID,
            name = bossData.name,
        })

        -- Add loot item rows
        for _, loot in ipairs(bossData.loot) do
            tinsert(data, {
                rowType = "loot",
                itemID = loot.itemID,
                name = loot.name,
                icon = loot.icon,
                slot = loot.slot,
                filterType = loot.filterType,
                link = loot.link,
                bossName = bossData.name,
                instanceName = cache.instanceName,
            })
        end
    end

    return data
end

-------------------------------------------------------------------------------
-- Frame Pools (left panel only - right panel uses ScrollBox)
-------------------------------------------------------------------------------

local instanceRowPool

local function ResetInstanceRow(pool, row)
    row:Hide()
    row:ClearAllPoints()
    row.instanceID = nil
    row:SetScript("OnClick", nil)
end

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

-- M+ season instance IDs cache
local cachedSeasonInstanceIDs = nil

-- Get current M+ season dungeon instance IDs dynamically (cached)
local function GetCurrentSeasonInstanceIDs()
    if cachedSeasonInstanceIDs then
        return cachedSeasonInstanceIDs
    end

    local instanceIDs = {}
    local mapTable = C_ChallengeMode.GetMapTable()

    if mapTable then
        for _, challengeModeID in ipairs(mapTable) do
            local name, id, timeLimit, texture, bgTexture, mapID = C_ChallengeMode.GetMapUIInfo(challengeModeID)
            if mapID then
                local journalInstanceID = C_EncounterJournal.GetInstanceForGameMap(mapID)
                if journalInstanceID then
                    instanceIDs[journalInstanceID] = true
                end
            end
        end
    end

    cachedSeasonInstanceIDs = instanceIDs
    return instanceIDs
end

-- Invalidate M+ season cache (call on season change)
local function InvalidateSeasonCache()
    cachedSeasonInstanceIDs = nil
end

-- Build difficulty options for current instance from static data
local function GetDifficultyOptionsForInstance(instanceID)
    if not instanceID then return {} end
    return ns:GetDifficultiesForInstance(instanceID)
end

-- Set default difficulty based on available difficulties for selected instance
function ns:SetDefaultDifficulty(state)
    if not state.selectedInstance then
        state.selectedDifficultyIndex = 1
        state.selectedDifficultyID = nil
        state.selectedTrack = "hero"
        return
    end

    local isRaid = (state.instanceType == "raid")
    local difficulties = GetDifficultyOptionsForInstance(state.selectedInstance)

    if #difficulties == 0 then
        state.selectedDifficultyIndex = 1
        state.selectedDifficultyID = nil
        state.selectedTrack = "hero"
        return
    end

    -- Find a good default: prefer Heroic for raids, Mythic for dungeons
    local preferredDiffIDs = isRaid and {15, 14, 16, 17} or {23, 2, 1}

    state.selectedDifficultyIndex = 1
    for _, prefID in ipairs(preferredDiffIDs) do
        for idx, diff in ipairs(difficulties) do
            if diff.id == prefID then
                state.selectedDifficultyIndex = idx
                break
            end
        end
        if state.selectedDifficultyIndex > 1 then break end
    end

    local diff = difficulties[state.selectedDifficultyIndex]
    if diff then
        state.selectedDifficultyID = diff.id
        state.selectedTrack = diff.track
    end
end

-------------------------------------------------------------------------------
-- Render Layer (DataProvider pattern)
-------------------------------------------------------------------------------

-- Render right panel using DataProvider/ScrollBox
local function RenderRightPanel(filteredData)
    local frame = ns.ItemBrowser
    if not frame or not frame.rightScrollBox then return end

    local state = ns.browserState
    local dims = frame.dims

    -- Build flattened data for DataProvider
    local data = ns.BrowserFilter:BuildRightPanelData(filteredData)

    -- Create and set DataProvider
    local dataProvider = CreateDataProvider(data)
    frame.rightScrollBox:SetDataProvider(dataProvider)

    -- Hide loading indicator
    if frame.loadingFrame then frame.loadingFrame:Hide() end

    -- Show/hide "No Items" indicator
    if frame.noItemsFrame then
        frame.noItemsFrame:SetShown(#data == 0)
    end
end

-------------------------------------------------------------------------------
-- Browser UI Creation
-------------------------------------------------------------------------------

function ns:CreateItemBrowser()
    if ns.ItemBrowser then
        ns.ItemBrowser:Show()
        return
    end

    local dims = GetBrowserDimensions()
    local BROWSER_WIDTH = dims.width
    local BROWSER_HEIGHT = dims.height
    local LEFT_PANEL_WIDTH = dims.leftPanel

    local frame = CreateFrame("Frame", "LootWishlistBrowser", UIParent, "BackdropTemplate")
    frame:SetSize(BROWSER_WIDTH, BROWSER_HEIGHT)
    frame.dims = dims

    if ns.MainWindow then
        frame:SetPoint("TOPLEFT", ns.MainWindow, "TOPRIGHT", 5, 0)
    else
        frame:SetPoint("CENTER")
    end

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(90)

    ns.UI:CreateBackground(frame)

    -- Title bar
    local titleBar = ns.UI:CreateTitleBar(frame, "Browse Items")
    frame.titleBar = titleBar

    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    titleBar.closeBtn:HookScript("OnClick", function()
        if ns.MainWindow and ns.MainWindow.browseBtn then
            ns.MainWindow.browseBtn:SetText("Browse")
        end
    end)

    -- Filter row 1: Search, Type, Expansion
    local filterRow1 = CreateFrame("Frame", nil, frame)
    filterRow1:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 10, -10)
    filterRow1:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -10, -10)
    filterRow1:SetHeight(25)

    local searchBox = ns.UI:CreateSearchBox(filterRow1, dims.searchWidth, 20)
    searchBox:SetPoint("LEFT", 8, 2)
    local searchTimer = nil
    searchBox:HookScript("OnTextChanged", function(self)
        if searchTimer then searchTimer:Cancel() end
        searchTimer = C_Timer.NewTimer(0.15, function()
            ns.browserState.searchText = self:GetText()
            -- Search is client-side only, no cache invalidation
            ns:RefreshRightPanel()
            searchTimer = nil
        end)
    end)
    frame.searchBox = searchBox

    local typeLabel = filterRow1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    typeLabel:SetPoint("LEFT", searchBox, "RIGHT", 8, 0)
    typeLabel:SetText("Type:")

    local typeDropdown = ns.UI:CreateDropdown(filterRow1, nil, dims.typeDropdown)
    typeDropdown:SetPoint("LEFT", typeLabel, "RIGHT", 0, 0)
    frame.typeDropdown = typeDropdown

    local expLabel = filterRow1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    expLabel:SetPoint("LEFT", typeDropdown, "RIGHT", 4, 0)
    expLabel:SetText("Exp:")

    local expDropdown = ns.UI:CreateDropdown(filterRow1, nil, dims.expDropdown)
    expDropdown:SetPoint("LEFT", expLabel, "RIGHT", 0, 0)
    frame.expDropdown = expDropdown

    -- Filter row 2: Class, Slot, Difficulty
    local filterRow2 = CreateFrame("Frame", nil, frame)
    filterRow2:SetPoint("TOPLEFT", filterRow1, "BOTTOMLEFT", 0, -2)
    filterRow2:SetPoint("TOPRIGHT", filterRow1, "BOTTOMRIGHT", 0, -2)
    filterRow2:SetHeight(25)

    local classLabel = filterRow2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    classLabel:SetPoint("LEFT", 8, 0)
    classLabel:SetText("Class:")

    local classDropdown = ns.UI:CreateDropdown(filterRow2, nil, dims.classDropdown)
    classDropdown:SetPoint("LEFT", classLabel, "RIGHT", 0, 0)
    frame.classDropdown = classDropdown

    local slotLabel = filterRow2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotLabel:SetPoint("LEFT", classDropdown, "RIGHT", 4, 0)
    slotLabel:SetText("Slot:")

    local slotDropdown = ns.UI:CreateDropdown(filterRow2, nil, dims.slotDropdown)
    slotDropdown:SetPoint("LEFT", slotLabel, "RIGHT", 0, 0)
    frame.slotDropdown = slotDropdown

    local diffLabel = filterRow2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    diffLabel:SetPoint("LEFT", slotDropdown, "RIGHT", 4, 0)
    diffLabel:SetText("Diff:")

    local difficultyDropdown = ns.UI:CreateDropdown(filterRow2, nil, dims.diffDropdown)
    difficultyDropdown:SetPoint("LEFT", diffLabel, "RIGHT", 0, 0)
    frame.difficultyDropdown = difficultyDropdown

    -- Content frame (holds both panels)
    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", filterRow2, "BOTTOMLEFT", 0, -10)
    contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    frame.contentFrame = contentFrame

    -- Left panel (instance list)
    local leftPanel = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
    leftPanel:SetPoint("TOPLEFT", 0, 0)
    leftPanel:SetPoint("BOTTOMLEFT", 0, 0)
    leftPanel:SetWidth(LEFT_PANEL_WIDTH)
    leftPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2},
    })
    leftPanel:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    leftPanel:SetBackdropBorderColor(0.3, 0.3, 0.3)
    frame.leftPanel = leftPanel

    local leftScroll = CreateFrame("ScrollFrame", nil, leftPanel, "UIPanelScrollFrameTemplate")
    leftScroll:SetPoint("TOPLEFT", 2, -2)
    leftScroll:SetPoint("BOTTOMRIGHT", -20, 2)

    local leftScrollChild = CreateFrame("Frame", nil, leftScroll)
    leftScrollChild:SetSize(LEFT_PANEL_WIDTH - 24, 1)
    leftScroll:SetScrollChild(leftScrollChild)
    frame.leftScrollChild = leftScrollChild

    -- Right panel (boss/items) - using WowScrollBoxList pattern
    local rightPanel = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 5, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", 0, 0)
    rightPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2},
    })
    rightPanel:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    rightPanel:SetBackdropBorderColor(0.3, 0.3, 0.3)
    frame.rightPanel = rightPanel

    -- Create ScrollBox for right panel (virtual scrolling)
    local rightScrollBox = CreateFrame("Frame", nil, rightPanel, "WowScrollBoxList")
    rightScrollBox:SetPoint("TOPLEFT", 2, -2)
    rightScrollBox:SetPoint("BOTTOMRIGHT", -20, 2)

    local rightScrollBar = CreateFrame("EventFrame", nil, rightPanel, "MinimalScrollBar")
    rightScrollBar:SetPoint("TOPLEFT", rightScrollBox, "TOPRIGHT", 2, 0)
    rightScrollBar:SetPoint("BOTTOMLEFT", rightScrollBox, "BOTTOMRIGHT", 2, 0)

    -- Create view with element extent calculator for mixed row heights
    local rightView = CreateScrollBoxListLinearView()

    rightView:SetElementExtentCalculator(function(dataIndex, elementData)
        return ns.UI:GetBrowserRowExtent(dataIndex, elementData, dims)
    end)

    -- Element initializer - configures each row based on data type
    rightView:SetElementInitializer("Button", function(rowFrame, elementData)
        -- First-time setup
        if not rowFrame.initialized then
            ns.UI:InitBrowserScrollBoxRow(rowFrame, dims)
        end

        -- Reset row state
        ns.UI:ResetBrowserScrollBoxRow(rowFrame)

        local scrollWidth = rightScrollBox:GetWidth()
        local state = ns.browserState
        local cache = ns.BrowserCache

        if elementData.rowType == "boss" then
            ns.UI:SetupBrowserBossRow(rowFrame, elementData, scrollWidth)
            rowFrame:EnableMouse(false)  -- Boss headers are not clickable
        else
            ns.UI:SetupBrowserLootRow(rowFrame, elementData, scrollWidth)

            -- Build source text
            local sourceText = elementData.bossName .. ", " .. (elementData.instanceName or cache.instanceName)
            rowFrame.sourceText = sourceText
            rowFrame.track = state.selectedTrack

            -- Check if already on wishlist
            local isOnWishlist = ns:IsItemOnWishlistWithSource(elementData.itemID, sourceText, nil, state.selectedTrack)
            if isOnWishlist then
                rowFrame.checkmark:Show()
                rowFrame.name:SetTextColor(0.5, 0.5, 0.5)
                rowFrame.addBtn:Hide()
            else
                rowFrame.checkmark:Hide()
                rowFrame.name:SetTextColor(1, 1, 1)
                rowFrame.addBtn:Show()
            end

            -- Add item handler
            local function addItemHandler()
                local track = state.selectedTrack or "hero"
                local success = ns:AddItemToWishlist(elementData.itemID, nil, sourceText, track, elementData.link)
                if success then
                    ns:MarkRowAsAdded(rowFrame, elementData.itemID)
                    ns:RefreshMainWindow()
                end
            end

            rowFrame.addBtn:SetScript("OnClick", addItemHandler)
            rowFrame:SetScript("OnClick", addItemHandler)

            rowFrame:SetScript("OnEnter", function(self)
                ns.UI:SetGradient(self.bg, self.hoverColors[1], self.hoverColors[2])
                if elementData.link then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(elementData.link)
                    GameTooltip:Show()
                end
            end)
            rowFrame:SetScript("OnLeave", function(self)
                ns.UI:SetGradient(self.bg, self.normalColors[1], self.normalColors[2])
                GameTooltip:Hide()
            end)
        end

        rowFrame:Show()
    end)

    -- Initialize ScrollBox with ScrollBar
    ScrollUtil.InitScrollBoxListWithScrollBar(rightScrollBox, rightScrollBar, rightView)

    frame.rightScrollBox = rightScrollBox
    frame.rightScrollBar = rightScrollBar
    frame.rightView = rightView

    -- Initialize frame pool for left panel only (right panel uses ScrollBox)
    if not instanceRowPool then
        instanceRowPool = CreateFramePool("Button", leftScrollChild, nil, ResetInstanceRow)
    end

    -- Loading indicator with spinner
    local loadingFrame = CreateFrame("Frame", nil, rightPanel)
    loadingFrame:SetSize(100, 50)
    loadingFrame:SetPoint("CENTER")
    loadingFrame:Hide()

    local spinner = loadingFrame:CreateTexture(nil, "ARTWORK")
    spinner:SetSize(32, 32)
    spinner:SetPoint("TOP", 0, 0)
    spinner:SetTexture("Interface\\COMMON\\StreamCircle")
    loadingFrame.spinner = spinner

    -- Create AnimationGroup for rotation
    local animGroup = spinner:CreateAnimationGroup()
    local rotation = animGroup:CreateAnimation("Rotation")
    rotation:SetDegrees(-360)
    rotation:SetDuration(1)
    rotation:SetSmoothing("NONE")
    animGroup:SetLooping("REPEAT")
    loadingFrame.animGroup = animGroup

    -- Auto-start/stop animation on show/hide
    loadingFrame:HookScript("OnShow", function(self)
        self.animGroup:Play()
    end)
    loadingFrame:HookScript("OnHide", function(self)
        self.animGroup:Stop()
    end)

    local loadingText = loadingFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    loadingText:SetPoint("TOP", spinner, "BOTTOM", 0, -5)
    loadingText:SetText("Loading...")
    loadingText:SetTextColor(0.6, 0.6, 0.6)

    frame.loadingFrame = loadingFrame

    -- "No Items" indicator
    local noItemsFrame = CreateFrame("Frame", nil, rightPanel)
    noItemsFrame:SetSize(100, 30)
    noItemsFrame:SetPoint("CENTER")
    noItemsFrame:Hide()

    local noItemsText = noItemsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noItemsText:SetPoint("CENTER")
    noItemsText:SetText("No Items")
    noItemsText:SetTextColor(0.5, 0.5, 0.5)

    frame.noItemsFrame = noItemsFrame

    -- Register for M+ season changes (EJ_LOOT_DATA_RECIEVED no longer needed - handled by ItemMixin)
    frame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
    frame:SetScript("OnEvent", function(self, event)
        if event == "CHALLENGE_MODE_MAPS_UPDATE" then
            -- M+ season changed, invalidate season cache
            InvalidateSeasonCache()
            if ns.ItemBrowser:IsShown() and ns.browserState.currentSeasonFilter then
                -- Only refresh if not currently loading
                if ns.BrowserCache.loadingState ~= "loading" then
                    ns:RefreshBrowser()
                end
            end
        end
    end)

    ns.ItemBrowser = frame

    -- Initialize dropdowns
    self:InitTypeDropdown(typeDropdown)
    self:InitExpansionDropdown(expDropdown)
    self:InitClassDropdown(classDropdown)
    self:InitSlotDropdown(slotDropdown)
    self:InitDifficultyDropdown(difficultyDropdown)

    -- Set defaults if not already set
    local state = ns.browserState
    if not state.expansion then
        local tiers = GetExpansionTiers()
        if tiers[1] then
            state.expansion = tiers[1].id
        end
    end
    if state.classFilter == 0 then
        local _, _, playerClassID = UnitClass("player")
        state.classFilter = playerClassID or 0
    end
    if not state.selectedDifficultyIndex then
        ns:SetDefaultDifficulty(state)
    end

    frame:Show()
    self:RefreshBrowser()

    return frame
end

-------------------------------------------------------------------------------
-- Dropdown Initialization
-------------------------------------------------------------------------------

function ns:InitTypeDropdown(dropdown)
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local types = {
            {id = "raid", name = "Raids"},
            {id = "dungeon", name = "Dungeons"},
        }

        for _, typeInfo in ipairs(types) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = typeInfo.name
            info.checked = (ns.browserState.instanceType == typeInfo.id)
            info.func = function()
                local state = ns.browserState
                state.instanceType = typeInfo.id
                UIDropDownMenu_SetText(dropdown, typeInfo.name)
                state.selectedInstance = nil  -- Will be auto-selected in RefreshLeftPanel
                state.selectedDifficultyIndex = nil  -- Reset to let SetDefaultDifficulty pick
                state.expandedBosses = {}
                if typeInfo.id == "raid" then
                    state.currentSeasonFilter = false
                end
                InvalidateCache()
                ns:RefreshBrowser()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    local displayName = ns.browserState.instanceType == "raid" and "Raids" or "Dungeons"
    UIDropDownMenu_SetText(dropdown, displayName)
end

function ns:InitExpansionDropdown(dropdown)
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local state = ns.browserState

        -- Add "Current Season" option for dungeons
        if state.instanceType == "dungeon" then
            local info = UIDropDownMenu_CreateInfo()
            info.text = "Current Season"
            info.checked = state.currentSeasonFilter
            info.func = function()
                state.currentSeasonFilter = true
                state.expansion = nil
                UIDropDownMenu_SetText(dropdown, "Current Season")
                state.selectedInstance = nil
                state.selectedDifficultyIndex = nil
                state.expandedBosses = {}
                InvalidateCache()
                ns:RefreshBrowser()
            end
            UIDropDownMenu_AddButton(info)
        end

        for _, exp in ipairs(GetExpansionTiers()) do
            -- Skip "Current Season" for dungeons (already added above with M+ pool logic)
            if not (state.instanceType == "dungeon" and exp.name == "Current Season") then
                local info = UIDropDownMenu_CreateInfo()
                info.text = exp.name
                info.checked = (not state.currentSeasonFilter and state.expansion == exp.id)
                info.func = function()
                    state.currentSeasonFilter = false
                    state.expansion = exp.id
                    UIDropDownMenu_SetText(dropdown, exp.name)
                    state.selectedInstance = nil
                    state.selectedDifficultyIndex = nil
                    state.expandedBosses = {}
                    InvalidateCache()
                    ns:RefreshBrowser()
                end
                UIDropDownMenu_AddButton(info)
            end
        end
    end)
end

function ns:InitClassDropdown(dropdown)
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, classInfo in ipairs(CLASS_DATA) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = classInfo.name
            info.checked = (ns.browserState.classFilter == classInfo.id)
            info.func = function()
                ns.browserState.classFilter = classInfo.id
                UIDropDownMenu_SetText(dropdown, classInfo.name)
                ns.browserState.expandedBosses = {}
                InvalidateCache()  -- Class filter changes EJ results
                ns:RefreshBrowser()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
end

function ns:InitSlotDropdown(dropdown)
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, slotInfo in ipairs(SLOT_DROPDOWN_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = slotInfo.name
            info.checked = (ns.browserState.slotFilter == slotInfo.id)
            info.func = function()
                ns.browserState.slotFilter = slotInfo.id
                UIDropDownMenu_SetText(dropdown, slotInfo.name)
                -- Slot filter is client-side only, no cache invalidation
                ns:RefreshRightPanel()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    UIDropDownMenu_SetText(dropdown, "All Slots")
end

function ns:InitDifficultyDropdown(dropdown)
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local state = ns.browserState

        local difficulties = GetDifficultyOptionsForInstance(state.selectedInstance)

        if #difficulties == 0 then
            local info = UIDropDownMenu_CreateInfo()
            info.text = "No difficulties"
            info.disabled = true
            UIDropDownMenu_AddButton(info)
            return
        end

        for idx, diff in ipairs(difficulties) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = diff.name
            info.checked = (state.selectedDifficultyIndex == idx)
            info.func = function()
                state.selectedDifficultyIndex = idx
                state.selectedDifficultyID = diff.id
                state.selectedTrack = diff.track
                UIDropDownMenu_SetText(dropdown, diff.name)
                -- Difficulty changes item links (bonus IDs), invalidate cache to reload
                InvalidateCache()
                ns:RefreshRightPanel()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
end

-------------------------------------------------------------------------------
-- Refresh Orchestration
-------------------------------------------------------------------------------

function ns:RefreshBrowser()
    if not ns.ItemBrowser or not ns.ItemBrowser:IsShown() then
        return
    end

    local state = ns.browserState

    -- Update dropdown texts
    UIDropDownMenu_SetText(ns.ItemBrowser.typeDropdown,
        state.instanceType == "raid" and "Raids" or "Dungeons")

    if state.currentSeasonFilter then
        UIDropDownMenu_SetText(ns.ItemBrowser.expDropdown, "Current Season")
    else
        for _, exp in ipairs(GetExpansionTiers()) do
            if exp.id == state.expansion then
                UIDropDownMenu_SetText(ns.ItemBrowser.expDropdown, exp.name)
                break
            end
        end
    end

    for _, classInfo in ipairs(CLASS_DATA) do
        if classInfo.id == state.classFilter then
            UIDropDownMenu_SetText(ns.ItemBrowser.classDropdown, classInfo.name)
            break
        end
    end

    for _, slotInfo in ipairs(SLOT_DROPDOWN_OPTIONS) do
        if slotInfo.id == state.slotFilter then
            UIDropDownMenu_SetText(ns.ItemBrowser.slotDropdown, slotInfo.name)
            break
        end
    end

    -- Validate and update difficulty dropdown using instance-specific difficulties
    if ns.ItemBrowser.difficultyDropdown then
        local difficulties = GetDifficultyOptionsForInstance(state.selectedInstance)

        if #difficulties == 0 then
            UIDropDownMenu_SetText(ns.ItemBrowser.difficultyDropdown, "N/A")
        else
            if not state.selectedDifficultyIndex or state.selectedDifficultyIndex > #difficulties then
                ns:SetDefaultDifficulty(state)
            end

            local diff = difficulties[state.selectedDifficultyIndex]
            if diff then
                UIDropDownMenu_SetText(ns.ItemBrowser.difficultyDropdown, diff.name)
                state.selectedDifficultyID = diff.id
                state.selectedTrack = diff.track
            end
        end
    end

    -- Set default expansion if not set
    if not state.currentSeasonFilter and not state.expansion then
        local tiers = GetExpansionTiers()
        if tiers[1] then
            state.expansion = tiers[1].id
        end
    end

    self:RefreshLeftPanel()
    self:RefreshRightPanel()
end

function ns:RefreshLeftPanel()
    local frame = ns.ItemBrowser
    local scrollChild = frame.leftScrollChild
    local state = ns.browserState
    local dims = frame.dims

    instanceRowPool:ReleaseAll()

    local isRaid = (state.instanceType == "raid")
    local yOffset = 0
    local firstInstance = nil
    local firstInstanceRow = nil

    -- Handle current season filter for dungeons
    if state.currentSeasonFilter and not isRaid then
        local seasonInstanceIDs = GetCurrentSeasonInstanceIDs()
        local allInstances = ns:GetAllInstances()

        -- Iterate through season instances
        for instanceID, _ in pairs(seasonInstanceIDs) do
            local instData = allInstances[instanceID]
            if instData then
                local row = instanceRowPool:Acquire()

                if not row.name then
                    ns.UI:InitInstanceListRow(row, dims)
                end

                row:SetWidth(scrollChild:GetWidth())
                row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
                row.name:SetText(instData.name)
                row.instanceID = instanceID
                row.instanceName = instData.name

                if not firstInstance then
                    firstInstance = instanceID
                    firstInstanceRow = row
                end

                ns.UI:SetInstanceRowSelected(row, state.selectedInstance == instanceID)

                row:SetScript("OnClick", function()
                    state.selectedInstance = instanceID
                    state.selectedDifficultyIndex = nil  -- Reset to pick new defaults
                    state.expandedBosses = {}
                    InvalidateCache()
                    ns:RefreshBrowser()
                end)

                row:Show()
                yOffset = yOffset - dims.instanceRowHeight
            end
        end
    else
        -- Get instances for selected tier from static data
        local tierID = state.expansion
        if not tierID then
            local tiers = GetExpansionTiers()
            if tiers[1] then
                tierID = tiers[1].id
                state.expansion = tierID
            end
        end

        local instances = ns:GetInstancesForTier(tierID, isRaid)

        for _, inst in ipairs(instances) do
            local row = instanceRowPool:Acquire()

            if not row.name then
                ns.UI:InitInstanceListRow(row, dims)
            end

            row:SetWidth(scrollChild:GetWidth())
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
            row.name:SetText(inst.name)
            row.instanceID = inst.id
            row.instanceName = inst.name

            if not firstInstance then
                firstInstance = inst.id
                firstInstanceRow = row
            end

            ns.UI:SetInstanceRowSelected(row, state.selectedInstance == inst.id)

            row:SetScript("OnClick", function()
                state.selectedInstance = inst.id
                state.selectedDifficultyIndex = nil  -- Reset to pick new defaults
                state.expandedBosses = {}
                InvalidateCache()
                ns:RefreshBrowser()
            end)

            row:Show()
            yOffset = yOffset - dims.instanceRowHeight
        end
    end

    -- Auto-select first instance if none selected
    if not state.selectedInstance and firstInstance then
        state.selectedInstance = firstInstance
        if firstInstanceRow then
            ns.UI:SetInstanceRowSelected(firstInstanceRow, true)
        end
        InvalidateCache()
        self:RefreshRightPanel()
    end

    scrollChild:SetHeight(math.max(math.abs(yOffset), 1))
end

function ns:RefreshRightPanel()
    local frame = ns.ItemBrowser
    if not frame or not frame:IsShown() then return end

    local state = ns.browserState
    local cache = ns.BrowserCache

    if not state.selectedInstance then
        if frame.loadingFrame then frame.loadingFrame:Hide() end
        if frame.rightScrollBox then
            frame.rightScrollBox:SetDataProvider(CreateDataProvider({}))
        end
        return
    end

    -- Check cache validity
    if not IsCacheValid() then
        -- Don't start new load if already loading
        if cache.loadingState == "loading" then
            return
        end

        -- Show loading spinner
        if frame.loadingFrame then frame.loadingFrame:Show() end
        if frame.noItemsFrame then frame.noItemsFrame:Hide() end

        -- Defer cache building to next frame so spinner renders
        C_Timer.After(0, function()
            CacheInstanceData(function(success)
                if success then
                    -- Cache ready, filter and render
                    local filteredData = ns.BrowserFilter:GetFilteredData()
                    RenderRightPanel(filteredData)
                end
                -- If not success, version changed - another refresh will handle it
            end)
        end)
    else
        -- Cache valid, just filter and render (instant)
        local filteredData = ns.BrowserFilter:GetFilteredData()
        RenderRightPanel(filteredData)
    end
end

-------------------------------------------------------------------------------
-- Row State Helpers
-------------------------------------------------------------------------------

function ns:MarkRowAsAdded(row, itemID)
    if not row then return end
    row.checkmark:Show()
    row.name:SetTextColor(0.5, 0.5, 0.5)
    row.addBtn:Hide()
    row:SetScript("OnClick", nil)
end

function ns:MarkRowAsAvailable(row, sourceText)
    if not row then return end
    row.checkmark:Hide()
    row.name:SetTextColor(1, 1, 1)
    row.addBtn:Show()
    row:SetScript("OnClick", function()
        if not ns:IsItemOnWishlistWithSource(row.itemID, sourceText) then
            local state = ns.browserState
            local track = state.selectedTrack or "hero"
            local success = ns:AddItemToWishlist(row.itemID, nil, sourceText, track, row.itemLink)
            if success then
                ns:MarkRowAsAdded(row, row.itemID)
                ns:RefreshMainWindow()
            end
        end
    end)
end

function ns:UpdateBrowserRowsForItem(itemID, sourceText)
    -- With ScrollBox/DataProvider, just refresh the right panel to update row state
    if ns.ItemBrowser and ns.ItemBrowser:IsShown() then
        ns:RefreshRightPanel()
    end
end

-------------------------------------------------------------------------------
-- Cleanup
-------------------------------------------------------------------------------

function ns:ClearBrowserRowPools()
    -- Only the left panel uses frame pools now
    if instanceRowPool then instanceRowPool:ReleaseAll() end
    instanceRowPool = nil
end

function ns:CleanupItemBrowser()
    ns:ClearBrowserRowPools()
    InvalidateCache()
    if ns.ItemBrowser then
        ns.ItemBrowser:UnregisterAllEvents()
    end
end
