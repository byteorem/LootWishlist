-- LootWishlist Item Browser
-- Two-panel browser for instance loot
-- Architecture: Data Cache → Filter → Render

local addonName, ns = ...

-- Cache global functions
local pairs, ipairs, math = pairs, ipairs, math
local wipe, tinsert = wipe, table.insert
local CreateFrame = CreateFrame
local C_Timer, C_EncounterJournal, C_Item = C_Timer, C_EncounterJournal, C_Item
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

-- Class data for dropdown (built dynamically from GetClassInfo)
local CLASS_DATA = {{id = 0, name = "All Classes"}}
for classID = 1, MAX_CLASSES or 20 do
    local className = GetClassInfo(classID)
    if className then
        table.insert(CLASS_DATA, {id = classID, name = className})
    end
end

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
    -- Remembered difficulty per instance type
    lastRaidDifficultyID = nil,
    lastDungeonDifficultyID = nil,

    -- Client-side filters (don't invalidate cache)
    slotFilter = "ALL",
    searchText = "",
    equipmentOnlyFilter = true,  -- Default to showing only equipment
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
end

-- Invalidate cache (called when data filters change)
local function InvalidateCache()
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

-- Refresh coalescing to prevent redundant refreshes during rapid filter changes
local pendingRefresh = false
local function ScheduleRefresh()
    if pendingRefresh then return end
    pendingRefresh = true
    C_Timer.After(0, function()
        pendingRefresh = false
        if ns.ItemBrowser and ns.ItemBrowser:IsShown() then
            ns:RefreshBrowser()
        end
    end)
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

    -- Ensure EJ addon is loaded before any queries
    local loaded, reason = ns.Data:EnsureEJLoaded()
    if not loaded then
        ns.Debug:Log("cache", "EJ addon load failed", reason)
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
    local tierID = state.expansion
    if not tierID then
        local info = ns.Data._instanceInfo[state.selectedInstance]
        tierID = info and info.tierID
    end

    -- Suppress EJ events to prevent Adventure Journal from reacting to our API calls
    ns.Data:SuppressEJEvents()

    local instanceName = ""
    local ejOk, ejErr = pcall(function()
        ns.Debug:Log("cache", "CacheInstanceData:START", {
            tierID = tierID,
            selectedInstance = state.selectedInstance,
            selectedDifficultyID = state.selectedDifficultyID,
            classFilter = state.classFilter,
        })

        -- Step 1: Select tier to establish correct expansion context
        if tierID then
            EJ_SelectTier(tierID)
            ns.Debug:Log("cache", "CacheInstanceData:EJ_SelectTier", { tierID = tierID })
        end

        -- Step 2: Select instance FIRST (this resets difficulty state)
        -- Note: Previously synced EncounterJournal.instanceID here, but that causes
        -- taint issues and corrupts API state on instance switch. EJ_SelectInstance
        -- handles its own state; we rely on SuppressEJEvents() to prevent AJ interference.
        EJ_SelectInstance(state.selectedInstance)
        ns.Debug:Log("cache", "CacheInstanceData:EJ_SelectInstance", { instanceID = state.selectedInstance })

        -- Get instance info AFTER selecting instance
        local ejName = EJ_GetInstanceInfo()
        instanceName = ejName or ""

        -- Step 3: Force difficulty state reset then set target difficulty
        -- CRITICAL: Both difficulty changes must happen BEFORE class filter.
        -- EJ_SetDifficulty regenerates loot, which wipes filter state for new instances.
        -- Use a valid reset difficulty for the instance type:
        -- - Raids: Use 17 (LFR) - always valid for raids
        -- - Dungeons: Use 1 (Normal) - always valid for dungeons
        local resetDifficultyID = (state.instanceType == "raid") and 17 or 1
        EJ_SetDifficulty(resetDifficultyID)
        ns.Debug:Log("cache", "CacheInstanceData:EJ_SetDifficulty(" .. resetDifficultyID .. ") - force reset")

        -- Step 4: Set target difficulty (before filter!)
        -- This regenerates the loot table for the target difficulty.
        -- CRITICAL: Always call EJ_SetDifficulty, even for world bosses.
        -- shouldDisplayDifficulty only controls UI visibility, not API requirements.
        local targetDifficultyID = state.selectedDifficultyID or 14
        EJ_SetDifficulty(targetDifficultyID)
        ns.Debug:Log("cache", "CacheInstanceData:EJ_SetDifficulty", { difficultyID = targetDifficultyID })

        -- Step 5: Apply class filter AFTER all difficulty changes are done
        -- This ensures filter is applied to the final loot table, not an intermediate state.
        -- Note: classID 0 is invalid - only call EJ_SetLootFilter for real classes
        EJ_ResetLootFilter()
        local classID = state.classFilter
        if classID > 0 then
            EJ_SetLootFilter(classID, 0)
            ns.Debug:Log("cache", "CacheInstanceData:EJ_SetLootFilter", { classID = classID })
        else
            ns.Debug:Log("cache", "CacheInstanceData:EJ_ResetLootFilter (all classes)")
        end

        -- DIAGNOSTIC: Only log if filter mismatch (reduces log spam)
        local actualClassID, actualSpecID = EJ_GetLootFilter()
        if actualClassID ~= classID then
            ns.Debug:Log("cache", "FilterMismatch",
                "set=" .. tostring(classID) ..
                " actual=" .. tostring(actualClassID) ..
                " spec=" .. tostring(actualSpecID))
        end

        -- Get encounters directly from EJ API (dynamic, never stale)
        local encounters = {}
        local encIndex = 1
        while true do
            local encName, _, encID = EJ_GetEncounterInfoByIndex(encIndex)
            if not encName then break end
            tinsert(encounters, {id = encID, name = encName, order = encIndex})
            encIndex = encIndex + 1
        end
        ns.Debug:Log("cache", "CacheInstanceData:EncountersFromEJ", { count = #encounters })

        local isFirstEncounter = true

        for _, encounter in ipairs(encounters) do
            -- Select encounter in EJ API to get its loot
            -- Note: EJ_SetLootFilter persists across encounter selections, no need to re-apply
            EJ_SelectEncounter(encounter.id)

            local lootList = {}
            local numLoot = EJ_GetNumLoot()

            -- Log first encounter for debugging class filter issues
            if isFirstEncounter then
                local firstInfo = numLoot > 0 and C_EncounterJournal.GetLootInfoByIndex(1) or nil
                ns.Debug:Log("cache", "FirstEncounter",
                    "enc=" .. tostring(encounter.id) ..
                    " numLoot=" .. numLoot ..
                    " filterType=" .. tostring(firstInfo and firstInfo.filterType or "nil") ..
                    " item=" .. tostring(firstInfo and firstInfo.name or "nil"))
                isFirstEncounter = false
            end

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

                    -- Build search index (use | delimiter - can't appear in numeric IDs)
                    local itemKey = info.itemID .. "|" .. encounter.id
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
    end)

    -- Always restore EJ events, even on error
    ns.Data:RestoreEJEvents()

    if not ejOk then
        cache.loadingState = "idle"
        if onComplete then onComplete(false) end
        return
    end

    -- Race condition check: version changed during load
    if cache.version ~= cacheVersion then
        cache.loadingState = "idle"  -- Reset state so next load can proceed
        if onComplete then onComplete(false) end
        return
    end

    -- Store in cache
    cache.instanceID = state.selectedInstance
    cache.classFilter = state.classFilter
    cache.difficultyID = state.selectedDifficultyID
    cache.expansion = state.expansion
    cache.instanceName = instanceName
    cache.bosses = bosses
    cache.searchIndex = searchIndex

    -- Trigger async loads for items with missing data
    if #pendingItems > 0 then
        -- Don't mark as ready yet - wait for async loads
        cache.loadingState = "loading"
        local capturedVersion = cache.version
        local callbackFired = false  -- Guard against double-fire from callback + timeout

        -- Build item lookup for batch update after load
        local itemMap = {}
        local container = ContinuableContainer:Create()
        for _, pending in ipairs(pendingItems) do
            local item = Item:CreateFromItemID(pending.itemID)
            itemMap[pending.itemID] = {item = item, pending = pending}
            container:AddContinuable(item)
        end

        container:ContinueOnLoad(function()
            -- Guard: prevent double-fire if timeout already ran
            if callbackFired then return end
            callbackFired = true

            -- Version guard: abort if cache was invalidated during loading
            if cache.version ~= capturedVersion then
                -- Clear partial data from this aborted load
                wipe(cache.bosses)
                wipe(cache.searchIndex)
                cache.loadingState = "idle"
                return
            end

            -- Update all cached entries with loaded data
            for _, data in pairs(itemMap) do
                local item, pending = data.item, data.pending
                local loadedName = item:GetItemName()
                local loadedIcon = item:GetItemIcon()
                local loadedLink = item:GetItemLink()

                if loadedName and loadedName ~= "" then
                    pending.entry.name = loadedName
                    -- Update search index for newly loaded name (only if not already indexed)
                    local itemKey = pending.itemID .. "|" .. pending.bossID
                    if not searchIndex[""] or not searchIndex[""][itemKey] then
                        BuildSearchIndexEntry(searchIndex, itemKey, loadedName)
                    end
                end
                if loadedIcon then
                    pending.entry.icon = loadedIcon
                end
                if loadedLink and not pending.entry.link then
                    pending.entry.link = loadedLink
                end
            end

            cache.loadingState = "ready"
            if onComplete then onComplete(true) end
        end)

        -- Fallback timeout - complete anyway after timeout
        C_Timer.After(ns.Constants.ASYNC_LOAD_TIMEOUT, function()
            -- Guard: prevent double-fire if callback already ran
            if callbackFired then return end
            callbackFired = true

            -- Version guard: abort if cache was invalidated during loading
            if cache.version ~= capturedVersion then
                wipe(cache.bosses)
                wipe(cache.searchIndex)
                cache.loadingState = "idle"
                return
            end

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
    local matches = searchIndex and searchIndex[searchLower]
    if not matches then
        return false
    end

    -- Exact match: key format is "itemID|bossID"
    local exactKey = itemID .. "|" .. bossID
    return matches[exactKey] == true
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

-- Build difficulty options for current instance from static data
local function GetDifficultyOptionsForInstance(instanceID)
    if not instanceID then return {} end
    return ns:GetDifficultiesForInstance(instanceID)
end

-- Set default difficulty based on available difficulties for selected instance
function ns:SetDefaultDifficulty(state)
    if not state.selectedInstance then
        state.selectedDifficultyIndex = 1
        state.selectedDifficultyID = 14  -- Fallback to Normal Raid
        return
    end

    local isRaid = (state.instanceType == "raid")
    local difficulties = GetDifficultyOptionsForInstance(state.selectedInstance)

    if #difficulties == 0 then
        -- No difficulties available, use Normal Raid as fallback (matches Details! pattern)
        state.selectedDifficultyIndex = 1
        state.selectedDifficultyID = 14  -- PrimaryRaidNormal
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

    local found = false
    state.selectedDifficultyIndex = 1
    for _, prefID in ipairs(preferredDiffIDs) do
        for idx, diff in ipairs(difficulties) do
            if diff.id == prefID then
                state.selectedDifficultyIndex = idx
                found = true
                break
            end
        end
        if found then break end
    end

    local diff = difficulties[state.selectedDifficultyIndex]
    if diff then
        state.selectedDifficultyID = diff.id
    end
end

-- Get the first instance for the current state (type, expansion)
function ns:GetFirstInstanceForCurrentState(state)
    local isRaid = (state.instanceType == "raid")

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
    frame.searchTimer = nil  -- Store on frame for cleanup
    searchBox:HookScript("OnTextChanged", function(self)
        if frame.searchTimer then frame.searchTimer:Cancel() end
        frame.searchTimer = C_Timer.NewTimer(0.15, function()
            frame.searchTimer = nil
            -- Guard: skip if browser closed during debounce
            if not ns.ItemBrowser or not ns.ItemBrowser:IsShown() then return end
            ns.browserState.searchText = self:GetText()
            -- Search is client-side only, no cache invalidation
            ns:RefreshRightPanel()
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
            ns.Debug:Log("ui", "InstanceClick:CLICKED", {
                newInstanceID = elementData.instanceID,
                oldInstanceID = state.selectedInstance,
                currentDifficultyID = state.selectedDifficultyID,
                classFilter = state.classFilter,
            })
            state.selectedInstance = elementData.instanceID
            InvalidateCache()
            ScheduleRefresh()
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

    ns.ItemBrowser = frame

    -- Initialize dropdowns
    self:InitTypeDropdown(typeDropdown)
    self:InitExpansionDropdown(expDropdown)
    self:InitClassDropdown(classDropdown)
    self:InitSlotDropdown(slotDropdown)
    self:InitDifficultyDropdown(difficultyDropdown)

    -- Subscribe to state changes for auto-refresh (update checkmarks when items change)
    frame.stateHandles = {
        {event = ns.StateEvents.ITEMS_CHANGED, handle = ns.State:Subscribe(ns.StateEvents.ITEMS_CHANGED, function()
            if frame:IsShown() then
                ns:RefreshRightPanel()  -- Update checkmarks
            end
        end)},
    }

    -- Set defaults if not already set
    local state = ns.browserState
    if not state.expansion then
        local tiers = GetExpansionTiers()
        if tiers[1] then
            state.expansion = tiers[1].id
        end
    end
    -- Set classFilter to player's class on first open
    if state.classFilter == 0 then
        local _, _, playerClassID = UnitClass("player")
        if playerClassID then
            state.classFilter = playerClassID
        end
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

                    -- Batch all state changes before single refresh
                    -- 1. Save current difficulty for old type
                    if oldType == "raid" and state.selectedDifficultyID then
                        state.lastRaidDifficultyID = state.selectedDifficultyID
                    elseif oldType == "dungeon" and state.selectedDifficultyID then
                        state.lastDungeonDifficultyID = state.selectedDifficultyID
                    end

                    -- 2. Update type
                    state.instanceType = typeInfo.id

                    -- 3. Select first instance for new type
                    state.selectedInstance = ns:GetFirstInstanceForCurrentState(state)

                    -- 4. Restore saved difficulty for new type
                    state.selectedDifficultyID = typeInfo.id == "raid"
                        and state.lastRaidDifficultyID
                        or state.lastDungeonDifficultyID
                    state.selectedDifficultyIndex = nil

                    -- 5. Single invalidate + coalesced refresh
                    InvalidateCache()
                    ScheduleRefresh()
                end
            )
        end
    end)

    dropdown:SetDefaultText("Raids")
end

function ns:InitExpansionDropdown(dropdown)
    dropdown:SetupMenu(function(dropdown, rootDescription)
        local state = ns.browserState

        for _, exp in ipairs(GetExpansionTiers()) do
            rootDescription:CreateRadio(exp.name,
                function() return state.expansion == exp.id end,
                function()
                    state.expansion = exp.id
                    -- Auto-select first instance for new tier
                    state.selectedInstance = ns:GetFirstInstanceForCurrentState(state)
                    InvalidateCache()
                    ScheduleRefresh()
                end
            )
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
                    InvalidateCache()
                    ScheduleRefresh()
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
                    ScheduleRefresh()
                end
            )
        end
    end)

    dropdown:SetDefaultText("Select Difficulty")
end

-------------------------------------------------------------------------------
-- Refresh Orchestration
-------------------------------------------------------------------------------

-- Helper: find difficulty by ID in list
local function FindDifficultyByID(difficulties, diffID)
    for idx, diff in ipairs(difficulties) do
        if diff.id == diffID then
            return idx, diff
        end
    end
    return nil, nil
end

-- Resolve/validate browser state before rendering
-- Separates state mutation from display logic
function ns:EnsureBrowserStateValid()
    local state = ns.browserState

    -- Ensure expansion is set
    if not state.expansion then
        local tiers = GetExpansionTiers()
        if tiers[1] then
            state.expansion = tiers[1].id
        end
    end

    -- Resolve difficulty if not set or invalid for current instance
    if state.selectedInstance then
        local difficulties = GetDifficultyOptionsForInstance(state.selectedInstance)

        if #difficulties == 0 then
            -- No difficulties available - use Normal Raid (14) as fallback
            state.selectedDifficultyID = 14
            state.selectedDifficultyIndex = 1
        else
            -- Try to find matching difficulty by ID
            local foundIndex = FindDifficultyByID(difficulties, state.selectedDifficultyID)
            if foundIndex then
                state.selectedDifficultyIndex = foundIndex
            elseif not state.selectedDifficultyIndex or state.selectedDifficultyIndex > #difficulties then
                -- Difficulty not available for this instance, use default
                ns:SetDefaultDifficulty(state)
            else
                -- Index valid but ID wasn't set - sync them
                local diff = difficulties[state.selectedDifficultyIndex]
                if diff then
                    state.selectedDifficultyID = diff.id
                end
            end
        end
    end
end

function ns:RefreshBrowser()
    if not ns.ItemBrowser or not ns.ItemBrowser:IsShown() then
        return
    end

    -- Resolve state before rendering (separates mutation from display)
    self:EnsureBrowserStateValid()

    local state = ns.browserState
    local frame = ns.ItemBrowser

    ns.Debug:Log("ui", "RefreshBrowser", {
        instance = state.selectedInstance,
        type = state.instanceType,
        expansion = state.expansion,
        difficulty = state.selectedDifficultyID,
        class = state.classFilter,
    })

    -- Update dropdown selection texts (OverrideText forces display text)
    if frame.typeDropdown then
        frame.typeDropdown:OverrideText(state.instanceType == "raid" and "Raids" or "Dungeons")
    end

    if frame.expDropdown then
        local expName = "Select Expansion"
        for _, exp in ipairs(GetExpansionTiers()) do
            if exp.id == state.expansion then
                expName = exp.name
                break
            end
        end
        frame.expDropdown:OverrideText(expName)
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

    -- Update difficulty dropdown display (state already resolved by EnsureBrowserStateValid)
    if frame.difficultyDropdown then
        local difficulties = GetDifficultyOptionsForInstance(state.selectedInstance)
        local instanceInfo = ns:GetInstanceInfo(state.selectedInstance)
        local showDiffDropdown = instanceInfo and instanceInfo.shouldDisplayDifficulty ~= false

        if #difficulties == 0 or not showDiffDropdown then
            -- No difficulties or world boss - disable dropdown
            frame.difficultyDropdown:SetEnabled(false)
            frame.difficultyDropdown:OverrideText("N/A")
        else
            -- Enable difficulty controls and show current selection
            frame.difficultyDropdown:SetEnabled(true)
            local diff = difficulties[state.selectedDifficultyIndex]
            if diff then
                frame.difficultyDropdown:OverrideText(diff.name)
            end
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

    -- Auto-select first instance if none selected
    if not state.selectedInstance and firstInstanceID then
        state.selectedInstance = firstInstanceID
        InvalidateCache()
    end

    -- Create and set DataProvider
    local dataProvider = CreateDataProvider(data)
    frame.leftScrollBox:SetDataProvider(dataProvider)
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
            local ok, err = pcall(CacheInstanceData, function(success)
                if success then
                    -- Cache ready, filter and render
                    local filteredData = ns.BrowserFilter:GetFilteredData()
                    RenderRightPanel(filteredData)
                end
                -- If not success, version changed - another refresh will handle it
            end)
            if not ok then
                ns.BrowserCache.loadingState = "idle"
                if frame.loadingFrame then frame.loadingFrame:Hide() end
            end
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

function ns:CleanupItemBrowser()
    InvalidateCache()

    if ns.ItemBrowser then
        ns.ItemBrowser:UnregisterAllEvents()

        -- Cancel search debounce timer
        if ns.ItemBrowser.searchTimer then
            ns.ItemBrowser.searchTimer:Cancel()
            ns.ItemBrowser.searchTimer = nil
        end

        -- Unsubscribe from state events
        if ns.ItemBrowser.stateHandles then
            for _, entry in ipairs(ns.ItemBrowser.stateHandles) do
                ns.State:Unsubscribe(entry.event, entry.handle)
            end
            ns.ItemBrowser.stateHandles = nil
        end
    end
end
