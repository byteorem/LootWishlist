-- LootWishlist UI Widgets
-- Reusable UI components

local addonName, ns = ...

-- Cache global functions
local pairs, unpack = pairs, unpack
local CreateFrame, CreateColor = CreateFrame, CreateColor

ns.UI = ns.UI or {}

-- HomeBound-style colors
local COLORS = {
    -- Header gradient
    headerLeft = {0.12, 0.12, 0.12, 0.8},
    headerRight = {0.08, 0.08, 0.08, 0.8},
    -- Header hover gradient
    headerHoverLeft = {0.18, 0.18, 0.18, 1},
    headerHoverRight = {0.12, 0.12, 0.12, 1},
    -- Item row gradient
    rowLeft = {0.08, 0.08, 0.08, 0.6},
    rowRight = {0.05, 0.05, 0.05, 0.6},
    -- Item row hover gradient
    rowHoverLeft = {0.12, 0.12, 0.12, 0.8},
    rowHoverRight = {0.08, 0.08, 0.08, 0.8},
    -- Selected row gradient
    selectedLeft = {0.2, 0.2, 0.35, 0.7},
    selectedRight = {0.15, 0.15, 0.25, 0.7},
    -- Title bar gradient (vertical)
    titleTop = {0.18, 0.18, 0.18, 1},
    titleBottom = {0.12, 0.12, 0.12, 1},
    -- Progress colors
    progressComplete = {0.2, 1, 0.2},      -- 100% green
    progressHigh = {1, 0.82, 0},           -- >=50% gold
    progressLow = {0.9, 0.9, 0.9},         -- <50% white
    -- Title color
    titleGold = {1, 0.85, 0},
}

ns.UI.COLORS = COLORS

-- Create a horizontal gradient texture
function ns.UI:CreateGradientTexture(parent, color1, color2)
    local tex = parent:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetColorTexture(1, 1, 1, 1)
    tex:SetGradient("HORIZONTAL", CreateColor(unpack(color1)), CreateColor(unpack(color2)))
    return tex
end

-- Apply gradient to existing texture
function ns.UI:SetGradient(tex, color1, color2)
    tex:SetColorTexture(1, 1, 1, 1)
    tex:SetGradient("HORIZONTAL", CreateColor(unpack(color1)), CreateColor(unpack(color2)))
end

-- Create a basic button
function ns.UI:CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 100, height or 22)
    button:SetText(text or "")
    return button
end

-- Create a modern dropdown menu (WowStyle1DropdownTemplate)
function ns.UI:CreateModernDropdown(parent, width)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(width or 150)
    return dropdown
end

-- Create a search box
function ns.UI:CreateSearchBox(parent, width, height)
    local searchBox = CreateFrame("EditBox", nil, parent, "SearchBoxTemplate")
    searchBox:SetSize(width or 150, height or 20)
    searchBox:SetAutoFocus(false)

    return searchBox
end

-- Create panel background
function ns.UI:CreateBackground(frame)
    -- Main background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)

    -- Border
    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4},
    })
    border:SetBackdropBorderColor(0.5, 0.5, 0.5)

    return bg, border
end

-- Create title bar
function ns.UI:CreateTitleBar(frame, title)
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", -4, -4)
    titleBar:SetHeight(28)

    -- Vertical gradient background
    local bg = titleBar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 1)
    bg:SetGradient("VERTICAL",
        CreateColor(unpack(COLORS.titleBottom)),
        CreateColor(unpack(COLORS.titleTop)))

    local text = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("LEFT", 16, 0)
    text:SetText(title)
    text:SetTextColor(unpack(COLORS.titleGold))

    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -3, -3)
    closeBtn:SetSize(22, 22)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    titleBar.text = text
    titleBar.closeBtn = closeBtn

    return titleBar
end

