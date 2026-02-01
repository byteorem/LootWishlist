-- LootWishlist Item Browser
-- Two-panel browser for instance loot

local addonName, ns = ...

-- Cache global functions
local pairs, ipairs, type, math = pairs, ipairs, type, math
local wipe, tinsert = wipe, table.insert
local CreateFrame, CreateFramePool = CreateFrame, CreateFramePool
local C_Timer, C_EncounterJournal, C_Item = C_Timer, C_EncounterJournal, C_Item
local EJ_SelectTier, EJ_SetLootFilter, EJ_ResetLootFilter = EJ_SelectTier, EJ_SetLootFilter, EJ_ResetLootFilter
local EJ_GetInstanceByIndex, EJ_SelectInstance, EJ_GetEncounterInfoByIndex, EJ_SelectEncounter = EJ_GetInstanceByIndex, EJ_SelectInstance, EJ_GetEncounterInfoByIndex, EJ_SelectEncounter
local UIDropDownMenu_Initialize, UIDropDownMenu_CreateInfo, UIDropDownMenu_AddButton, UIDropDownMenu_SetText = UIDropDownMenu_Initialize, UIDropDownMenu_CreateInfo, UIDropDownMenu_AddButton, UIDropDownMenu_SetText
local UnitClass = UnitClass

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
        searchWidth = 130,
        typeDropdown = 90,
        expDropdown = 130,
        classDropdown = 110,
        slotDropdown = 90,
    },
    [2] = {  -- Large
        width = 750, height = 625, leftPanel = 175,
        instanceRowHeight = 30, bossRowHeight = 34, lootRowHeight = 28,
        lootIconSize = 24,
        lootNameFont = "GameFontNormal",
        lootSlotFont = "GameFontNormal",
        instanceFont = "GameFontNormal",
        bossFont = "GameFontNormalLarge",
        searchWidth = 160,
        typeDropdown = 110,
        expDropdown = 160,
        classDropdown = 135,
        slotDropdown = 110,
    },
}

local function GetBrowserDimensions()
    local sizeID = ns.db and ns.db.settings and ns.db.settings.browserSize or 1
    return SIZE_PRESETS[sizeID] or SIZE_PRESETS[1]
end

-- Expansion tier IDs (EJ tiers)
local EXPANSION_TIERS = {
    {id = 11, name = "The War Within"},
    {id = 10, name = "Dragonflight"},
    {id = 9, name = "Shadowlands"},
    {id = 8, name = "Battle for Azeroth"},
    {id = 7, name = "Legion"},
    {id = 6, name = "Warlords of Draenor"},
    {id = 5, name = "Mists of Pandaria"},
    {id = 4, name = "Cataclysm"},
    {id = 3, name = "Wrath of the Lich King"},
    {id = 2, name = "The Burning Crusade"},
    {id = 1, name = "Classic"},
}

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

-- Slot data for dropdown
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

-- Session-only browser state (not persisted to SavedVariables)
local browserState = {
    expansion = nil,
    instanceType = "raid",
    selectedInstance = nil,
    expandedBosses = {},
    classFilter = 0,
    slotFilter = "ALL",
}

local function GetBrowserState()
    return browserState
end

-- Frame pools (initialized in CreateItemBrowser)
local instanceRowPool, bossRowPool, lootRowPool

-- Reset functions for frame pools
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
    row.sourceText = nil
    if row.checkmark then row.checkmark:Hide() end
    if row.name then row.name:SetTextColor(1, 1, 1) end
    if row.addBtn then row.addBtn:Show() end
    row:SetScript("OnClick", nil)
    row:SetScript("OnEnter", nil)
    row:SetScript("OnLeave", nil)
end

