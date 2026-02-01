-- LootWishlist Main Window
-- LootProfile panel

local addonName, ns = ...

-- Cache global functions
local pairs, ipairs, type, unpack = pairs, ipairs, type, unpack
local tinsert = table.insert
local CreateFrame, StaticPopup_Show = CreateFrame, StaticPopup_Show
local UIDropDownMenu_Initialize, UIDropDownMenu_CreateInfo, UIDropDownMenu_AddButton = UIDropDownMenu_Initialize, UIDropDownMenu_CreateInfo, UIDropDownMenu_AddButton
local UIDropDownMenu_SetText = UIDropDownMenu_SetText
local CreateDataProvider, CreateScrollBoxListLinearView, ScrollUtil = CreateDataProvider, CreateScrollBoxListLinearView, ScrollUtil
local EventRegistry = EventRegistry

local WINDOW_WIDTH = 450
local WINDOW_HEIGHT = 500
local GROUP_SPACING = 6

-- Selected item tracking
local selectedItemID = nil

-- Helper to get collapsed groups from persisted settings
local function GetCollapsedGroups()
    return ns.db and ns.db.settings and ns.db.settings.collapsedGroups or {}
end

-- Table column definitions
local TABLE_COLUMNS = {
    {name = "Item", width = 180},
    {name = "Slot", width = 70},
    {name = "Source", width = 180},
}

-- Group items by instance (from sourceText)
local function GroupItemsBySource(items)
    local groups = {}
    local groupOrder = {}

    for _, entry in ipairs(items) do
        local sourceText = entry.sourceText or ""
        -- Extract instance name (after comma in "Boss, Instance")
        local instanceName = sourceText:match(",?%s*([^,]+)$") or "Unknown"
        instanceName = instanceName:gsub("^%s+", ""):gsub("%s+$", "")

        if not groups[instanceName] then
            groups[instanceName] = {}
            table.insert(groupOrder, instanceName)
        end
        table.insert(groups[instanceName], entry)
    end

    return groups, groupOrder
end

-- Get collected count for a group of items
local function GetGroupProgress(ns, items)
    local collected = 0
    for _, entry in ipairs(items) do
        if ns:IsItemCollected(entry.itemID) then
            collected = collected + 1
        end
    end
    return collected, #items
end

-- Build flattened DataProvider data from grouped wishlist items
local function BuildDataProviderData(ns)
    local collapsedGroups = GetCollapsedGroups()
    local data = {}
    local items = ns:GetWishlistItems()
    local groups, groupOrder = GroupItemsBySource(items)

    for _, instanceName in ipairs(groupOrder) do
        local groupItems = groups[instanceName]
        local isCollapsed = collapsedGroups[instanceName]
        local collected, total = GetGroupProgress(ns, groupItems)

        -- Add header row
        table.insert(data, {
            rowType = "header",
            instanceName = instanceName,
            isCollapsed = isCollapsed,
            collected = collected,
            total = total,
        })

        -- Add item rows if not collapsed
        if not isCollapsed then
            for _, entry in ipairs(groupItems) do
                table.insert(data, {
                    rowType = "item",
                    itemID = entry.itemID,
                    sourceText = entry.sourceText or "",
                    isCollected = ns:IsItemCollected(entry.itemID),
                    isChecked = ns:IsItemChecked(entry.itemID),
                    isSelected = (selectedItemID == entry.itemID),
                })
            end
        end
    end

    return data
end