-- Create a table header row
function ns.UI:CreateTableHeader(parent, columns)
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(24)

    -- Horizontal gradient background
    local bg = self:CreateGradientTexture(header,
        COLORS.headerLeft,
        COLORS.headerRight)

    header.columns = {}
    local xOffset = 0

    for i, col in ipairs(columns) do
        local label = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", xOffset + 4, 0)
        label:SetWidth(col.width - 8)
        label:SetJustifyH("LEFT")
        label:SetText(col.name)
        label:SetTextColor(0.8, 0.8, 0.6)
        header.columns[i] = label
        xOffset = xOffset + col.width
    end

    return header
end

-------------------------------------------------------------------------------
-- ScrollBox Row Helpers (for DataProvider pattern)
-------------------------------------------------------------------------------

-- Row height constants for ScrollBox
ns.UI.HEADER_ROW_HEIGHT = 32
ns.UI.ITEM_ROW_HEIGHT = 24

-- Initialize a ScrollBox row frame with all required elements
-- Called once per row when first created by ScrollBox
function ns.UI:InitializeScrollBoxRow(row)
    -- Enable mouse interaction
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Background gradient (always present)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, 1)

    -- Selected highlight gradient
    row.selectedBg = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.selectedBg:SetAllPoints()
    row.selectedBg:SetColorTexture(1, 1, 1, 1)
    row.selectedBg:SetGradient("HORIZONTAL",
        CreateColor(unpack(COLORS.selectedLeft)),
        CreateColor(unpack(COLORS.selectedRight)))
    row.selectedBg:Hide()

    -- Checked overlay (grayed out for checked-off items)
    row.checkedOverlay = row:CreateTexture(nil, "OVERLAY")
    row.checkedOverlay:SetAllPoints()
    row.checkedOverlay:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    row.checkedOverlay:Hide()

    -- Expand/collapse icon (for headers)
    row.expandIcon = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    row.expandIcon:SetPoint("LEFT", 8, 0)
    row.expandIcon:SetTextColor(0.8, 0.8, 0.8)
    row.expandIcon:Hide()

    -- Collected indicator (green dot for items)
    row.collected = row:CreateTexture(nil, "ARTWORK")
    row.collected:SetSize(10, 10)
    row.collected:SetPoint("LEFT", 6, 0)
    row.collected:SetTexture("Interface\\COMMON\\Indicator-Green")
    row.collected:Hide()

    -- Icon (for items)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 22, 0)
    row.icon:Hide()

    -- Text/Name label (for headers)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    row.text:SetPoint("LEFT", row.expandIcon, "RIGHT", 6, 0)
    row.text:SetJustifyH("LEFT")
    row.text:Hide()

    -- Name label (for items)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetWidth(110)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.name:Hide()

    -- Track badge (for items)
    row.trackBadge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.trackBadge:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
    row.trackBadge:SetJustifyH("LEFT")
    row.trackBadge:Hide()

    -- Legacy warning icon (for items without track data)
    row.legacyWarning = row:CreateTexture(nil, "ARTWORK")
    row.legacyWarning:SetSize(14, 14)
    row.legacyWarning:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
    row.legacyWarning:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
    row.legacyWarning:Hide()

    -- Progress label (for headers, right side)
    row.progress = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.progress:SetPoint("RIGHT", -10, 0)
    row.progress:SetJustifyH("RIGHT")
    row.progress:Hide()

    -- Slot label (for items)
    row.slot = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.slot:SetPoint("LEFT", 190, 0)
    row.slot:SetWidth(60)
    row.slot:SetJustifyH("LEFT")
    row.slot:SetTextColor(0.7, 0.7, 0.7)
    row.slot:Hide()

    -- Source label (for items)
    row.source = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.source:SetPoint("LEFT", 260, 0)
    row.source:SetPoint("RIGHT", row, "RIGHT", -28, 0)
    row.source:SetJustifyH("LEFT")
    row.source:SetTextColor(0.6, 0.6, 0.6)
    row.source:SetWordWrap(false)
    row.source:Hide()

    -- Remove button (for items)
    row.removeBtn = CreateFrame("Button", nil, row)
    row.removeBtn:SetSize(16, 16)
    row.removeBtn:SetPoint("RIGHT", -6, 0)
    row.removeBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    row.removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
    row.removeBtn:GetHighlightTexture():SetVertexColor(1, 0.2, 0.2)
    row.removeBtn:Hide()

    -- Mark as initialized
    row.initialized = true