-- Create item browser
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
    frame.dims = dims  -- Store for row creation

    -- Position next to main window
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
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)

    -- Update browse button text when close button is clicked
    titleBar.closeBtn:HookScript("OnClick", function()
        if ns.MainWindow and ns.MainWindow.browseBtn then
            ns.MainWindow.browseBtn:SetText("Browse")
        end
    end)

    -- Filter row 1: Type and Expansion
    local filterRow1 = CreateFrame("Frame", nil, frame)
    filterRow1:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 10, -10)
    filterRow1:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -10, -10)
    filterRow1:SetHeight(25)

    local typeLabel = filterRow1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    typeLabel:SetPoint("LEFT", 0, 2)
    typeLabel:SetText("Type:")

    local typeDropdown = ns.UI:CreateDropdown(filterRow1, nil, dims.typeDropdown)
    typeDropdown:SetPoint("LEFT", typeLabel, "RIGHT", 0, 0)
    frame.typeDropdown = typeDropdown

    local expLabel = filterRow1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    expLabel:SetPoint("LEFT", typeDropdown, "RIGHT", 5, 2)
    expLabel:SetText("Expansion")

    local expDropdown = ns.UI:CreateDropdown(filterRow1, nil, dims.expDropdown)
    expDropdown:SetPoint("LEFT", expLabel, "RIGHT", 0, 0)
    frame.expDropdown = expDropdown

    -- Filter row 2: Search, Class, Slot
    local filterRow2 = CreateFrame("Frame", nil, frame)
    filterRow2:SetPoint("TOPLEFT", filterRow1, "BOTTOMLEFT", 0, -2)
    filterRow2:SetPoint("TOPRIGHT", filterRow1, "BOTTOMRIGHT", 0, -2)
    filterRow2:SetHeight(25)

    local searchBox = ns.UI:CreateSearchBox(filterRow2, dims.searchWidth, 20)
    searchBox:SetPoint("LEFT", 8, 2)
    searchBox:HookScript("OnTextChanged", function(self)
        ns.browserSearchText = self:GetText():lower()
        ns:RefreshBrowser()
    end)
    frame.searchBox = searchBox

    local classLabel = filterRow2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    classLabel:SetPoint("LEFT", searchBox, "RIGHT", 5, 0)
    classLabel:SetText("Class:")

    local classDropdown = ns.UI:CreateDropdown(filterRow2, nil, dims.classDropdown)
    classDropdown:SetPoint("LEFT", classLabel, "RIGHT", 0, 0)
    frame.classDropdown = classDropdown

    local slotLabel = filterRow2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotLabel:SetPoint("LEFT", classDropdown, "RIGHT", 5, 0)
    slotLabel:SetText("Slot:")

    local slotDropdown = ns.UI:CreateDropdown(filterRow2, nil, dims.slotDropdown)
    slotDropdown:SetPoint("LEFT", slotLabel, "RIGHT", 0, 0)
    frame.slotDropdown = slotDropdown

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

    -- Initialize frame pools on first creation
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

    local loadingText = loadingFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    loadingText:SetPoint("TOP", spinner, "BOTTOM", 0, -5)
    loadingText:SetText("Loading...")
    loadingText:SetTextColor(0.6, 0.6, 0.6)

    -- Animate spinner rotation
    loadingFrame:SetScript("OnUpdate", function(self, elapsed)
        local rotation = (self.rotation or 0) - elapsed * 2
        spinner:SetRotation(rotation)
        self.rotation = rotation
    end)

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

    -- Register for EJ loot data callback (note: WoW has typo in event name)
    frame:RegisterEvent("EJ_LOOT_DATA_RECIEVED")
    frame:SetScript("OnEvent", function(self, event)
        if event == "EJ_LOOT_DATA_RECIEVED" then
            if ns.ItemBrowser:IsShown() and GetBrowserState().selectedInstance then
                ns:RefreshRightPanel()
            end
        end
    end)

    ns.ItemBrowser = frame

    -- Initialize dropdowns
    self:InitTypeDropdown(typeDropdown)
    self:InitExpansionDropdown(expDropdown)
    self:InitClassDropdown(classDropdown)
    self:InitSlotDropdown(slotDropdown)

    -- Set default expansion and class if not already set (first time opening)
    local state = GetBrowserState()
    if not state.expansion then
        state.expansion = EXPANSION_TIERS[1].id
    end
    if state.classFilter == 0 then
        -- Default class to player's class on first use
        local _, _, playerClassID = UnitClass("player")
        state.classFilter = playerClassID or 0
    end

    frame:Show()
    self:RefreshBrowser()

    return frame
