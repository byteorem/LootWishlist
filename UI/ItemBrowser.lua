-- LootWishlist Item Browser
-- Two-panel browser for instance loot
-- Architecture: Data Cache → Filter → Render

local addonName, ns = ...

-- Cache global functions
local pairs, ipairs, type, math = pairs, ipairs, type, math
local wipe, tinsert = wipe, table.insert
local CreateFrame, CreateFramePool = CreateFrame, CreateFramePool
local C_Timer, C_EncounterJournal, C_Item, C_ChallengeMode = C_Timer, C_EncounterJournal, C_Item, C_ChallengeMode
local EJ_SelectTier, EJ_SetLootFilter, EJ_ResetLootFilter, EJ_SetDifficulty = EJ_SelectTier, EJ_SetLootFilter, EJ_ResetLootFilter, EJ_SetDifficulty
local EJ_GetInstanceByIndex, EJ_SelectInstance, EJ_GetEncounterInfoByIndex, EJ_SelectEncounter = EJ_GetInstanceByIndex, EJ_SelectInstance, EJ_GetEncounterInfoByIndex, EJ_SelectEncounter
local EJ_GetNumTiers, EJ_GetTierInfo = EJ_GetNumTiers, EJ_GetTierInfo
local UIDropDownMenu_Initialize, UIDropDownMenu_CreateInfo, UIDropDownMenu_AddButton, UIDropDownMenu_SetText = UIDropDownMenu_Initialize, UIDropDownMenu_CreateInfo, UIDropDownMenu_AddButton, UIDropDownMenu_SetText
local UnitClass = UnitClass
local GameTooltip = GameTooltip

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

-- Dynamically build expansion tiers from Encounter Journal API
local EXPANSION_TIERS  -- Cached after first build

local function GetExpansionTiers()
    if EXPANSION_TIERS then return EXPANSION_TIERS end

    EXPANSION_TIERS = {}
    local numTiers = EJ_GetNumTiers()
    -- Build newest first (reverse order)
    for i = numTiers, 1, -1 do
        local name = EJ_GetTierInfo(i)
        if name then
            table.insert(EXPANSION_TIERS, {id = i, name = name})
        end
    end
    return EXPANSION_TIERS
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
    instanceID = nil,
    classFilter = nil,
    instanceName = "",
    bosses = {},       -- Array: {bossID, name, loot = {lootInfo...}}
    allItemsLoaded = false,
}

-- Instance name cache to avoid repeated tier loops
local instanceNameCache = {}

local function GetCachedInstanceName(instanceID, isRaid, currentSeasonFilter)
    if instanceNameCache[instanceID] then
        return instanceNameCache[instanceID]
    end

    local instanceName = ""

    -- For current season dungeons, search across all tiers
    if currentSeasonFilter and not isRaid then
        for tierIdx = 11, 1, -1 do
            EJ_SelectTier(tierIdx)
            local idx = 1
            while true do
                local instID, instName = EJ_GetInstanceByIndex(idx, false)
                if not instID then break end
                if instID == instanceID then
                    instanceName = instName
                    break
                end
                idx = idx + 1
            end
            if instanceName ~= "" then break end
        end
    else
        -- Search current tier
        local idx = 1
        while true do
            local instID, instName = EJ_GetInstanceByIndex(idx, isRaid)
            if not instID then break end
            if instID == instanceID then
                instanceName = instName
                break
            end
            idx = idx + 1
        end
    end

    if instanceName ~= "" then
        instanceNameCache[instanceID] = instanceName
    end

    return instanceName
end

-- Check if cache is valid for current state
local function IsCacheValid()
    local state = ns.browserState
    local cache = ns.BrowserCache

    return cache.instanceID == state.selectedInstance
       and cache.classFilter == state.classFilter
end

-- Invalidate cache (called when data filters change)
local function InvalidateCache()
    local cache = ns.BrowserCache
    cache.instanceID = nil
    cache.classFilter = nil
    cache.instanceName = ""
    wipe(cache.bosses)
    cache.allItemsLoaded = false