end

-- Reset a ScrollBox row to default state
function ns.UI:ResetScrollBoxRow(row)
    -- Note: Do NOT call ClearAllPoints() here - ScrollBox manages positioning internally
    row:Hide()
    row.selectedBg:Hide()
    row.checkedOverlay:Hide()
    row.expandIcon:Hide()
    row.collected:Hide()
    row.icon:Hide()
    row.text:Hide()
    row.name:Hide()
    row.trackBadge:Hide()
    row.legacyWarning:Hide()
    row.progress:Hide()
    row.slot:Hide()
    row.source:Hide()
    row.removeBtn:Hide()
    row.rowType = nil
    row.data = nil

    -- Clear scripts
    row:SetScript("OnClick", nil)
    row:SetScript("OnEnter", nil)
    row:SetScript("OnLeave", nil)
    row.removeBtn:SetScript("OnClick", nil)
end

-- Configure a row as a header (instance/group header)
function ns.UI:SetupHeaderRow(row, data, width)
    row.rowType = "header"
    row.data = data
    row:SetSize(width, self.HEADER_ROW_HEIGHT)

    -- Set header gradient
    self:SetGradient(row.bg, COLORS.headerLeft, COLORS.headerRight)

    -- Store colors for hover
    row.normalColors = {COLORS.headerLeft, COLORS.headerRight}
    row.hoverColors = {COLORS.headerHoverLeft, COLORS.headerHoverRight}

    -- Show expand icon
    row.expandIcon:Show()
    if data.isCollapsed then
        row.expandIcon:SetText("+")
    else
        row.expandIcon:SetText("−")
    end

    -- Show header text
    row.text:SetText(data.instanceName or "Unknown")
    row.text:Show()

    -- Show progress
    if data.total and data.total > 0 then
        local percent = math.floor((data.collected / data.total) * 100)
        row.progress:SetText(string.format("%d/%d (%d%%)", data.collected, data.total, percent))

        -- Color based on progress
        if percent >= 100 then
            row.progress:SetTextColor(unpack(COLORS.progressComplete))
        elseif percent >= 50 then
            row.progress:SetTextColor(unpack(COLORS.progressHigh))
        else
            row.progress:SetTextColor(unpack(COLORS.progressLow))
        end
        row.progress:Show()
    end

    -- Hover effects
    row:SetScript("OnEnter", function(self)
        ns.UI:SetGradient(self.bg, self.hoverColors[1], self.hoverColors[2])
    end)
    row:SetScript("OnLeave", function(self)
        ns.UI:SetGradient(self.bg, self.normalColors[1], self.normalColors[2])
    end)
end