end

-- Initialize type dropdown (Raids/Dungeons)
function ns:InitTypeDropdown(dropdown)
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local types = {
            {id = "raid", name = "Raids"},
            {id = "dungeon", name = "Dungeons"},
        }

        for _, typeInfo in ipairs(types) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = typeInfo.name
            local state = GetBrowserState()
            info.checked = (state.instanceType == typeInfo.id)
            info.func = function()
                local state = GetBrowserState()
                state.instanceType = typeInfo.id
                UIDropDownMenu_SetText(dropdown, typeInfo.name)
                state.selectedInstance = nil
                state.expandedBosses = {}
                ns:RefreshBrowser()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    local displayName = GetBrowserState().instanceType == "raid" and "Raids" or "Dungeons"
    UIDropDownMenu_SetText(dropdown, displayName)
end

-- Initialize expansion dropdown
function ns:InitExpansionDropdown(dropdown)
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, exp in ipairs(EXPANSION_TIERS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = exp.name
            local state = GetBrowserState()
            info.checked = (state.expansion == exp.id)
            info.func = function()
                local state = GetBrowserState()
                state.expansion = exp.id
                UIDropDownMenu_SetText(dropdown, exp.name)
                state.selectedInstance = nil
                state.expandedBosses = {}
                ns:RefreshBrowser()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
end

-- Initialize class dropdown
function ns:InitClassDropdown(dropdown)
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, classInfo in ipairs(CLASS_DATA) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = classInfo.name
            local state = GetBrowserState()
            info.checked = (state.classFilter == classInfo.id)
            info.func = function()
                local state = GetBrowserState()
                state.classFilter = classInfo.id
                UIDropDownMenu_SetText(dropdown, classInfo.name)
                ns:RefreshBrowser()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
end

-- Initialize slot dropdown
function ns:InitSlotDropdown(dropdown)
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, slotInfo in ipairs(SLOT_DROPDOWN_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = slotInfo.name
            local state = GetBrowserState()
            info.checked = (state.slotFilter == slotInfo.id)
            info.func = function()
                local state = GetBrowserState()
                state.slotFilter = slotInfo.id
                UIDropDownMenu_SetText(dropdown, slotInfo.name)
                ns:RefreshBrowser()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    UIDropDownMenu_SetText(dropdown, "All Slots")
end

-- Main refresh orchestrator
function ns:RefreshBrowser()
    if not ns.ItemBrowser or not ns.ItemBrowser:IsShown() then
        return
    end

    local state = GetBrowserState()

    -- Update type dropdown text
    local displayName = state.instanceType == "raid" and "Raids" or "Dungeons"
    UIDropDownMenu_SetText(ns.ItemBrowser.typeDropdown, displayName)

    -- Update expansion dropdown text
    for _, exp in ipairs(EXPANSION_TIERS) do
        if exp.id == state.expansion then
            UIDropDownMenu_SetText(ns.ItemBrowser.expDropdown, exp.name)
            break
        end
    end

    -- Update class dropdown text
    for _, classInfo in ipairs(CLASS_DATA) do
        if classInfo.id == state.classFilter then
            UIDropDownMenu_SetText(ns.ItemBrowser.classDropdown, classInfo.name)
            break
        end
    end

    -- Update slot dropdown text
    for _, slotInfo in ipairs(SLOT_DROPDOWN_OPTIONS) do
        if slotInfo.id == state.slotFilter then
            UIDropDownMenu_SetText(ns.ItemBrowser.slotDropdown, slotInfo.name)
            break
        end
    end

    -- Set the EJ tier and loot filter
    if not state.expansion then
        state.expansion = EXPANSION_TIERS[1].id  -- Default to "The War Within"
    end
    EJ_SelectTier(state.expansion)
    if state.classFilter > 0 then
        EJ_SetLootFilter(state.classFilter, 0)
    else
        EJ_ResetLootFilter()
    end

    self:RefreshLeftPanel()
    self:RefreshRightPanel()
end

-- Refresh left panel (instance list)
function ns:RefreshLeftPanel()
    local frame = ns.ItemBrowser
    local scrollChild = frame.leftScrollChild
    local state = GetBrowserState()
    local dims = frame.dims

    -- Release all pooled rows
    instanceRowPool:ReleaseAll()

    local isRaid = (state.instanceType == "raid")
    local yOffset = 0
    local instanceIndex = 1
    local firstInstance = nil

    -- Iterate instances
    while true do
        local instanceID, instanceName = EJ_GetInstanceByIndex(instanceIndex, isRaid)
        if not instanceID then break end

        -- Always show all instances (search only filters items, not instance list)
        local row = instanceRowPool:Acquire()

        -- Initialize row if new (check if row.name exists)
        if not row.name then
            ns.UI:InitInstanceListRow(row, dims)
        end

        row:SetWidth(scrollChild:GetWidth())
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
        row.name:SetText(instanceName)
        row.instanceID = instanceID
        row.instanceName = instanceName

        -- Track first instance for auto-select
        if not firstInstance then
            firstInstance = instanceID
        end

        -- Selection state
        local isSelected = (state.selectedInstance == instanceID)
        ns.UI:SetInstanceRowSelected(row, isSelected)

        row:SetScript("OnClick", function()
            local state = GetBrowserState()
            state.selectedInstance = instanceID
            state.expandedBosses = {}
            ns:RefreshBrowser()
        end)

        row:Show()
        yOffset = yOffset - dims.instanceRowHeight

        instanceIndex = instanceIndex + 1
    end

    -- Auto-select first instance if none selected
    if not state.selectedInstance and firstInstance then
        state.selectedInstance = firstInstance
        self:RefreshRightPanel()
    end

    -- Update scroll child height
    scrollChild:SetHeight(math.max(math.abs(yOffset), 1))
end

-- Refresh right panel (boss headers + items)
function ns:RefreshRightPanel()
    local frame = ns.ItemBrowser
    if frame.loadingFrame then frame.loadingFrame:Show() end

    -- Defer heavy work to next frame so spinner renders first
    C_Timer.After(0, function()
        ns:DoRefreshRightPanel()
    end)
end

function ns:DoRefreshRightPanel()
    local frame = ns.ItemBrowser
    if not frame or not frame:IsShown() then return end

    local scrollChild = frame.rightScrollChild
    local searchText = ns.browserSearchText or ""
    local state = GetBrowserState()
    local dims = frame.dims

    -- Release all pooled rows
    bossRowPool:ReleaseAll()
    lootRowPool:ReleaseAll()

    if not state.selectedInstance then
        if frame.loadingFrame then frame.loadingFrame:Hide() end
        scrollChild:SetHeight(1)
        return
    end

    -- Find instance name
    local instanceName = ""
    local isRaid = (state.instanceType == "raid")
    local idx = 1
    while true do
        local instID, instName = EJ_GetInstanceByIndex(idx, isRaid)
        if not instID then break end
        if instID == state.selectedInstance then
            instanceName = instName
            break
        end
        idx = idx + 1
    end

    EJ_SelectInstance(state.selectedInstance)

    -- PHASE 1: Check if all items are loaded before rendering
    local allItemsReady = true
    local bossIndex = 1
    while true do
        local name, description, bossID = EJ_GetEncounterInfoByIndex(bossIndex)
        if not name then break end

        EJ_SelectEncounter(bossID)
        local lootIndex = 1
        while true do
            local lootInfo = C_EncounterJournal.GetLootInfoByIndex(lootIndex)
            if not lootInfo then break end

            if not lootInfo.name and lootInfo.itemID then
                -- Item needs loading
                allItemsReady = false
                C_Item.RequestLoadItemDataByID(lootInfo.itemID)
            end
            lootIndex = lootIndex + 1
        end
        bossIndex = bossIndex + 1
    end

    -- PHASE 2: If items need loading, keep spinner and wait for event
    if not allItemsReady then
        if frame.loadingFrame then frame.loadingFrame:Show() end
        -- EJ_LOOT_DATA_RECIEVED event will trigger refresh when data arrives
        return
    end

    -- PHASE 3: All items ready - proceed with rendering
    local rowIndex = 0
    local yOffset = 0
    bossIndex = 1

    while true do
        local name, description, bossID = EJ_GetEncounterInfoByIndex(bossIndex)
        if not name then break end

        -- Check if boss name matches search
        local bossNameMatches = (searchText == "" or name:lower():find(searchText, 1, true))

        -- Select encounter first so we can query loot
        EJ_SelectEncounter(bossID)

        -- Pre-scan: check if any items pass filters before showing boss header
        local hasMatchingItems = false
        local scanIndex = 1
        while true do
            local lootInfo = C_EncounterJournal.GetLootInfoByIndex(scanIndex)
            if not lootInfo then break end

            local itemName = lootInfo.name or ""
            local itemSlot = lootInfo.slot or ""

            -- Same slot filter logic as below
            local passesSlotFilter = (state.slotFilter == "ALL")
            if not passesSlotFilter then
                if state.slotFilter == "WEAPON" then
                    passesSlotFilter = itemSlot:find("Weapon") or
                                      itemSlot:find("Shield") or
                                      itemSlot:find("Off Hand") or
                                      itemSlot:find("Held In Off")
                else
                    for _, slotData in ipairs(SLOT_DATA) do
                        if slotData.id == state.slotFilter then
                            passesSlotFilter = (itemSlot == slotData.name)
                            break
                        end
                    end
                end
            end

            -- Check search filter
            local passesSearch = (searchText == "" or itemName:lower():find(searchText, 1, true))

            if passesSlotFilter and passesSearch then
                hasMatchingItems = true
                break  -- Found one, no need to continue
            end
            scanIndex = scanIndex + 1
        end

        -- Show boss if name matches OR has matching items
        if bossNameMatches or hasMatchingItems then
                -- Boss header row
                rowIndex = rowIndex + 1
                local bossRow = bossRowPool:Acquire()

                -- Initialize row if new
                if not bossRow.name then
                    ns.UI:InitBossRow(bossRow, dims)
                end

                bossRow:SetWidth(scrollChild:GetWidth())
                bossRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
                bossRow.name:SetText(name)
                bossRow.bossID = bossID

                -- Boss rows are always expanded (no collapse functionality)
                bossRow:SetScript("OnClick", nil)
                bossRow:EnableMouse(false)

                bossRow:Show()
                yOffset = yOffset - dims.bossRowHeight

                -- Show loot rows
                local lootIndex = 1
                while true do
                    local lootInfo = C_EncounterJournal.GetLootInfoByIndex(lootIndex)
                    if not lootInfo then break end

                    local itemID = lootInfo.itemID
                    local itemLink = lootInfo.link
                    local itemSlot = lootInfo.slot or ""
                    local itemName = lootInfo.name
                    if not itemName and itemID then
                        C_Item.RequestLoadItemDataByID(itemID)
                        itemName = "Loading..."
                    else
                        itemName = itemName or "Unknown"
                    end

                    -- Apply slot filter
                    local passesSlotFilter = (state.slotFilter == "ALL")
                    if not passesSlotFilter then
                        -- Check for weapon types
                        if state.slotFilter == "WEAPON" then
                            passesSlotFilter = itemSlot:find("Weapon") or
                                              itemSlot:find("Shield") or
                                              itemSlot:find("Off Hand") or
                                              itemSlot:find("Held In Off")
                        else
                            -- Match slot name
                            for _, slotData in ipairs(SLOT_DATA) do
                                if slotData.id == state.slotFilter then
                                    passesSlotFilter = (itemSlot == slotData.name)
                                    break
                                end
                            end
                        end
                    end

                    -- Check search filter for item name
                    local showLoot = passesSlotFilter and
                                    (searchText == "" or itemName:lower():find(searchText, 1, true))

                    if showLoot then
                        rowIndex = rowIndex + 1
                        local lootRow = lootRowPool:Acquire()

                        -- Initialize row if new
                        if not lootRow.name then
                            ns.UI:InitLootRow(lootRow, dims)
                        end

                        lootRow:SetWidth(scrollChild:GetWidth())
                        lootRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
                        lootRow.name:SetText(itemName)
                        lootRow.icon:SetTexture(lootInfo.icon or 134400)
                        lootRow.itemID = itemID
                        lootRow.slotLabel:SetText(itemSlot)

                        -- Build source text
                        local sourceText = name .. ", " .. instanceName
                        lootRow.sourceText = sourceText

                        -- Check if already on wishlist (with this specific source)
                        local isOnWishlist = ns:IsItemOnWishlistWithSource(itemID, sourceText)
                        if isOnWishlist then
                            lootRow.checkmark:Show()
                            lootRow.name:SetTextColor(0.5, 0.5, 0.5)
                            lootRow.addBtn:Hide()
                        else
                            lootRow.checkmark:Hide()
                            lootRow.name:SetTextColor(1, 1, 1)
                            lootRow.addBtn:Show()
                        end

                        -- Add item handler (used by both button and row click)
                        local function addItemHandler()
                            if not ns:IsItemOnWishlistWithSource(itemID, sourceText) then
                                local success = ns:AddItemToWishlist(itemID, nil, sourceText)
                                if success then
                                    ns:MarkRowAsAdded(lootRow, itemID)
                                    ns:RefreshMainWindow()
                                end
                            end
                        end

                        lootRow.addBtn:SetScript("OnClick", addItemHandler)

                        -- Make entire row clickable (only if not already on wishlist)
                        if not isOnWishlist then
                            lootRow:SetScript("OnClick", addItemHandler)
                        end

                        -- Tooltip
                        lootRow:SetScript("OnEnter", function(self)
                            if itemLink then
                                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                                GameTooltip:SetHyperlink(itemLink)
                                GameTooltip:Show()
                            end
                        end)
                        lootRow:SetScript("OnLeave", function()
                            GameTooltip:Hide()
                        end)

                        lootRow:Show()
                        yOffset = yOffset - dims.lootRowHeight
                    end

                    lootIndex = lootIndex + 1
                end
        end

        bossIndex = bossIndex + 1
    end

    -- Hide loading indicator
    if frame.loadingFrame then frame.loadingFrame:Hide() end

    -- Show/hide "No Items" indicator
    if frame.noItemsFrame then
        if rowIndex == 0 then
            frame.noItemsFrame:Show()
        else
            frame.noItemsFrame:Hide()
        end
    end

    -- Update scroll child height
    scrollChild:SetHeight(math.max(math.abs(yOffset), 1))
end

-- Mark a single row as added (without full refresh)
function ns:MarkRowAsAdded(row, itemID)
    if not row then return end
    row.checkmark:Show()
    row.name:SetTextColor(0.5, 0.5, 0.5)
    row.addBtn:Hide()
    -- Disable row click for added items
    row:SetScript("OnClick", nil)
end

-- Mark a single row as available (inverse of MarkRowAsAdded)
function ns:MarkRowAsAvailable(row, sourceText)
    if not row then return end
    row.checkmark:Hide()
    row.name:SetTextColor(1, 1, 1)
    row.addBtn:Show()
    -- Re-enable row click
    row:SetScript("OnClick", function()
        if not ns:IsItemOnWishlistWithSource(row.itemID, sourceText) then
            local success = ns:AddItemToWishlist(row.itemID, nil, sourceText)
            if success then
                ns:MarkRowAsAdded(row, row.itemID)
                ns:RefreshMainWindow()
            end
        end
    end)
end

-- Update browser rows for a specific item (used when item is removed from wishlist)
function ns:UpdateBrowserRowsForItem(itemID, sourceText)
    if not lootRowPool then return end

    -- Iterate over active loot rows in the pool
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

-- Clear row pools (called when browser size changes)
function ns:ClearBrowserRowPools()
    if instanceRowPool then instanceRowPool:ReleaseAll() end
    if bossRowPool then bossRowPool:ReleaseAll() end
    if lootRowPool then lootRowPool:ReleaseAll() end
end
