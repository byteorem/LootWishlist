-- LootWishlist Item Browser
-- Two-panel browser for instance loot
-- Architecture: Data Cache → Filter → Render

local addonName, ns = ...

-- Cache global functions
local pairs, ipairs, type, math = pairs, ipairs, type, math
local wipe, tinsert = wipe, table.insert
local CreateFrame = CreateFrame
local C_Timer, C_EncounterJournal, C_Item, C_ChallengeMode = C_Timer, C_EncounterJournal, C_Item, C_ChallengeMode
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

-- Slot mappings now come from ns.Constants
-- Local aliases for convenience
local function GetSlotData() return ns.Constants.SLOT_DATA end
local function GetSlotDropdownOptions() return ns.Constants.SLOT_DROPDOWN_OPTIONS end
local function GetSlotNames() return ns.Constants.SLOT_NAMES end

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
    currentSeasonFilter = false,

    -- Remembered difficulty per instance type
    lastRaidDifficultyID = nil,
    lastDungeonDifficultyID = nil,

    -- Client-side filters (don't invalidate cache)
    slotFilter = "ALL",
    searchText = "",
    equipmentOnlyFilter = true,  -- Default to showing only equipment

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
    local maxLen = math.min(#lowerSearchable, ns.Constants.MAX_NGRAM_PREFIX_LENGTH)
    for i = 1, maxLen do
        local prefix = lowerSearchable:sub(1, i)  -- O(1) vs O(n^2) concatenation
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

    -- Collect all items from EJ API with state protection
    local bosses = {}
    local searchIndex = {}
    local pendingItems = {}

    -- CRITICAL: Establish EJ API state BEFORE any queries
    -- The EJ state may be corrupted by:
    -- - Adventure Journal being opened
    -- - GetInstancesForTier() iterating through instances
    -- - Other addons using EJ API
    --
    -- We MUST fully reset EJ state by:
    -- 1. Selecting the correct tier FIRST
    -- 2. Then selecting our target instance
    -- 3. Then setting difficulty and class filter
    -- 4. Query encounters DIRECTLY (never use cached encounters)

    -- Determine the correct tier for this instance
    -- Priority: browserState.expansion > cached instance info > search all tiers
    local tierID = state.expansion

    -- If no expansion set (e.g., current season filter), try to find the tier
    if not tierID then
        -- Check if we have cached info for this instance
        local cachedInfo = ns.Data._instanceInfo[state.selectedInstance]
        if cachedInfo and cachedInfo.tierID then
            tierID = cachedInfo.tierID
        else
            -- Last resort: the instance ID is valid, EJ_SelectInstance should work
            -- We'll select the latest tier as fallback context
            local tiers = GetExpansionTiers()
            if tiers[1] then
                tierID = tiers[1].id
            end
        end
    end

    -- Step 1: Select tier to establish correct expansion context
    if tierID then
        EJ_SelectTier(tierID)
    end

    -- Step 2: Sync EncounterJournal frame state if it exists
    -- This fixes corruption when Adventure Journal has been opened, which sets
    -- EncounterJournal.instanceID. Without this sync, EJ_GetEncounterInfoByIndex()
    -- returns data for the wrong instance.
    if EncounterJournal then
        EncounterJournal.instanceID = state.selectedInstance
        EncounterJournal.encounterID = nil
    end

    -- Step 3: Select our target instance
    EJ_SelectInstance(state.selectedInstance)

    -- Get instance info for later use
    local ejName = EJ_GetInstanceInfo()

    -- Step 4: Set difficulty (must be after instance selection)
    if state.selectedDifficultyID then
        EJ_SetDifficulty(state.selectedDifficultyID)
    end

    -- Step 4: Set class filter AFTER selecting instance (EJ API requirement)
    -- 0 = all classes, else specific class ID; second param 0 = all specs
    local classID = state.classFilter > 0 and state.classFilter or 0
    EJ_SetLootFilter(classID, 0)

    -- Get instance name AFTER selecting instance (ensures correct EJ state)
    local instanceName = ejName or ""

    -- CRITICAL: Query encounters DIRECTLY from EJ API, bypassing the cache
    -- The cache may contain stale encounters from when EJ state was corrupted
    local encounters = {}
    local encounterIndex = 1
    while true do
        local encounterName, _, encounterID = EJ_GetEncounterInfoByIndex(encounterIndex)
        if not encounterID then break end
        table.insert(encounters, {
            id = encounterID,
            name = encounterName,
            order = encounterIndex,
        })
        encounterIndex = encounterIndex + 1
    end

    for _, encounter in ipairs(encounters) do
        -- Select encounter in EJ API to get its loot
        EJ_SelectEncounter(encounter.id)

        local lootList = {}
        local numLoot = EJ_GetNumLoot()

        for lootIndex = 1, numLoot do
            local info = C_EncounterJournal.GetLootInfoByIndex(lootIndex)
            if info and info.itemID then
                -- EJ API returns properly filtered items with correct difficulty links
                local slot = info.slot
                if (not slot or slot == "") and info.itemID then
                    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(info.itemID)
                    if equipLoc and equipLoc ~= "" then
                        slot = GetSlotNames()[equipLoc] or ""
                    end
                end

                local lootEntry = {
                    itemID = info.itemID,
                    name = info.name or "",
                    icon = info.icon or ns.Constants.TEXTURE.QUESTION_MARK,
                    slot = slot or "",
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

                -- Track items needing async load (missing name or icon)
                if not info.name or info.name == "" or not info.icon then
                    tinsert(pendingItems, {
                        itemID = info.itemID,
                        entry = lootEntry,
                        bossID = encounter.id,
                    })
                end
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

    -- Trigger async loads for items with missing data
    if #pendingItems > 0 then
        -- Don't mark as ready yet - wait for async loads
        cache.loadingState = "loading"

        local loadedCount = 0
        local totalPending = #pendingItems

        for _, pending in ipairs(pendingItems) do
            local item = Item:CreateFromItemID(pending.itemID)
            item:ContinueOnItemLoad(function()
                -- Update cached entry with loaded data
                local loadedName = item:GetItemName()
                local loadedIcon = item:GetItemIcon()
                local loadedLink = item:GetItemLink()

                if loadedName and loadedName ~= "" then
                    pending.entry.name = loadedName
                    -- Update search index for newly loaded name
                    local itemKey = pending.itemID .. "_" .. pending.bossID
                    BuildSearchIndexEntry(searchIndex, itemKey, loadedName)
                end
                if loadedIcon then
                    pending.entry.icon = loadedIcon
                end
                if loadedLink and not pending.entry.link then
                    pending.entry.link = loadedLink
                end

                loadedCount = loadedCount + 1

                -- All items loaded - NOW mark ready and complete
                if loadedCount >= totalPending then
                    cache.loadingState = "ready"
                    if onComplete then onComplete(true) end
                end
            end)
        end

        -- Fallback timeout - complete anyway after timeout
        C_Timer.After(ns.Constants.ASYNC_LOAD_TIMEOUT, function()
            if cache.loadingState == "loading" then
                cache.loadingState = "ready"
                if onComplete then onComplete(true) end
            end
        end)
    else
        -- No pending items, complete immediately
        cache.loadingState = "ready"
        if onComplete then onComplete(true) end
    end
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

-- Check if item is equipment (has valid filterType or slot)
function ns.BrowserFilter:IsEquipment(filterType, slot)
    -- Enum.ItemSlotFilterType: 0-13 = equipment, 14 = Other (non-equipment)
    if filterType ~= nil then
        -- filterType 14 = Other (mounts, toys, pets, profession items)
        return filterType ~= Enum.ItemSlotFilterType.Other
    end
    -- Fallback for items without filterType - check slot string
    return slot and slot ~= ""
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

    -- Match slot name from constants
    for _, slotData in ipairs(GetSlotData()) do
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

            -- Equipment filter check
            local passesEquipment = true
            if state.equipmentOnlyFilter then
                passesEquipment = self:IsEquipment(loot.filterType, loot.slot)
            end

            if passesSlot and passesSearch and passesEquipment then
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

-- Current raid season instance IDs cache
local cachedRaidSeasonInstanceIDs = nil

-- Get current season raid instance IDs from static data
local function GetCurrentSeasonRaidInstanceIDs()
    if cachedRaidSeasonInstanceIDs then
        return cachedRaidSeasonInstanceIDs
    end

    local instanceIDs = {}
    local seasonData = ns:GetCurrentSeasonInstances()
    if seasonData and seasonData.raids then
        for _, instID in ipairs(seasonData.raids) do
            instanceIDs[instID] = true
        end
    end

    cachedRaidSeasonInstanceIDs = instanceIDs
    return instanceIDs
end

-- Invalidate raid season cache (call on season/tier change)
local function InvalidateRaidSeasonCache()
    cachedRaidSeasonInstanceIDs = nil
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
        return
    end

    local isRaid = (state.instanceType == "raid")
    local difficulties = GetDifficultyOptionsForInstance(state.selectedInstance)

    if #difficulties == 0 then
        state.selectedDifficultyIndex = 1
        state.selectedDifficultyID = nil
        return
    end

    -- Check if there's a saved difficulty for this type
    local savedDiffID = isRaid and state.lastRaidDifficultyID or state.lastDungeonDifficultyID
    if savedDiffID then
        for idx, diff in ipairs(difficulties) do
            if diff.id == savedDiffID then
                state.selectedDifficultyIndex = idx
                state.selectedDifficultyID = diff.id
                return
            end
        end
    end

    -- No saved difficulty or not available, find a good default
    -- Default to Normal for both raids and dungeons
    local preferredDiffIDs = ns.Constants.PREFERRED_DIFFICULTY_IDS

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
    end
end

-- Get the first instance for the current state (type, expansion, season filter)
function ns:GetFirstInstanceForCurrentState(state)
    local isRaid = (state.instanceType == "raid")

    -- Handle current season filter for both dungeons and raids
    if state.currentSeasonFilter then
        local seasonInstanceIDs
        if isRaid then
            seasonInstanceIDs = GetCurrentSeasonRaidInstanceIDs()
        else
            seasonInstanceIDs = GetCurrentSeasonInstanceIDs()
        end
        local allInstances = ns:GetAllInstances()

        for instanceID, _ in pairs(seasonInstanceIDs) do
            local instData = allInstances[instanceID]
            if instData then
                return instanceID
            end
        end
        return nil
    end

    -- Get instances for selected tier from static data
    local tierID = state.expansion
    if not tierID then
        local tiers = GetExpansionTiers()
        if tiers[1] then
            tierID = tiers[1].id
        end
    end

    if not tierID then return nil end

    local instances = ns:GetInstancesForTier(tierID, isRaid)
    if instances and instances[1] then
        return instances[1].id
    end

    return nil
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
        -- CRITICAL: Invalidate BOTH caches to recover from EJ state corruption
        -- ns.Data caches (tiers, instances, encounters) may be stale if Adventure Journal was opened
        ns:InvalidateDataCache()  -- Clear static data cache (Loader.lua)
        InvalidateCache()  -- Clear loot cache (this file)

        ns.ItemBrowser:Show()

        -- CRITICAL: Must refresh after showing to repopulate with fresh data
        -- Without this, the UI shows stale data from before caches were invalidated
        ns:RefreshBrowser()
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

    -- Filter row 1: Tier (Expansion), Type, Difficulty
    local filterRow1 = CreateFrame("Frame", nil, frame)
    filterRow1:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 10, -10)
    filterRow1:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -10, -10)
    filterRow1:SetHeight(25)

    local expLabel = filterRow1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    expLabel:SetPoint("LEFT", 8, 0)
    expLabel:SetText("Tier:")

    local expDropdown = ns.UI:CreateModernDropdown(filterRow1, dims.expDropdown)
    expDropdown:SetPoint("LEFT", expLabel, "RIGHT", 4, 0)
    frame.expDropdown = expDropdown

    local typeLabel = filterRow1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    typeLabel:SetPoint("LEFT", expDropdown, "RIGHT", 16, 0)
    typeLabel:SetText("Type:")

    local typeDropdown = ns.UI:CreateModernDropdown(filterRow1, dims.typeDropdown)
    typeDropdown:SetPoint("LEFT", typeLabel, "RIGHT", 4, 0)
    frame.typeDropdown = typeDropdown

    local diffLabel = filterRow1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    diffLabel:SetPoint("LEFT", typeDropdown, "RIGHT", 16, 0)
    diffLabel:SetText("Diff:")
    frame.diffLabel = diffLabel

    local difficultyDropdown = ns.UI:CreateModernDropdown(filterRow1, dims.diffDropdown)
    difficultyDropdown:SetPoint("LEFT", diffLabel, "RIGHT", 4, 0)
    frame.difficultyDropdown = difficultyDropdown

    -- Filter row 2: Class, Slot, Search, Equipment checkbox
    local filterRow2 = CreateFrame("Frame", nil, frame)
    filterRow2:SetPoint("TOPLEFT", filterRow1, "BOTTOMLEFT", 0, -8)
    filterRow2:SetPoint("TOPRIGHT", filterRow1, "BOTTOMRIGHT", 0, -8)
    filterRow2:SetHeight(25)

    local classLabel = filterRow2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    classLabel:SetPoint("LEFT", 8, 0)
    classLabel:SetText("Class:")

    local classDropdown = ns.UI:CreateModernDropdown(filterRow2, dims.classDropdown)
    classDropdown:SetPoint("LEFT", classLabel, "RIGHT", 4, 0)
    frame.classDropdown = classDropdown

    local slotLabel = filterRow2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotLabel:SetPoint("LEFT", classDropdown, "RIGHT", 16, 0)
    slotLabel:SetText("Slot:")

    local slotDropdown = ns.UI:CreateModernDropdown(filterRow2, dims.slotDropdown)
    slotDropdown:SetPoint("LEFT", slotLabel, "RIGHT", 4, 0)
    frame.slotDropdown = slotDropdown

    local searchBox = ns.UI:CreateSearchBox(filterRow2, dims.searchWidth, 20)
    searchBox:SetPoint("LEFT", slotDropdown, "RIGHT", 16, 2)
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

    -- Equipment checkbox (filters non-gear items like mounts, pets, etc.)
    local equipCheckbox = CreateFrame("CheckButton", nil, filterRow2, "UICheckButtonTemplate")
    equipCheckbox:SetPoint("LEFT", searchBox, "RIGHT", 12, 0)
    equipCheckbox:SetSize(24, 24)
    equipCheckbox:SetChecked(ns.browserState.equipmentOnlyFilter)

    local equipLabel = filterRow2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    equipLabel:SetPoint("LEFT", equipCheckbox, "RIGHT", 2, 0)
    equipLabel:SetText("Equipment")

    equipCheckbox:SetScript("OnClick", function(self)
        ns.browserState.equipmentOnlyFilter = self:GetChecked()
        ns:RefreshRightPanel()  -- Client-side only, no cache invalidation
    end)
    frame.equipCheckbox = equipCheckbox

    -- Content frame (holds both panels)
    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", filterRow2, "BOTTOMLEFT", 0, -12)
    contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    frame.contentFrame = contentFrame

    -- Left panel (instance list) - using WowScrollBoxList pattern
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

    -- Create ScrollBox for left panel (virtual scrolling)
    local leftScrollBox = CreateFrame("Frame", nil, leftPanel, "WowScrollBoxList")
    leftScrollBox:SetPoint("TOPLEFT", 2, -2)
    leftScrollBox:SetPoint("BOTTOMRIGHT", -20, 2)

    local leftScrollBar = CreateFrame("EventFrame", nil, leftPanel, "MinimalScrollBar")
    leftScrollBar:SetPoint("TOPLEFT", leftScrollBox, "TOPRIGHT", 2, 0)
    leftScrollBar:SetPoint("BOTTOMLEFT", leftScrollBox, "BOTTOMRIGHT", 2, 0)

    -- Create view with fixed row height
    local leftView = CreateScrollBoxListLinearView()
    leftView:SetElementExtent(dims.instanceRowHeight)

    -- Element initializer for instance rows
    leftView:SetElementInitializer("Button", function(rowFrame, elementData)
        -- First-time setup
        if not rowFrame.initialized then
            ns.UI:InitInstanceScrollBoxRow(rowFrame, dims)
        end

        -- Reset row state
        ns.UI:ResetInstanceScrollBoxRow(rowFrame)

        local scrollWidth = leftScrollBox:GetWidth()
        local state = ns.browserState
        local isSelected = (state.selectedInstance == elementData.instanceID)

        ns.UI:SetupInstanceRow(rowFrame, elementData, scrollWidth, isSelected)

        -- Click handler
        rowFrame:SetScript("OnClick", function()
            state.selectedInstance = elementData.instanceID
            -- Keep current difficulty when changing instances within same type
            state.expandedBosses = {}
            InvalidateCache()
            ns:RefreshBrowser()
        end)

        rowFrame:Show()
    end)

    -- Initialize ScrollBox with ScrollBar
    ScrollUtil.InitScrollBoxListWithScrollBar(leftScrollBox, leftScrollBar, leftView)

    frame.leftScrollBox = leftScrollBox
    frame.leftScrollBar = leftScrollBar
    frame.leftView = leftView

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

            -- Check if already on wishlist
            local isOnWishlist = ns:IsItemOnWishlistWithSource(elementData.itemID, sourceText)
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
                local success = ns:AddItemToWishlist(elementData.itemID, nil, sourceText, elementData.link)
                if success then
                    ns:MarkRowAsAdded(rowFrame, elementData.itemID)
                    ns:RefreshMainWindow()
                end
            end

            rowFrame.addBtn:SetScript("OnClick", addItemHandler)
            rowFrame:SetScript("OnClick", addItemHandler)

            rowFrame:SetScript("OnEnter", function(self)
                ns.UI:SetGradient(self.bg, self.hoverColors[1], self.hoverColors[2])
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if elementData.link then
                    GameTooltip:SetHyperlink(elementData.link)
                else
                    GameTooltip:SetItemByID(elementData.itemID)
                end
                GameTooltip:Show()
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

    -- Subscribe to state changes for auto-refresh (update checkmarks when items change)
    frame.stateHandles = {}
    frame.stateHandles.itemsChanged = ns.State:Subscribe(ns.StateEvents.ITEMS_CHANGED, function(data)
        if frame:IsShown() then
            ns:RefreshRightPanel()  -- Update checkmarks
        end
    end)

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
    -- Auto-select first instance before setting difficulty (prevents N/A on first open)
    if not state.selectedInstance then
        state.selectedInstance = self:GetFirstInstanceForCurrentState(state)
    end
    if not state.selectedDifficultyIndex then
        ns:SetDefaultDifficulty(state)
    end

    frame:Show()
    self:RefreshBrowser()

    return frame
end

-------------------------------------------------------------------------------
-- Dropdown Initialization (Modern WowStyle1DropdownTemplate)
-------------------------------------------------------------------------------

function ns:InitTypeDropdown(dropdown)
    local types = {
        {id = "raid", name = "Raids"},
        {id = "dungeon", name = "Dungeons"},
    }

    dropdown:SetupMenu(function(dropdown, rootDescription)
        for _, typeInfo in ipairs(types) do
            rootDescription:CreateRadio(typeInfo.name,
                function() return ns.browserState.instanceType == typeInfo.id end,
                function()
                    local state = ns.browserState
                    local oldType = state.instanceType

                    -- Save current difficulty for old type before switching
                    if oldType == "raid" and state.selectedDifficultyID then
                        state.lastRaidDifficultyID = state.selectedDifficultyID
                    elseif oldType == "dungeon" and state.selectedDifficultyID then
                        state.lastDungeonDifficultyID = state.selectedDifficultyID
                    end

                    state.instanceType = typeInfo.id
                    state.expandedBosses = {}

                    -- Auto-select first instance for new type (prevents N/A difficulty)
                    state.selectedInstance = ns:GetFirstInstanceForCurrentState(state)

                    -- Restore saved difficulty for new type (or nil to trigger default)
                    if typeInfo.id == "raid" then
                        state.selectedDifficultyID = state.lastRaidDifficultyID
                    else
                        state.selectedDifficultyID = state.lastDungeonDifficultyID
                    end
                    state.selectedDifficultyIndex = nil  -- Will be resolved in RefreshBrowser

                    InvalidateCache()
                    ns:RefreshBrowser()
                end
            )
        end
    end)

    dropdown:SetDefaultText("Raids")
end

function ns:InitExpansionDropdown(dropdown)
    dropdown:SetupMenu(function(dropdown, rootDescription)
        local state = ns.browserState

        -- Add "Current Season" option for both dungeons and raids
        rootDescription:CreateRadio("Current Season",
            function() return state.currentSeasonFilter end,
            function()
                state.currentSeasonFilter = true
                state.expansion = nil
                -- Auto-select first instance for new tier
                state.selectedInstance = ns:GetFirstInstanceForCurrentState(state)
                -- Keep current difficulty when changing tiers within same type
                state.expandedBosses = {}
                InvalidateCache()
                ns:RefreshBrowser()
            end
        )

        for _, exp in ipairs(GetExpansionTiers()) do
            if exp.name ~= "Current Season" then
                rootDescription:CreateRadio(exp.name,
                    function() return not state.currentSeasonFilter and state.expansion == exp.id end,
                    function()
                        state.currentSeasonFilter = false
                        state.expansion = exp.id
                        -- Auto-select first instance for new tier
                        state.selectedInstance = ns:GetFirstInstanceForCurrentState(state)
                        -- Keep current difficulty when changing tiers within same type
                        state.expandedBosses = {}
                        InvalidateCache()
                        ns:RefreshBrowser()
                    end
                )
            end
        end
    end)

    dropdown:SetDefaultText("Select Expansion")
end

function ns:InitClassDropdown(dropdown)
    dropdown:SetupMenu(function(dropdown, rootDescription)
        for _, classInfo in ipairs(CLASS_DATA) do
            rootDescription:CreateRadio(classInfo.name,
                function() return ns.browserState.classFilter == classInfo.id end,
                function()
                    ns.browserState.classFilter = classInfo.id
                    ns.browserState.expandedBosses = {}
                    InvalidateCache()
                    ns:RefreshBrowser()
                end
            )
        end
    end)

    dropdown:SetDefaultText("All Classes")
end

function ns:InitSlotDropdown(dropdown)
    dropdown:SetupMenu(function(dropdown, rootDescription)
        for _, slotInfo in ipairs(GetSlotDropdownOptions()) do
            rootDescription:CreateRadio(slotInfo.name,
                function() return ns.browserState.slotFilter == slotInfo.id end,
                function()
                    ns.browserState.slotFilter = slotInfo.id
                    ns:RefreshBrowser()
                end
            )
        end
    end)

    dropdown:SetDefaultText("All Slots")
end

function ns:InitDifficultyDropdown(dropdown)
    dropdown:SetupMenu(function(dropdown, rootDescription)
        local state = ns.browserState
        local difficulties = GetDifficultyOptionsForInstance(state.selectedInstance)

        if #difficulties == 0 then
            rootDescription:CreateButton("No difficulties"):SetEnabled(false)
            return
        end

        for idx, diff in ipairs(difficulties) do
            rootDescription:CreateRadio(diff.name,
                function() return state.selectedDifficultyIndex == idx end,
                function()
                    state.selectedDifficultyIndex = idx
                    state.selectedDifficultyID = diff.id
                    InvalidateCache()
                    ns:RefreshBrowser()
                end
            )
        end
    end)

    dropdown:SetDefaultText("Select Difficulty")
end

-------------------------------------------------------------------------------
-- Refresh Orchestration
-------------------------------------------------------------------------------

function ns:RefreshBrowser()
    if not ns.ItemBrowser or not ns.ItemBrowser:IsShown() then
        return
    end

    local state = ns.browserState
    local frame = ns.ItemBrowser

    -- Update dropdown selection texts (OverrideText forces display text)
    if frame.typeDropdown then
        frame.typeDropdown:OverrideText(state.instanceType == "raid" and "Raids" or "Dungeons")
    end

    if frame.expDropdown then
        if state.currentSeasonFilter then
            frame.expDropdown:OverrideText("Current Season")
        else
            local expName = "Select Expansion"
            for _, exp in ipairs(GetExpansionTiers()) do
                if exp.id == state.expansion then
                    expName = exp.name
                    break
                end
            end
            frame.expDropdown:OverrideText(expName)
        end
    end

    if frame.classDropdown then
        local className = "All Classes"
        for _, classInfo in ipairs(CLASS_DATA) do
            if classInfo.id == state.classFilter then
                className = classInfo.name
                break
            end
        end
        frame.classDropdown:OverrideText(className)
    end

    if frame.slotDropdown then
        local slotName = "All Slots"
        for _, slotInfo in ipairs(GetSlotDropdownOptions()) do
            if slotInfo.id == state.slotFilter then
                slotName = slotInfo.name
                break
            end
        end
        frame.slotDropdown:OverrideText(slotName)
    end

    -- Validate and update difficulty dropdown
    if frame.difficultyDropdown then
        local difficulties = GetDifficultyOptionsForInstance(state.selectedInstance)

        if #difficulties == 0 then
            -- Disable difficulty dropdown for world bosses and instances without difficulty selection
            -- Keep selectedDifficultyID/Index so it restores when switching back to normal instances
            frame.difficultyDropdown:SetEnabled(false)
            frame.difficultyDropdown:OverrideText("N/A")
        else
            -- Enable difficulty controls
            frame.difficultyDropdown:SetEnabled(true)

            -- Try to find matching difficulty by ID first (preserves selection across instances)
            local foundIndex = nil
            if state.selectedDifficultyID then
                for idx, diff in ipairs(difficulties) do
                    if diff.id == state.selectedDifficultyID then
                        foundIndex = idx
                        break
                    end
                end
            end

            if foundIndex then
                state.selectedDifficultyIndex = foundIndex
            elseif not state.selectedDifficultyIndex or state.selectedDifficultyIndex > #difficulties then
                -- Difficulty not available for this instance, use default
                ns:SetDefaultDifficulty(state)
            end

            local diff = difficulties[state.selectedDifficultyIndex]
            if diff then
                frame.difficultyDropdown:OverrideText(diff.name)
                state.selectedDifficultyID = diff.id
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
    if not frame or not frame.leftScrollBox then return end

    local state = ns.browserState
    local isRaid = (state.instanceType == "raid")
    local data = {}
    local firstInstanceID = nil

    -- Handle current season filter for both dungeons and raids
    if state.currentSeasonFilter then
        local seasonInstanceIDs
        if isRaid then
            seasonInstanceIDs = GetCurrentSeasonRaidInstanceIDs()
        else
            seasonInstanceIDs = GetCurrentSeasonInstanceIDs()
        end
        local allInstances = ns:GetAllInstances()

        -- Build data array from season instances
        for instanceID, _ in pairs(seasonInstanceIDs) do
            local instData = allInstances[instanceID]
            if instData then
                tinsert(data, {
                    instanceID = instanceID,
                    name = instData.name,
                })
                if not firstInstanceID then
                    firstInstanceID = instanceID
                end
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

        -- Build data array from tier instances
        for _, inst in ipairs(instances) do
            tinsert(data, {
                instanceID = inst.id,
                name = inst.name,
            })
            if not firstInstanceID then
                firstInstanceID = inst.id
            end
        end
    end

    -- Auto-select first instance if none selected
    if not state.selectedInstance and firstInstanceID then
        state.selectedInstance = firstInstanceID
        InvalidateCache()
    end

    -- Create and set DataProvider
    local dataProvider = CreateDataProvider(data)
    frame.leftScrollBox:SetDataProvider(dataProvider)

    -- Refresh right panel after left panel is ready
    self:RefreshRightPanel()
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
    -- Both panels now use ScrollBox, nothing to release
end

function ns:CleanupItemBrowser()
    InvalidateCache()

    if ns.ItemBrowser then
        ns.ItemBrowser:UnregisterAllEvents()

        -- Unsubscribe from state events
        if ns.ItemBrowser.stateHandles then
            for event, handle in pairs(ns.ItemBrowser.stateHandles) do
                ns.State:Unsubscribe(ns.StateEvents[event:upper()] or event, handle)
            end
            ns.ItemBrowser.stateHandles = nil
        end
    end
end