end

-- Cache instance data from EJ API
local function CacheInstanceData()
    local state = ns.browserState
    local cache = ns.BrowserCache

    if not state.selectedInstance then
        InvalidateCache()
        return false
    end

    local isRaid = (state.instanceType == "raid")
    local instanceName = GetCachedInstanceName(state.selectedInstance, isRaid, state.currentSeasonFilter)

    EJ_SelectInstance(state.selectedInstance)

    -- Apply class filter
    if state.classFilter > 0 then
        EJ_SetLootFilter(state.classFilter, 0)
    else
        EJ_ResetLootFilter()
    end

    -- Cache boss and loot data
    local bosses = {}
    local allItemsLoaded = true
    local bossIndex = 1

    while true do
        local name, description, bossID = EJ_GetEncounterInfoByIndex(bossIndex)
        if not name then break end

        EJ_SelectEncounter(bossID)

        local lootList = {}
        local lootIndex = 1

        while true do
            local lootInfo = C_EncounterJournal.GetLootInfoByIndex(lootIndex)
            if not lootInfo then break end

            -- Check if item needs loading
            if not lootInfo.name and lootInfo.itemID then
                allItemsLoaded = false
                C_Item.RequestLoadItemDataByID(lootInfo.itemID)
            end

            tinsert(lootList, {
                itemID = lootInfo.itemID,
                name = lootInfo.name or "Loading...",
                icon = lootInfo.icon or 134400,
                slot = lootInfo.slot or "",
                link = lootInfo.link,
            })

            lootIndex = lootIndex + 1
        end

        -- Only include boss if it has loot (respects class filter)
        if #lootList > 0 then
            tinsert(bosses, {
                bossID = bossID,
                name = name,
                loot = lootList,
            })
        end

        bossIndex = bossIndex + 1
    end

    -- Store in cache
    cache.instanceID = state.selectedInstance
    cache.classFilter = state.classFilter
    cache.instanceName = instanceName
    cache.bosses = bosses
    cache.allItemsLoaded = allItemsLoaded

    return allItemsLoaded
end

-------------------------------------------------------------------------------
-- Filter Layer
-------------------------------------------------------------------------------

ns.BrowserFilter = {}

-- Check if slot passes filter
function ns.BrowserFilter:PassesSlotFilter(itemSlot, slotFilter)
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

-- Check if item passes search filter
function ns.BrowserFilter:PassesSearchFilter(itemName, bossName, searchText)
    if searchText == "" then
        return true
    end
    local searchLower = searchText:lower()
    return itemName:lower():find(searchLower, 1, true)
        or bossName:lower():find(searchLower, 1, true)
end

-- Get filtered data ready for rendering
function ns.BrowserFilter:GetFilteredData()
    local state = ns.browserState
    local cache = ns.BrowserCache
    local result = {}

    for _, boss in ipairs(cache.bosses) do
        local filteredLoot = {}

        for _, loot in ipairs(boss.loot) do
            local passesSlot = self:PassesSlotFilter(loot.slot, state.slotFilter)
            local passesSearch = self:PassesSearchFilter(loot.name, boss.name, state.searchText)

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

-------------------------------------------------------------------------------
-- Frame Pools
-------------------------------------------------------------------------------

local instanceRowPool, bossRowPool, lootRowPool

local function ResetInstanceRow(pool, row)
    row:Hide()
    row:ClearAllPoints()
    row.instanceID = nil
    row:SetScript("OnClick", nil)
end

local function ResetBossRow(pool, row)
    row:Hide()
    row:ClearAllPoints()
    row.bossID = nil
end

local function ResetLootRow(pool, row)
    row:Hide()
    row:ClearAllPoints()
    row.itemID = nil
    row.itemLink = nil
    row.sourceText = nil
    row.track = nil
    if row.checkmark then row.checkmark:Hide() end
    if row.name then row.name:SetTextColor(1, 1, 1) end
    if row.addBtn then row.addBtn:Show() end
    row:SetScript("OnClick", nil)
    row:SetScript("OnEnter", nil)
    row:SetScript("OnLeave", nil)
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

