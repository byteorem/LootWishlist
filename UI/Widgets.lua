-- LootWishlist UI Widgets
-- Reusable UI components

local addonName, ns = ...

-- Cache global functions
local pairs, unpack = pairs, unpack
local CreateFrame, CreateColor = CreateFrame, CreateColor
local UIDropDownMenu_SetWidth = UIDropDownMenu_SetWidth

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

-- Create a collapsible header widget
function ns.UI:CreateCollapsibleHeader(parent, width)
    local header = CreateFrame("Button", nil, parent)
    header:SetSize(width or parent:GetWidth(), 32)

    -- Background gradient
    header.bg = self:CreateGradientTexture(header,
        COLORS.headerLeft,
        COLORS.headerRight)
    header.bg:SetDrawLayer("BACKGROUND", 0)

    -- Store original colors for hover
    header.normalColors = {COLORS.headerLeft, COLORS.headerRight}
    header.hoverColors = {COLORS.headerHoverLeft, COLORS.headerHoverRight}

    -- Expand/collapse icon (FontString for +/−)
    header.expandIcon = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header.expandIcon:SetPoint("LEFT", 8, 0)
    header.expandIcon:SetText("+")
    header.expandIcon:SetTextColor(0.8, 0.8, 0.8)

    -- Text label
    header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header.text:SetPoint("LEFT", header.expandIcon, "RIGHT", 6, 0)
    header.text:SetJustifyH("LEFT")

    -- Progress label (right side)
    header.progress = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.progress:SetPoint("RIGHT", -10, 0)
    header.progress:SetJustifyH("RIGHT")

    -- Hover effects
    header:SetScript("OnEnter", function(self)
        ns.UI:SetGradient(self.bg,
            self.hoverColors[1],
            self.hoverColors[2])
    end)

    header:SetScript("OnLeave", function(self)
        ns.UI:SetGradient(self.bg,
            self.normalColors[1],
            self.normalColors[2])
    end)

    return header
end

-- Set header collapsed state (+/−)
function ns.UI:SetHeaderState(header, isCollapsed)
    if isCollapsed then
        header.expandIcon:SetText("+")
    else
        header.expandIcon:SetText("−")
    end
end

-- Set header progress display with color coding
function ns.UI:SetHeaderProgress(header, completed, total)
    if total == 0 then
        header.progress:SetText("")
        return
    end

    local percent = math.floor((completed / total) * 100)
    local text = string.format("%d/%d (%d%%)", completed, total, percent)
    header.progress:SetText(text)

    -- Color based on progress
    if percent >= 100 then
        header.progress:SetTextColor(unpack(COLORS.progressComplete))
    elseif percent >= 50 then
        header.progress:SetTextColor(unpack(COLORS.progressHigh))
    else
        header.progress:SetTextColor(unpack(COLORS.progressLow))
    end
end

-- Create a basic button
function ns.UI:CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 100, height or 22)
    button:SetText(text or "")
    return button
end

-- Create an icon button
function ns.UI:CreateIconButton(parent, icon, size)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size or 24, size or 24)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexture(icon)

    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

    return button
end

-- Create a dropdown menu
function ns.UI:CreateDropdown(parent, label, width)
    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, width or 150)

    if label then
        local labelText = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        labelText:SetPoint("BOTTOMLEFT", dropdown, "TOPLEFT", 16, 3)
        labelText:SetText(label)
        dropdown.label = labelText
    end

    return dropdown
end

-- Create a search box
function ns.UI:CreateSearchBox(parent, width, height)
    local searchBox = CreateFrame("EditBox", nil, parent, "SearchBoxTemplate")
    searchBox:SetSize(width or 150, height or 20)
    searchBox:SetAutoFocus(false)

    return searchBox
end

-- Create a scroll frame with content
function ns.UI:CreateScrollFrame(parent, width, height)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(width or 200, height or 300)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(width or 200, 1) -- Height will be adjusted
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame.content = scrollChild

    return scrollFrame
end