-- Configure a row as an item row
function ns.UI:SetupItemRow(row, data, width, itemInfo)
    row.rowType = "item"
    row.data = data
    row.itemID = data.itemID
    row:SetSize(width, self.ITEM_ROW_HEIGHT)

    -- Set item row gradient
    self:SetGradient(row.bg, COLORS.rowLeft, COLORS.rowRight)

    -- Store colors for hover
    row.normalColors = {COLORS.rowLeft, COLORS.rowRight}
    row.hoverColors = {COLORS.rowHoverLeft, COLORS.rowHoverRight}

    -- Show icon
    row.icon:Show()
    if itemInfo then
        row.icon:SetTexture(itemInfo.texture)
        row.name:SetText(itemInfo.name)

        -- Color by quality
        local r, g, b = unpack(ns:GetItemQualityColor(itemInfo.quality))
        row.name:SetTextColor(r, g, b)

        -- Slot info
        local slotName = ns:GetSlotName(itemInfo.equipSlot)
        row.slot:SetText(slotName)
        row.slot:Show()
    else
        row.icon:SetTexture(134400) -- Question mark
        row.name:SetText("Loading...")
        row.name:SetTextColor(0.5, 0.5, 0.5)
    end
    row.name:Show()

    -- Legacy warning (for items without track data)
    row.trackBadge:Hide()
    if data.upgradeTrack then
        row.legacyWarning:Hide()
    else
        row.legacyWarning:Show()
    end

    -- Source text (just boss name)
    local sourceText = data.sourceText or ""
    local bossName = sourceText:match("^([^,]+)") or sourceText
    row.source:SetText(bossName)
    row.source:Show()

    -- Collected state
    if data.isCollected then
        row.collected:Show()
        row.name:SetAlpha(0.6)
    else
        row.name:SetAlpha(1)
    end

    -- Selection state
    if data.isSelected then
        row.selectedBg:Show()
    end

    -- Checked state
    if data.isChecked then
        row.checkedOverlay:Show()
    end

    -- Show remove button
    row.removeBtn:Show()

    -- Hover effects
    row:SetScript("OnEnter", function(self)
        if not self.selectedBg:IsShown() then
            ns.UI:SetGradient(self.bg, self.hoverColors[1], self.hoverColors[2])
        end
        -- Show tooltip
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if data.itemLink then
            GameTooltip:SetHyperlink(data.itemLink)
        elseif itemInfo and itemInfo.link then
            GameTooltip:SetHyperlink(itemInfo.link)
        end

        -- Legacy warning only (no track info - native tooltip shows item level)
        if not data.upgradeTrack and data.isLegacy then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Needs track data for alerts.", 1, 0.5, 0.5)
            GameTooltip:AddLine("Remove and re-add from Browse panel.", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        if not self.selectedBg:IsShown() then
            ns.UI:SetGradient(self.bg, self.normalColors[1], self.normalColors[2])
        end
        GameTooltip:Hide()
    end)
end

-- Element extent calculator for mixed row heights
function ns.UI:GetRowExtent(dataIndex, elementData)
    if elementData.rowType == "header" then
        return self.HEADER_ROW_HEIGHT
    else
        return self.ITEM_ROW_HEIGHT
    end
end

-------------------------------------------------------------------------------
-- Browser ScrollBox Row Helpers (for DataProvider pattern in ItemBrowser)
-------------------------------------------------------------------------------

-- Browser row height constants
ns.UI.BROWSER_BOSS_ROW_HEIGHT = 28
ns.UI.BROWSER_LOOT_ROW_HEIGHT = 22

-- Initialize a browser ScrollBox row frame with all required elements
function ns.UI:InitBrowserScrollBoxRow(row, dims)
    local bossHeight = dims and dims.bossRowHeight or 28
    local lootHeight = dims and dims.lootRowHeight or 22
    local lootIconSize = dims and dims.lootIconSize or 18
    local bossFont = dims and dims.bossFont or "GameFontNormal"
    local lootNameFont = dims and dims.lootNameFont or "GameFontHighlightSmall"
    local lootSlotFont = dims and dims.lootSlotFont or "GameFontNormalSmall"

    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Background gradient (always present)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, 1)

    -- Boss name (for boss headers)
    row.bossName = row:CreateFontString(nil, "OVERLAY", bossFont)
    row.bossName:SetPoint("LEFT", 8, 0)
    row.bossName:SetPoint("RIGHT", -8, 0)
    row.bossName:SetJustifyH("LEFT")
    row.bossName:SetWordWrap(false)
    row.bossName:Hide()

    -- Checkmark for items already on wishlist (left of icon)
    row.checkmark = row:CreateTexture(nil, "ARTWORK")
    row.checkmark:SetSize(14, 14)
    row.checkmark:SetPoint("LEFT", 2, 0)
    row.checkmark:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
    row.checkmark:SetVertexColor(0.2, 1, 0.2)
    row.checkmark:Hide()

    -- Icon (for loot items, positioned after checkmark space)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(lootIconSize, lootIconSize)
    row.icon:SetPoint("LEFT", 18, 0)
    row.icon:Hide()

    -- Item name (for loot items)
    row.name = row:CreateFontString(nil, "OVERLAY", lootNameFont)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -130, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.name:Hide()

    -- Slot label (for loot items)
    row.slotLabel = row:CreateFontString(nil, "OVERLAY", lootSlotFont)
    row.slotLabel:SetPoint("RIGHT", -34, 0)
    row.slotLabel:SetWidth(110)
    row.slotLabel:SetJustifyH("RIGHT")
    row.slotLabel:SetTextColor(0.6, 0.6, 0.6)
    row.slotLabel:Hide()

    -- Add button (for loot items)
    row.addBtn = CreateFrame("Button", nil, row)
    row.addBtn:SetSize(16, 16)
    row.addBtn:SetPoint("RIGHT", -4, 0)
    row.addBtn:SetNormalTexture("Interface\\PaperDollInfoFrame\\Character-Plus")
    row.addBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
    row.addBtn:GetNormalTexture():SetVertexColor(1, 0.82, 0)
    row.addBtn:Hide()

    -- Store dims for later use
    row.dims = dims

    row.initialized = true