-- Create main window
function ns:CreateMainWindow()
    if ns.MainWindow then
        ns.MainWindow:Show()
        return
    end

    local frame = CreateFrame("Frame", "LootWishlistMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(400, 350, 700, 800)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(110)

    -- Background and border
    ns.UI:CreateBackground(frame)

    -- Title bar
    local titleBar = ns.UI:CreateTitleBar(frame, "LootWishlist")
    frame.titleBar = titleBar

    -- Make draggable
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)

    -- Profile row (dropdown + edit box + new profile button)
    local profileRow = CreateFrame("Frame", nil, frame)
    profileRow:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 10, -8)
    profileRow:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -10, -8)
    profileRow:SetHeight(30)

    -- Profile label
    local profileLabel = profileRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    profileLabel:SetPoint("LEFT", 0, 0)
    profileLabel:SetText("Wishlist:")

    -- Profile dropdown
    local dropdown = ns.UI:CreateDropdown(profileRow, nil, 120)
    dropdown:SetPoint("LEFT", profileLabel, "RIGHT", -8, 2)
    frame.wishlistDropdown = dropdown

    self:InitWishlistDropdown(dropdown)

    -- New Wishlist button
    local newProfileBtn = ns.UI:CreateButton(profileRow, "New Wishlist", 90, 22)
    newProfileBtn:SetPoint("LEFT", dropdown, "RIGHT", -2, 2)
    newProfileBtn:SetScript("OnClick", function()
        ns:ShowNewWishlistDialog()
    end)
    frame.newProfileBtn = newProfileBtn

    -- Collected count display
    local collectedLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    collectedLabel:SetPoint("TOPLEFT", profileRow, "BOTTOMLEFT", 0, -10)
    collectedLabel:SetText("0 Items Collected")
    collectedLabel:SetTextColor(0.6, 0.8, 1)
    frame.collectedLabel = collectedLabel

    -- Section header
    local sectionHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sectionHeader:SetPoint("TOPLEFT", collectedLabel, "BOTTOMLEFT", 0, -12)
    sectionHeader:SetText("Wishlist Items (Default)")
    frame.sectionHeader = sectionHeader

    -- Table header
    local tableHeader = ns.UI:CreateTableHeader(frame, TABLE_COLUMNS)
    tableHeader:SetPoint("TOPLEFT", sectionHeader, "BOTTOMLEFT", 0, -8)
    tableHeader:SetPoint("RIGHT", frame, "RIGHT", -30, 0)
    frame.tableHeader = tableHeader

    -- ScrollBox for items (modern pattern)
    local scrollBox = CreateFrame("Frame", nil, frame, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", tableHeader, "BOTTOMLEFT", 0, -2)
    scrollBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 50)

    local scrollBar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 5, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 5, 0)

    -- Create view with element initializer
    local view = CreateScrollBoxListLinearView()

    -- Set element extent calculator for mixed row heights
    view:SetElementExtentCalculator(function(dataIndex, elementData)
        return ns.UI:GetRowExtent(dataIndex, elementData)
    end)

    -- Element initializer - configures each row based on data type
    -- Must use "Button" template for RegisterForClicks to work
    view:SetElementInitializer("Button", function(rowFrame, elementData)
        -- First-time setup: initialize frame structure directly
        if not rowFrame.initialized then
            ns.UI:InitializeScrollBoxRow(rowFrame)
        end

        -- Reset row state
        ns.UI:ResetScrollBoxRow(rowFrame)

        local scrollWidth = scrollBox:GetWidth()

        if elementData.rowType == "header" then
            ns.UI:SetupHeaderRow(rowFrame, elementData, scrollWidth)

            -- Header click handler - toggle collapse
            rowFrame:SetScript("OnClick", function()
                local collapsed = GetCollapsedGroups()
                collapsed[elementData.instanceName] = not collapsed[elementData.instanceName]
                ns:RefreshMainWindow()
            end)
        else
            local itemInfo = ns:GetCachedItemInfo(elementData.itemID)
            ns.UI:SetupItemRow(rowFrame, elementData, scrollWidth, itemInfo)

            -- Item click handler - toggle collected/checked
            rowFrame:SetScript("OnClick", function(self, button)
                if button == "RightButton" then
                    if ns:IsItemCollected(elementData.itemID) then
                        ns:UnmarkItemCollected(elementData.itemID)
                    else
                        ns:MarkItemCollected(elementData.itemID)
                    end
                else
                    ns:ToggleItemChecked(elementData.itemID)
                end
                ns:RefreshMainWindow()
            end)

            -- Remove button handler
            rowFrame.removeBtn:SetScript("OnClick", function()
                ns:RemoveItemFromWishlist(elementData.itemID, elementData.sourceText)
                selectedItemID = nil
                ns:RefreshMainWindow()
                ns:UpdateBrowserRowsForItem(elementData.itemID, elementData.sourceText)
            end)
        end

        rowFrame:Show()
    end)

    -- Initialize ScrollBox with ScrollBar
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

    frame.scrollBox = scrollBox
    frame.scrollBar = scrollBar
    frame.scrollView = view

    -- Bottom buttons
    local browseBtn = ns.UI:CreateButton(frame, "Browse", 70, 24)
    browseBtn:SetPoint("BOTTOMRIGHT", -10, 12)
    browseBtn:SetScript("OnClick", function()
        ns:ToggleItemBrowser()
    end)
    frame.browseBtn = browseBtn

    -- Resize handle
    local resizer = CreateFrame("Button", nil, frame)
    resizer:SetSize(16, 16)
    resizer:SetPoint("BOTTOMRIGHT")
    resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    resizer:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resizer:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        ns:RefreshMainWindow()
    end)

    ns.MainWindow = frame

    -- Register for item info callbacks using EventRegistry
    frame.itemInfoHandle = EventRegistry:RegisterFrameEventAndCallback(
        "GET_ITEM_INFO_RECEIVED",
        function(event, itemID)
            -- Refresh if we were waiting for this item
            if ns.itemCache[itemID] == nil then
                ns:CacheItemInfo(itemID)
                ns:RefreshMainWindow()
            end
        end,
        frame
    )

    -- Show and refresh
    frame:Show()
    self:RefreshMainWindow()

    return frame