-- Create item row for wishlist display
function ns.UI:CreateItemRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(parent:GetWidth() - 20, 32)

    -- Background
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)

    -- Collected checkmark
    row.collected = row:CreateTexture(nil, "ARTWORK")
    row.collected:SetSize(16, 16)
    row.collected:SetPoint("LEFT", 4, 0)
    row.collected:SetAtlas("common-icon-checkmark")
    row.collected:Hide()

    -- Icon
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(24, 24)
    row.icon:SetPoint("LEFT", row.collected, "RIGHT", 4, 0)

    -- Name
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -80, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    -- Slot type
    row.slot = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.slot:SetPoint("RIGHT", row, "RIGHT", -32, 0)
    row.slot:SetWidth(60)
    row.slot:SetJustifyH("RIGHT")
    row.slot:SetTextColor(0.7, 0.7, 0.7)

    -- Remove button
    row.removeBtn = CreateFrame("Button", nil, row)
    row.removeBtn:SetSize(16, 16)
    row.removeBtn:SetPoint("RIGHT", -8, 0)
    row.removeBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    row.removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
    row.removeBtn:GetHighlightTexture():SetVertexColor(1, 0.2, 0.2)

    -- Highlight
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    return row
end

-- Create instance/boss row for browser
function ns.UI:CreateBrowserRow(parent, rowType, dims)
    local row = CreateFrame("Button", nil, parent)
    row.rowType = rowType

    if rowType == "instance" then
        -- Instance header style (32px height)
        row:SetSize(parent:GetWidth() - 20, 32)

        -- Gradient background
        row.bg = self:CreateGradientTexture(row,
            COLORS.headerLeft,
            COLORS.headerRight)
        row.bg:SetDrawLayer("BACKGROUND", 0)

        -- Expand icon (FontString +/−)
        row.expand = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        row.expand:SetPoint("LEFT", 8, 0)
        row.expand:SetText("+")
        row.expand:SetTextColor(0.8, 0.8, 0.8)

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        row.name:SetPoint("LEFT", row.expand, "RIGHT", 6, 0)
        row.name:SetJustifyH("LEFT")

        -- Store colors for hover
        row.normalColors = {COLORS.headerLeft, COLORS.headerRight}
        row.hoverColors = {COLORS.headerHoverLeft, COLORS.headerHoverRight}

        row:SetScript("OnEnter", function(self)
            ns.UI:SetGradient(self.bg,
                self.hoverColors[1],
                self.hoverColors[2])
        end)

        row:SetScript("OnLeave", function(self)
            ns.UI:SetGradient(self.bg,
                self.normalColors[1],
                self.normalColors[2])
        end)

    elseif rowType == "boss" then
        -- Boss style (28px height for right panel, or use dims)
        local bossHeight = dims and dims.bossRowHeight or 28
        local bossFont = dims and dims.bossFont or "GameFontNormal"
        row:SetSize(parent:GetWidth() - 20, bossHeight)

        -- Gradient background
        row.bg = self:CreateGradientTexture(row,
            COLORS.headerLeft,
            COLORS.headerRight)
        row.bg:SetDrawLayer("BACKGROUND", 0)

        -- Expand/collapse icon (hidden - no longer used)
        row.expand = row:CreateFontString(nil, "OVERLAY", bossFont)
        row.expand:SetPoint("RIGHT", -8, 0)
        row.expand:SetText("")
        row.expand:Hide()

        row.name = row:CreateFontString(nil, "OVERLAY", bossFont)
        row.name:SetPoint("LEFT", 8, 0)
        row.name:SetPoint("RIGHT", -8, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)

        -- Store colors for hover (header style)
        row.normalColors = {COLORS.headerLeft, COLORS.headerRight}
        row.hoverColors = {COLORS.headerHoverLeft, COLORS.headerHoverRight}

        row:SetScript("OnEnter", function(self)
            ns.UI:SetGradient(self.bg,
                self.hoverColors[1],
                self.hoverColors[2])
        end)

        row:SetScript("OnLeave", function(self)
            ns.UI:SetGradient(self.bg,
                self.normalColors[1],
                self.normalColors[2])
        end)

    else
        -- Loot item style (22px height, or use dims)
        local lootHeight = dims and dims.lootRowHeight or 22
        local lootIconSize = dims and dims.lootIconSize or 18
        local lootNameFont = dims and dims.lootNameFont or "GameFontHighlightSmall"
        local lootSlotFont = dims and dims.lootSlotFont or "GameFontNormalSmall"

        -- Column order: Checkmark, Icon, Name, Slot, Add
        row:SetSize(parent:GetWidth() - 20, lootHeight)

        -- Checkmark for items already on wishlist (left edge indicator)
        row.checkmark = row:CreateTexture(nil, "ARTWORK")
        row.checkmark:SetSize(16, 16)
        row.checkmark:SetPoint("LEFT", 4, 0)
        row.checkmark:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
        row.checkmark:SetVertexColor(0.2, 1, 0.2)  -- Green
        row.checkmark:Hide()

        -- Icon (after checkmark)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(lootIconSize, lootIconSize)
        row.icon:SetPoint("LEFT", 16, 0)

        -- Name (after icon, before slot)
        row.name = row:CreateFontString(nil, "OVERLAY", lootNameFont)
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
        row.name:SetPoint("RIGHT", row, "RIGHT", -130, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)

        -- Slot label (before add button)
        row.slotLabel = row:CreateFontString(nil, "OVERLAY", lootSlotFont)
        row.slotLabel:SetPoint("RIGHT", -34, 0)
        row.slotLabel:SetWidth(110)
        row.slotLabel:SetJustifyH("RIGHT")
        row.slotLabel:SetTextColor(0.6, 0.6, 0.6)

        -- Add button (right edge) - yellow plus icon
        row.addBtn = CreateFrame("Button", nil, row)
        row.addBtn:SetSize(16, 16)
        row.addBtn:SetPoint("RIGHT", -4, 0)
        row.addBtn:SetNormalTexture("Interface\\PaperDollInfoFrame\\Character-Plus")
        row.addBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
        row.addBtn:GetNormalTexture():SetVertexColor(1, 0.82, 0)  -- Yellow/gold
    end

    return row