end

-- Reset a browser ScrollBox row to default state
function ns.UI:ResetBrowserScrollBoxRow(row)
    row:Hide()
    row.bossName:Hide()
    row.checkmark:Hide()
    row.icon:Hide()
    row.name:Hide()
    row.slotLabel:Hide()
    row.addBtn:Hide()
    row.rowType = nil
    row.data = nil
    row.itemID = nil
    row.itemLink = nil
    row.sourceText = nil
    row.track = nil

    -- Reset text colors
    if row.name then row.name:SetTextColor(1, 1, 1) end

    -- Clear scripts
    row:SetScript("OnClick", nil)
    row:SetScript("OnEnter", nil)
    row:SetScript("OnLeave", nil)
    row.addBtn:SetScript("OnClick", nil)
end

-- Configure a browser row as a boss header
function ns.UI:SetupBrowserBossRow(row, data, width)
    local dims = row.dims
    local bossHeight = dims and dims.bossRowHeight or 28

    row.rowType = "boss"
    row.data = data
    row:SetSize(width, bossHeight)

    -- Set header gradient
    self:SetGradient(row.bg, COLORS.headerLeft, COLORS.headerRight)

    -- Store colors for hover
    row.normalColors = {COLORS.headerLeft, COLORS.headerRight}
    row.hoverColors = {COLORS.headerHoverLeft, COLORS.headerHoverRight}

    -- Show boss name
    row.bossName:SetText(data.name or "Unknown")
    row.bossName:Show()

    -- Hover effects
    row:SetScript("OnEnter", function(self)
        ns.UI:SetGradient(self.bg, self.hoverColors[1], self.hoverColors[2])
    end)
    row:SetScript("OnLeave", function(self)
        ns.UI:SetGradient(self.bg, self.normalColors[1], self.normalColors[2])
    end)
end

-- Configure a browser row as a loot item
function ns.UI:SetupBrowserLootRow(row, data, width)
    local dims = row.dims
    local lootHeight = dims and dims.lootRowHeight or 22

    row.rowType = "loot"
    row.data = data
    row.itemID = data.itemID
    row.itemLink = data.link
    row:SetSize(width, lootHeight)

    -- Set row gradient (subtle)
    self:SetGradient(row.bg, COLORS.rowLeft, COLORS.rowRight)

    -- Store colors for hover
    row.normalColors = {COLORS.rowLeft, COLORS.rowRight}
    row.hoverColors = {COLORS.rowHoverLeft, COLORS.rowHoverRight}

    -- Show icon
    row.icon:SetTexture(data.icon or 134400)
    row.icon:Show()

    -- Show name
    row.name:SetText(data.name or "Loading...")
    row.name:Show()

    -- Show slot
    row.slotLabel:SetText(data.slot or "")
    row.slotLabel:Show()

    -- Show add button (may be hidden later if on wishlist)
    row.addBtn:Show()

    -- Hover effects
    row:SetScript("OnEnter", function(self)
        ns.UI:SetGradient(self.bg, self.hoverColors[1], self.hoverColors[2])
    end)
    row:SetScript("OnLeave", function(self)
        ns.UI:SetGradient(self.bg, self.normalColors[1], self.normalColors[2])
    end)