end

-- Initialize wishlist dropdown
function ns:InitWishlistDropdown(dropdown)
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local names = ns:GetWishlistNames()

        for _, name in ipairs(names) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.checked = (name == ns:GetActiveWishlistName())
            info.func = function()
                ns:SetActiveWishlist(name)
                UIDropDownMenu_SetText(dropdown, name)
                selectedItemID = nil
                ns:RefreshMainWindow()
                -- Refresh browser to show new wishlist's browser state
                if ns.ItemBrowser and ns.ItemBrowser:IsShown() then
                    ns:RefreshBrowser()
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    UIDropDownMenu_SetText(dropdown, ns:GetActiveWishlistName())
end

-- Refresh main window
function ns:RefreshMainWindow()
    if not ns.MainWindow or not ns.MainWindow:IsShown() then
        return
    end

    local frame = ns.MainWindow
    local activeName = self:GetActiveWishlistName()

    -- Update dropdown text
    UIDropDownMenu_SetText(frame.wishlistDropdown, activeName)

    -- Update collected count with percentage
    local collected, total = self:GetWishlistProgress()
    if total > 0 then
        local percent = math.floor((collected / total) * 100)
        frame.collectedLabel:SetText(string.format("%d/%d (%d%%) Collected", collected, total, percent))

        -- Color based on progress
        local COLORS = ns.UI.COLORS
        if percent >= 100 then
            frame.collectedLabel:SetTextColor(unpack(COLORS.progressComplete))
        elseif percent >= 50 then
            frame.collectedLabel:SetTextColor(unpack(COLORS.progressHigh))
        else
            frame.collectedLabel:SetTextColor(unpack(COLORS.progressLow))
        end
    else
        frame.collectedLabel:SetText("0 Items")
        frame.collectedLabel:SetTextColor(0.6, 0.8, 1)
    end

    -- Update section header
    frame.sectionHeader:SetText("Wishlist Items (" .. activeName .. ")")

    -- Build flattened data and create DataProvider
    local data = BuildDataProviderData(self)
    local dataProvider = CreateDataProvider(data)

    -- Set the DataProvider on the ScrollBox
    frame.scrollBox:SetDataProvider(dataProvider)
end

-- Show new wishlist dialog
function ns:ShowNewWishlistDialog()
    StaticPopupDialogs["LOOTWISHLIST_NEW_WISHLIST"] = {
        text = "New Wishlist Name:",
        button1 = "Create",
        button2 = "Cancel",
        hasEditBox = true,
        OnAccept = function(self)
            local name = self.EditBox:GetText()
            if name and name ~= "" then
                local success, err = ns:CreateWishlist(name)
                if success then
                    ns:SetActiveWishlist(name)
                    selectedItemID = nil
                    ns:RefreshMainWindow()
                else
                    print("|cff00ccffLootWishlist|r: " .. (err or "Failed to create wishlist"))
                end
            end
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            StaticPopupDialogs["LOOTWISHLIST_NEW_WISHLIST"].OnAccept(parent)
            parent:Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show("LOOTWISHLIST_NEW_WISHLIST")
end

-- Toggle item browser
function ns:ToggleItemBrowser()
    if ns.ItemBrowser then
        if ns.ItemBrowser:IsShown() then
            ns.ItemBrowser:Hide()
            if ns.MainWindow and ns.MainWindow.browseBtn then
                ns.MainWindow.browseBtn:SetText("Browse")
            end
        else
            ns.ItemBrowser:Show()
            if ns.MainWindow and ns.MainWindow.browseBtn then
                ns.MainWindow.browseBtn:SetText("Close")
            end
        end
    else
        ns:CreateItemBrowser()
        if ns.MainWindow and ns.MainWindow.browseBtn then
            ns.MainWindow.browseBtn:SetText("Close")
        end
    end
end