end

-- Create a simple tooltip helper
function ns.UI:SetupTooltip(frame, text, anchor)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
        if type(text) == "function" then
            text(GameTooltip, self)
        else
            GameTooltip:SetText(text)
        end
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
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

-- Create a profile table row (for LootProfile window)
function ns.UI:CreateProfileTableRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(24)

    -- Background gradient
    row.bg = self:CreateGradientTexture(row,
        COLORS.rowLeft,
        COLORS.rowRight)
    row.bg:SetDrawLayer("BACKGROUND", 0)

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

    -- Collected indicator (dot instead of checkmark)
    row.collected = row:CreateTexture(nil, "ARTWORK")
    row.collected:SetSize(10, 10)
    row.collected:SetPoint("LEFT", 6, 0)
    row.collected:SetTexture("Interface\\COMMON\\Indicator-Green")
    row.collected:Hide()

    -- Column order: Item (icon+name), Slot, Source

    -- Icon (first column, after collected indicator)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 22, 0)

    -- Name (after icon, within first column)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetWidth(140)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    -- Slot label (second column)
    row.slot = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.slot:SetPoint("LEFT", 190, 0)
    row.slot:SetWidth(60)
    row.slot:SetJustifyH("LEFT")
    row.slot:SetTextColor(0.7, 0.7, 0.7)

    -- Source (third column)
    row.source = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.source:SetPoint("LEFT", 260, 0)
    row.source:SetPoint("RIGHT", row, "RIGHT", -28, 0)
    row.source:SetJustifyH("LEFT")
    row.source:SetTextColor(0.6, 0.6, 0.6)
    row.source:SetWordWrap(false)

    -- Remove button (red X)
    row.removeBtn = CreateFrame("Button", nil, row)
    row.removeBtn:SetSize(16, 16)
    row.removeBtn:SetPoint("RIGHT", -6, 0)
    row.removeBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    row.removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
    row.removeBtn:GetHighlightTexture():SetVertexColor(1, 0.2, 0.2)

    -- Store colors for hover effects
    row.normalColors = {COLORS.rowLeft, COLORS.rowRight}
    row.hoverColors = {COLORS.rowHoverLeft, COLORS.rowHoverRight}

    -- Hover effects (gradient brightness change)
    row:SetScript("OnEnter", function(self)
        if not self.selectedBg:IsShown() then
            ns.UI:SetGradient(self.bg,
                self.hoverColors[1],
                self.hoverColors[2])
        end
    end)

    row:SetScript("OnLeave", function(self)
        if not self.selectedBg:IsShown() then
            ns.UI:SetGradient(self.bg,
                self.normalColors[1],
                self.normalColors[2])
        end
    end)

    return row
end

-- Create an edit box
function ns.UI:CreateEditBox(parent, width, height)
    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetSize(width or 150, height or 20)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    return editBox
end

-- Create a checkbox with label
function ns.UI:CreateCheckbox(parent, label)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)

    if label then
        local text = check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", check, "RIGHT", 2, 0)
        text:SetText(label)
        check.label = text
    end

    return check
end