end

-- Get browser row extent for mixed heights
function ns.UI:GetBrowserRowExtent(dataIndex, elementData, dims)
    if elementData.rowType == "boss" then
        return dims and dims.bossRowHeight or self.BROWSER_BOSS_ROW_HEIGHT
    else
        return dims and dims.lootRowHeight or self.BROWSER_LOOT_ROW_HEIGHT
    end
end

-------------------------------------------------------------------------------
-- Instance List ScrollBox Row Helpers (for left panel DataProvider pattern)
-------------------------------------------------------------------------------

-- Instance row height constant
ns.UI.INSTANCE_ROW_HEIGHT = 24

-- Initialize an instance list ScrollBox row
function ns.UI:InitInstanceScrollBoxRow(row, dims)
    local height = dims and dims.instanceRowHeight or 24
    local font = dims and dims.instanceFont or "GameFontNormalSmall"

    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp")

    -- Background gradient
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, 1)

    -- Selected highlight gradient
    row.selectedBg = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.selectedBg:SetAllPoints()
    row.selectedBg:SetColorTexture(1, 1, 1, 1)
    row.selectedBg:SetGradient("HORIZONTAL",
        CreateColor(unpack(COLORS.selectedLeft)),
        CreateColor(unpack(COLORS.selectedRight)))
    row.selectedBg:Hide()

    -- Instance name
    row.name = row:CreateFontString(nil, "OVERLAY", font)
    row.name:SetPoint("LEFT", 8, 0)
    row.name:SetPoint("RIGHT", -4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    -- Store dims for later use
    row.dims = dims

    row.initialized = true
end

-- Reset an instance list ScrollBox row
function ns.UI:ResetInstanceScrollBoxRow(row)
    row:Hide()
    row.selectedBg:Hide()
    row.instanceID = nil
    row.instanceName = nil
    row:SetScript("OnClick", nil)
    row:SetScript("OnEnter", nil)
    row:SetScript("OnLeave", nil)
end

-- Configure an instance row with data
function ns.UI:SetupInstanceRow(row, data, width, isSelected)
    local dims = row.dims
    local height = dims and dims.instanceRowHeight or 24

    row:SetSize(width, height)
    row.instanceID = data.instanceID
    row.instanceName = data.name

    -- Set background gradient
    self:SetGradient(row.bg, COLORS.rowLeft, COLORS.rowRight)

    -- Store colors for hover
    row.normalColors = {COLORS.rowLeft, COLORS.rowRight}
    row.hoverColors = {COLORS.rowHoverLeft, COLORS.rowHoverRight}

    -- Show name
    row.name:SetText(data.name or "Unknown")

    -- Selection state
    if isSelected then
        row.selectedBg:Show()
        row.name:SetTextColor(1, 1, 1)
    else
        row.selectedBg:Hide()
        row.name:SetTextColor(0.9, 0.9, 0.9)
    end

    -- Hover effects
    row:SetScript("OnEnter", function(self)
        if not self.selectedBg:IsShown() then
            ns.UI:SetGradient(self.bg, self.hoverColors[1], self.hoverColors[2])
        end
    end)
    row:SetScript("OnLeave", function(self)
        if not self.selectedBg:IsShown() then
            ns.UI:SetGradient(self.bg, self.normalColors[1], self.normalColors[2])
        end
    end)
end

-- Get instance row extent (uniform height)
function ns.UI:GetInstanceRowExtent(dataIndex, elementData, dims)
    return dims and dims.instanceRowHeight or self.INSTANCE_ROW_HEIGHT
end