-- Get difficulty options for current instance type
local function GetDifficultyOptions(instanceType)
    if instanceType == "raid" then
        return ns.RAID_DIFFICULTIES
    else
        return ns.DUNGEON_DIFFICULTIES
    end
end

-- Set default difficulty based on instance type
function ns:SetDefaultDifficulty(state)
    local isRaid = (state.instanceType == "raid")
    local difficulties = isRaid and ns.RAID_DIFFICULTIES or ns.DUNGEON_DIFFICULTIES

    if isRaid then
        state.selectedDifficultyIndex = 3  -- Heroic
    else
        state.selectedDifficultyIndex = 5  -- Mythic+ (6-9)
    end

    local diff = difficulties[state.selectedDifficultyIndex]
    state.selectedDifficultyID = diff.id
    state.selectedTrack = diff.track
end

-------------------------------------------------------------------------------
-- Render Layer
-------------------------------------------------------------------------------

-- Render right panel from filtered data
local function RenderRightPanel(filteredData)
    local frame = ns.ItemBrowser
    if not frame then return end

    local scrollChild = frame.rightScrollChild
    local state = ns.browserState
    local cache = ns.BrowserCache
    local dims = frame.dims

    bossRowPool:ReleaseAll()
    lootRowPool:ReleaseAll()

    local yOffset = 0
    local rowCount = 0

    for _, bossData in ipairs(filteredData) do
        -- Render boss header
        rowCount = rowCount + 1
        local bossRow = bossRowPool:Acquire()

        if not bossRow.name then
            ns.UI:InitBossRow(bossRow, dims)
        end

        bossRow:SetWidth(scrollChild:GetWidth())
        bossRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
        bossRow.name:SetText(bossData.name)
        bossRow.bossID = bossData.bossID
        bossRow:SetScript("OnClick", nil)
        bossRow:EnableMouse(false)
        bossRow:Show()

        yOffset = yOffset - dims.bossRowHeight

        -- Render loot rows
        for _, loot in ipairs(bossData.loot) do
            rowCount = rowCount + 1
            local lootRow = lootRowPool:Acquire()

            if not lootRow.name then
                ns.UI:InitLootRow(lootRow, dims)
            end

            lootRow:SetWidth(scrollChild:GetWidth())
            lootRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
            lootRow.name:SetText(loot.name)
            lootRow.icon:SetTexture(loot.icon)
            lootRow.slotLabel:SetText(loot.slot)
            lootRow.itemID = loot.itemID
            lootRow.itemLink = loot.link
            lootRow.track = state.selectedTrack

            -- Build source text
            local sourceText = bossData.name .. ", " .. cache.instanceName
            lootRow.sourceText = sourceText

            -- Check if already on wishlist
            local isOnWishlist = ns:IsItemOnWishlistWithSource(loot.itemID, sourceText, nil, state.selectedTrack)
            if isOnWishlist then
                lootRow.checkmark:Show()
                lootRow.name:SetTextColor(0.5, 0.5, 0.5)
                lootRow.addBtn:Hide()
            else
                lootRow.checkmark:Hide()
                lootRow.name:SetTextColor(1, 1, 1)
                lootRow.addBtn:Show()
            end

            -- Add item handler
            local function addItemHandler()
                local track = state.selectedTrack or "hero"
                local success = ns:AddItemToWishlist(loot.itemID, nil, sourceText, track, loot.link)
                if success then
                    ns:MarkRowAsAdded(lootRow, loot.itemID)
                    ns:RefreshMainWindow()
                end
            end

            lootRow.addBtn:SetScript("OnClick", addItemHandler)
            lootRow:SetScript("OnClick", addItemHandler)

            lootRow:SetScript("OnEnter", function(self)
                if loot.link then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(loot.link)
                    GameTooltip:Show()
                end
            end)
            lootRow:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            lootRow:Show()
            yOffset = yOffset - dims.lootRowHeight
        end
    end

    -- Hide loading indicator
    if frame.loadingFrame then frame.loadingFrame:Hide() end

    -- Show/hide "No Items" indicator
    if frame.noItemsFrame then
        frame.noItemsFrame:SetShown(rowCount == 0)
    end

    scrollChild:SetHeight(math.max(math.abs(yOffset), 1))
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

    -- Right panel (boss/items)
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

    local rightScroll = CreateFrame("ScrollFrame", nil, rightPanel, "UIPanelScrollFrameTemplate")
    rightScroll:SetPoint("TOPLEFT", 2, -2)
    rightScroll:SetPoint("BOTTOMRIGHT", -20, 2)

    local rightScrollChild = CreateFrame("Frame", nil, rightScroll)
    rightScrollChild:SetSize(rightPanel:GetWidth() - 24, 1)
    rightScroll:SetScrollChild(rightScrollChild)
    frame.rightScrollChild = rightScrollChild

    -- Initialize frame pools
    if not instanceRowPool then
        instanceRowPool = CreateFramePool("Button", leftScrollChild, nil, ResetInstanceRow)
    end
    if not bossRowPool then
        bossRowPool = CreateFramePool("Button", rightScrollChild, nil, ResetBossRow)
    end
    if not lootRowPool then
        lootRowPool = CreateFramePool("Button", rightScrollChild, nil, ResetLootRow)
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

    -- Register for EJ loot data callback and M+ season changes
    frame:RegisterEvent("EJ_LOOT_DATA_RECIEVED")
    frame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
    frame:SetScript("OnEvent", function(self, event)
        if event == "EJ_LOOT_DATA_RECIEVED" then
            if ns.ItemBrowser:IsShown() and ns.browserState.selectedInstance then
                -- Data arrived, invalidate cache and refresh
                InvalidateCache()
                ns:RefreshRightPanel()
            end
        elseif event == "CHALLENGE_MODE_MAPS_UPDATE" then
            -- M+ season changed, invalidate season cache
            InvalidateSeasonCache()
            if ns.ItemBrowser:IsShown() and ns.browserState.currentSeasonFilter then
                ns:RefreshBrowser()
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
        state.expansion = GetExpansionTiers()[1].id
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
                state.selectedInstance = nil
                state.expandedBosses = {}
                if typeInfo.id == "raid" then
                    state.currentSeasonFilter = false
                end
                ns:SetDefaultDifficulty(state)
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
        local difficulties = GetDifficultyOptions(state.instanceType)

        for idx, diff in ipairs(difficulties) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = diff.name
            info.checked = (state.selectedDifficultyIndex == idx)
            info.func = function()
                state.selectedDifficultyIndex = idx
                state.selectedDifficultyID = diff.id
                state.selectedTrack = diff.track
                UIDropDownMenu_SetText(dropdown, diff.name)
                EJ_SetDifficulty(diff.id)
                -- Difficulty doesn't change EJ loot list, just display
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

    -- Validate and update difficulty dropdown
    if ns.ItemBrowser.difficultyDropdown then
        local difficulties = GetDifficultyOptions(state.instanceType)
        if not state.selectedDifficultyIndex or state.selectedDifficultyIndex > #difficulties then
            ns:SetDefaultDifficulty(state)
        end
        local diff = difficulties[state.selectedDifficultyIndex]
        if diff then
            UIDropDownMenu_SetText(ns.ItemBrowser.difficultyDropdown, diff.name)
            EJ_SetDifficulty(diff.id)
        end
    end

    -- Set EJ tier and loot filter
    if not state.currentSeasonFilter then
        if not state.expansion then
            state.expansion = GetExpansionTiers()[1].id
        end
        EJ_SelectTier(state.expansion)
    end

    if state.classFilter > 0 then
        EJ_SetLootFilter(state.classFilter, 0)
    else
        EJ_ResetLootFilter()
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

        for tierIdx = 11, 1, -1 do
            EJ_SelectTier(tierIdx)
            local instanceIndex = 1

            while true do
                local instanceID, instanceName = EJ_GetInstanceByIndex(instanceIndex, false)
                if not instanceID then break end

                if seasonInstanceIDs[instanceID] then
                    local row = instanceRowPool:Acquire()

                    if not row.name then
                        ns.UI:InitInstanceListRow(row, dims)
                    end

                    row:SetWidth(scrollChild:GetWidth())
                    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
                    row.name:SetText(instanceName)
                    row.instanceID = instanceID
                    row.instanceName = instanceName

                    if not firstInstance then
                        firstInstance = instanceID
                        firstInstanceRow = row
                    end

                    ns.UI:SetInstanceRowSelected(row, state.selectedInstance == instanceID)

                    row:SetScript("OnClick", function()
                        state.selectedInstance = instanceID
                        state.expandedBosses = {}
                        InvalidateCache()
                        ns:RefreshBrowser()
                    end)

                    row:Show()
                    yOffset = yOffset - dims.instanceRowHeight
                end

                instanceIndex = instanceIndex + 1
            end
        end
    else
        local instanceIndex = 1

        while true do
            local instanceID, instanceName = EJ_GetInstanceByIndex(instanceIndex, isRaid)
            if not instanceID then break end

            local row = instanceRowPool:Acquire()

            if not row.name then
                ns.UI:InitInstanceListRow(row, dims)
            end

            row:SetWidth(scrollChild:GetWidth())
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
            row.name:SetText(instanceName)
            row.instanceID = instanceID
            row.instanceName = instanceName

            if not firstInstance then
                firstInstance = instanceID
                firstInstanceRow = row
            end

            ns.UI:SetInstanceRowSelected(row, state.selectedInstance == instanceID)

            row:SetScript("OnClick", function()
                state.selectedInstance = instanceID
                state.expandedBosses = {}
                InvalidateCache()
                ns:RefreshBrowser()
            end)

            row:Show()
            yOffset = yOffset - dims.instanceRowHeight

            instanceIndex = instanceIndex + 1
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

    if not state.selectedInstance then
        if frame.loadingFrame then frame.loadingFrame:Hide() end
        bossRowPool:ReleaseAll()
        lootRowPool:ReleaseAll()
        frame.rightScrollChild:SetHeight(1)
        return
    end

    -- Check cache validity
    if not IsCacheValid() then
        -- Clear previous items and show loading spinner
        bossRowPool:ReleaseAll()
        lootRowPool:ReleaseAll()
        frame.rightScrollChild:SetHeight(1)
        if frame.loadingFrame then frame.loadingFrame:Show() end

        -- Defer cache building to next frame so spinner renders
        C_Timer.After(0, function()
            local allLoaded = CacheInstanceData()

            if not allLoaded then
                -- Items still loading, EJ_LOOT_DATA_RECIEVED will trigger refresh
                return
            end

            -- Cache ready, filter and render
            local filteredData = ns.BrowserFilter:GetFilteredData()
            RenderRightPanel(filteredData)
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
    if not lootRowPool then return end

    for row in lootRowPool:EnumerateActive() do
        if row.itemID == itemID and row.sourceText == sourceText and row:IsShown() then
            local isOnWishlist = ns:IsItemOnWishlistWithSource(itemID, sourceText)
            if isOnWishlist then
                ns:MarkRowAsAdded(row, itemID)
            else
                ns:MarkRowAsAvailable(row, row.sourceText)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Cleanup
-------------------------------------------------------------------------------

function ns:ClearBrowserRowPools()
    if instanceRowPool then instanceRowPool:ReleaseAll() end
    if bossRowPool then bossRowPool:ReleaseAll() end
    if lootRowPool then lootRowPool:ReleaseAll() end
    instanceRowPool = nil
    bossRowPool = nil
    lootRowPool = nil
end

function ns:CleanupItemBrowser()
    ns:ClearBrowserRowPools()
    InvalidateCache()
    if ns.ItemBrowser then
        ns.ItemBrowser:UnregisterAllEvents()
    end
end