-- Create instance list row for browser left panel
function ns.UI:CreateInstanceListRow(parent, height, font)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(parent:GetWidth(), height or 24)

    -- Background gradient
    row.bg = self:CreateGradientTexture(row,
        COLORS.rowLeft,
        COLORS.rowRight)
    row.bg:SetDrawLayer("BACKGROUND", 0)

    -- Selected highlight gradient
    row.selectedBg = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.selectedBg:SetAllPoints()
    row.selectedBg:SetColorTexture(1, 1, 1, 1)
    row.selectedBg:SetGradient("HORIZONTAL",
        CreateColor(unpack(COLORS.selectedLeft)),
        CreateColor(unpack(COLORS.selectedRight)))
    row.selectedBg:Hide()

    -- Expand arrow for expansion grouping
    row.arrow = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.arrow:SetPoint("LEFT", 4, 0)
    row.arrow:SetText(">")
    row.arrow:SetTextColor(0.6, 0.6, 0.6)
    row.arrow:Hide()

    -- Instance name
    row.name = row:CreateFontString(nil, "OVERLAY", font or "GameFontNormalSmall")
    row.name:SetPoint("LEFT", 8, 0)
    row.name:SetPoint("RIGHT", -4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    -- Store colors for hover effects
    row.normalColors = {COLORS.rowLeft, COLORS.rowRight}
    row.hoverColors = {COLORS.rowHoverLeft, COLORS.rowHoverRight}

    -- Hover effects
    row:SetScript("OnEnter", function(self)
        if not self.selectedBg:IsShown() then
            ns.UI:SetGradient(self.bg,
                self.hoverColors[1],
                self.hoverColors[2])
        end
    end)

    row:SetScript("OnLeave", function(self)
        if not self.selectedBg:IsShown() then
            ns.UI:SetGradient(self.bg,
                self.normalColors[1],
                self.normalColors[2])
        end
    end)

    return row
end

-- Set instance row selected state
function ns.UI:SetInstanceRowSelected(row, isSelected)
    if isSelected then
        row.selectedBg:Show()
        row.name:SetTextColor(1, 1, 1)
    else
        row.selectedBg:Hide()
        row.name:SetTextColor(0.9, 0.9, 0.9)
        ns.UI:SetGradient(row.bg, row.normalColors[1], row.normalColors[2])
    end
end

-- Progress bar widget
function ns.UI:CreateProgressBar(parent, width, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width or 100, height or 16)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.2, 0.6, 1)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.text:SetPoint("CENTER")
    bar.text:SetTextColor(1, 1, 1)

    return bar
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
-- Frame Pool Initializers (for CreateFramePool pattern)
-------------------------------------------------------------------------------

