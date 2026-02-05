-- LootWishlist Options Panel
-- Interface > AddOns settings using WoW Settings API (11.0+)

local addonName, ns = ...

-- Cache global functions
local CreateFrame = CreateFrame
local Settings = Settings
local PlaySound = PlaySound
local LibStub = LibStub

-- Sound options for dropdown
local SOUND_OPTIONS = {
    {value = 8959, label = "Raid Warning"},
    {value = 8174, label = "Ready Check"},
    {value = 3081, label = "Level Up"},
    {value = 567458, label = "UI Bonus Loot Roll End"},
    {value = 567482, label = "Treasure Found"},
}

local function CreateOptionsPanel()
    local panel = CreateFrame("Frame")
    panel:SetSize(600, 400)
    panel.name = "LootWishlist"

    local yOffset = -20
    local leftMargin = 20

    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", leftMargin, yOffset)
    title:SetText("LootWishlist Settings")
    yOffset = yOffset - 30

    -- Chat Alerts Checkbox
    local chatAlerts = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    chatAlerts:SetPoint("TOPLEFT", leftMargin, yOffset)
    chatAlerts.Text:SetText("Enable Chat Alerts")
    chatAlerts:SetChecked(ns.db.settings.chatAlertEnabled)
    chatAlerts:SetScript("OnClick", function(self)
        ns.db.settings.chatAlertEnabled = self:GetChecked()
    end)
    chatAlerts.tooltipText = "Show a message in chat when a wishlist item drops."
    yOffset = yOffset - 30

    -- Sound Alerts Checkbox
    local soundAlerts = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    soundAlerts:SetPoint("TOPLEFT", leftMargin, yOffset)
    soundAlerts.Text:SetText("Enable Sound Alerts")
    soundAlerts:SetChecked(ns.db.settings.soundEnabled)
    soundAlerts:SetScript("OnClick", function(self)
        ns.db.settings.soundEnabled = self:GetChecked()
    end)
    soundAlerts.tooltipText = "Play a sound when a wishlist item drops."
    yOffset = yOffset - 30

    -- Glow Effects Checkbox
    local glowEffects = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    glowEffects:SetPoint("TOPLEFT", leftMargin, yOffset)
    glowEffects.Text:SetText("Enable Glow Effects")
    glowEffects:SetChecked(ns.db.settings.glowEnabled)
    glowEffects:SetScript("OnClick", function(self)
        ns.db.settings.glowEnabled = self:GetChecked()
    end)
    glowEffects.tooltipText = "Show a glow effect on wishlist items in the loot window."
    yOffset = yOffset - 30

    -- Hide Minimap Icon Checkbox
    local hideMinimapIcon = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    hideMinimapIcon:SetPoint("TOPLEFT", leftMargin, yOffset)
    hideMinimapIcon.Text:SetText("Hide Minimap Icon")
    hideMinimapIcon:SetChecked(ns.db.settings.minimapIcon.hide)
    hideMinimapIcon:SetScript("OnClick", function(self)
        ns.db.settings.minimapIcon.hide = self:GetChecked()
        local LDBIcon = LibStub("LibDBIcon-1.0")
        if self:GetChecked() then
            LDBIcon:Hide("LootWishlist")
        else
            LDBIcon:Show("LootWishlist")
        end
    end)
    hideMinimapIcon.tooltipText = "Hide the LootWishlist minimap button."
    yOffset = yOffset - 40

    -- Alert Sound Dropdown
    local soundLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soundLabel:SetPoint("TOPLEFT", leftMargin, yOffset)
    soundLabel:SetText("Alert Sound:")

    local soundDropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    soundDropdown:SetPoint("LEFT", soundLabel, "RIGHT", 10, 0)
    soundDropdown:SetWidth(180)

    -- Helper to get current sound label
    local function GetSoundLabel(value)
        for _, sound in ipairs(SOUND_OPTIONS) do
            if sound.value == value then return sound.label end
        end
        return "Raid Warning"
    end

    soundDropdown:SetupMenu(function(dropdown, rootDescription)
        for _, sound in ipairs(SOUND_OPTIONS) do
            rootDescription:CreateRadio(sound.label,
                function() return ns.db.settings.alertSound == sound.value end,
                function()
                    ns.db.settings.alertSound = sound.value
                    dropdown:SetText(sound.label)
                    PlaySound(sound.value)
                end)
        end
    end)
    soundDropdown:SetText(GetSoundLabel(ns.db.settings.alertSound))
    yOffset = yOffset - 40

    -- Browser Size Dropdown
    local browserLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    browserLabel:SetPoint("TOPLEFT", leftMargin, yOffset)
    browserLabel:SetText("Item Browser Size:")

    local browserDropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    browserDropdown:SetPoint("LEFT", browserLabel, "RIGHT", 10, 0)
    browserDropdown:SetWidth(120)

    local browserSizeLabels = { [1] = "Normal", [2] = "Large" }

    browserDropdown:SetupMenu(function(dropdown, rootDescription)
        rootDescription:CreateRadio("Normal",
            function() return ns.db.settings.browserSize == 1 end,
            function()
                ns.db.settings.browserSize = 1
                dropdown:SetText("Normal")
                if ns.ItemBrowser then
                    ns.ItemBrowser:Hide()
                    ns.ItemBrowser = nil

                    if ns.MainWindow and ns.MainWindow.browseBtn then
                        ns.MainWindow.browseBtn:SetText("Browse")
                    end
                end
            end)
        rootDescription:CreateRadio("Large",
            function() return ns.db.settings.browserSize == 2 end,
            function()
                ns.db.settings.browserSize = 2
                dropdown:SetText("Large")
                if ns.ItemBrowser then
                    ns.ItemBrowser:Hide()
                    ns.ItemBrowser = nil

                    if ns.MainWindow and ns.MainWindow.browseBtn then
                        ns.MainWindow.browseBtn:SetText("Browse")
                    end
                end
            end)
    end)
    browserDropdown:SetText(browserSizeLabels[ns.db.settings.browserSize] or "Normal")
    yOffset = yOffset - 50

    -- Danger Zone Section
    local dangerHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dangerHeader:SetPoint("TOPLEFT", leftMargin, yOffset)
    dangerHeader:SetText("Danger Zone")
    dangerHeader:SetTextColor(1, 0.3, 0.3)
    yOffset = yOffset - 25

    local dangerWarning = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dangerWarning:SetPoint("TOPLEFT", leftMargin, yOffset)
    dangerWarning:SetText("Permanently delete all wishlists, settings, and collected item tracking.")
    dangerWarning:SetTextColor(0.7, 0.7, 0.7)
    yOffset = yOffset - 25

    -- Delete All Data Button
    local deleteButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    deleteButton:SetSize(140, 25)
    deleteButton:SetPoint("TOPLEFT", leftMargin, yOffset)
    deleteButton:SetText("Delete All Data")
    deleteButton.Text:SetTextColor(1, 0.3, 0.3)
    deleteButton:SetScript("OnClick", function()
        ns:ShowDeleteAllDataDialog()
    end)

    return panel
end

function ns:InitOptionsPanel()
    local panel = CreateOptionsPanel()
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
end

function ns:OpenSettings()
    if ns.settingsCategory then
        Settings.OpenToCategory(ns.settingsCategory:GetID())
    end
end