-- Initialize an instance list row (for pool pattern)
function ns.UI:InitInstanceListRow(row, dims)
    local height = dims and dims.instanceRowHeight or 24
    local font = dims and dims.instanceFont or "GameFontNormalSmall"

    row:SetSize(200, height)

    -- Background gradient
    row.bg = self:CreateGradientTexture(row,
        COLORS.rowLeft,
        COLORS.rowRight)
    row.bg:SetDrawLayer("BACKGROUND", 0)

    -- Selected highlight gradient
    row.selectedBg = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.selectedBg:SetAllPoints()
    row.selectedBg:SetColorTexture(1, 1, 1, 1)
    row.selectedBg:SetGradient("HORIZONTAL",
        CreateColor(unpack(COLORS.selectedLeft)),
        CreateColor(unpack(COLORS.selectedRight)))
    row.selectedBg:Hide()

    -- Expand arrow for expansion grouping
    row.arrow = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.arrow:SetPoint("LEFT", 4, 0)
    row.arrow:SetText(">")
    row.arrow:SetTextColor(0.6, 0.6, 0.6)
    row.arrow:Hide()

    -- Instance name
    row.name = row:CreateFontString(nil, "OVERLAY", font)
    row.name:SetPoint("LEFT", 8, 0)
    row.name:SetPoint("RIGHT", -4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    -- Store colors for hover effects
    row.normalColors = {COLORS.rowLeft, COLORS.rowRight}
    row.hoverColors = {COLORS.rowHoverLeft, COLORS.rowHoverRight}

    -- Hover effects
    row:SetScript("OnEnter", function(self)
        if not self.selectedBg:IsShown() then
            ns.UI:SetGradient(self.bg,
                self.hoverColors[1],
                self.hoverColors[2])
        end
    end)

    row:SetScript("OnLeave", function(self)
        if not self.selectedBg:IsShown() then
            ns.UI:SetGradient(self.bg,
                self.normalColors[1],
                self.normalColors[2])
        end
    end)
end

-- Initialize a boss header row (for pool pattern)
function ns.UI:InitBossRow(row, dims)
    local bossHeight = dims and dims.bossRowHeight or 28
    local bossFont = dims and dims.bossFont or "GameFontNormal"

    row:SetSize(200, bossHeight)
    row.rowType = "boss"

    -- Gradient background
    row.bg = self:CreateGradientTexture(row,
        COLORS.headerLeft,
        COLORS.headerRight)
    row.bg:SetDrawLayer("BACKGROUND", 0)

    -- Expand/collapse icon (hidden - no longer used)
    row.expand = row:CreateFontString(nil, "OVERLAY", bossFont)
    row.expand:SetPoint("RIGHT", -8, 0)
    row.expand:SetText("")
    row.expand:Hide()

    row.name = row:CreateFontString(nil, "OVERLAY", bossFont)
    row.name:SetPoint("LEFT", 8, 0)
    row.name:SetPoint("RIGHT", -8, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    -- Store colors for hover (header style)
    row.normalColors = {COLORS.headerLeft, COLORS.headerRight}
    row.hoverColors = {COLORS.headerHoverLeft, COLORS.headerHoverRight}

    row:SetScript("OnEnter", function(self)
        ns.UI:SetGradient(self.bg,
            self.hoverColors[1],
            self.hoverColors[2])
    end)

    row:SetScript("OnLeave", function(self)
        ns.UI:SetGradient(self.bg,
            self.normalColors[1],
            self.normalColors[2])
    end)
end

-- Initialize a loot item row (for pool pattern)
function ns.UI:InitLootRow(row, dims)
    local lootHeight = dims and dims.lootRowHeight or 22
    local lootIconSize = dims and dims.lootIconSize or 18
    local lootNameFont = dims and dims.lootNameFont or "GameFontHighlightSmall"
    local lootSlotFont = dims and dims.lootSlotFont or "GameFontNormalSmall"

    row:SetSize(200, lootHeight)
    row.rowType = "loot"

    -- Checkmark for items already on wishlist (left edge indicator)
    row.checkmark = row:CreateTexture(nil, "ARTWORK")
    row.checkmark:SetSize(16, 16)
    row.checkmark:SetPoint("LEFT", 4, 0)
    row.checkmark:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
    row.checkmark:SetVertexColor(0.2, 1, 0.2)  -- Green
    row.checkmark:Hide()

    -- Icon (after checkmark)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(lootIconSize, lootIconSize)
    row.icon:SetPoint("LEFT", 16, 0)

    -- Name (after icon, before track badge)
    row.name = row:CreateFontString(nil, "OVERLAY", lootNameFont)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    -- Track badge (after name, colored based on track)
    row.trackBadge = row:CreateFontString(nil, "OVERLAY", lootSlotFont)
    row.trackBadge:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
    row.trackBadge:SetJustifyH("LEFT")

    -- Slot label (before add button)
    row.slotLabel = row:CreateFontString(nil, "OVERLAY", lootSlotFont)
    row.slotLabel:SetPoint("RIGHT", -34, 0)
    row.slotLabel:SetWidth(110)
    row.slotLabel:SetJustifyH("RIGHT")
    row.slotLabel:SetTextColor(0.6, 0.6, 0.6)

    -- Add button (right edge) - yellow plus icon
    row.addBtn = CreateFrame("Button", nil, row)
    row.addBtn:SetSize(16, 16)
    row.addBtn:SetPoint("RIGHT", -4, 0)
    row.addBtn:SetNormalTexture("Interface\\PaperDollInfoFrame\\Character-Plus")
    row.addBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
    row.addBtn:GetNormalTexture():SetVertexColor(1, 0.82, 0)  -- Yellow/gold
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

    -- Checkmark for items already on wishlist
    row.checkmark = row:CreateTexture(nil, "ARTWORK")
    row.checkmark:SetSize(16, 16)
    row.checkmark:SetPoint("LEFT", 4, 0)
    row.checkmark:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
    row.checkmark:SetVertexColor(0.2, 1, 0.2)
    row.checkmark:Hide()

    -- Icon (for loot items)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(lootIconSize, lootIconSize)
    row.icon:SetPoint("LEFT", 16, 0)
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
