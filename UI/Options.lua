-- LootWishlist Options Panel
-- Interface > AddOns settings using WoW Settings API (11.0+)

local addonName, ns = ...

-- Sound options for dropdown
local SOUND_OPTIONS = {
    {value = 8959, label = "Raid Warning"},
    {value = 8174, label = "Ready Check"},
    {value = 3081, label = "Level Up"},
    {value = 567458, label = "UI Bonus Loot Roll End"},
    {value = 567482, label = "Treasure Found"},
}

function ns:InitOptionsPanel()
    local category = Settings.RegisterVerticalLayoutCategory("LootWishlist")

    -- Chat Alerts
    do
        local variable = "LootWishlist_ChatAlerts"
        local name = "Enable Chat Alerts"
        local tooltip = "Show a message in chat when a wishlist item drops."

        -- Signature: (category, variable, variableKey, variableTbl, variableType, name, defaultValue)
        local setting = Settings.RegisterAddOnSetting(category, variable, "chatAlertEnabled", ns.db.settings, Settings.VarType.Boolean, name, true)
        Settings.SetOnValueChangedCallback(variable, function(_, _, val)
            ns.db.settings.chatAlertEnabled = val
        end)
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    -- Sound Alerts
    do
        local variable = "LootWishlist_SoundAlerts"
        local name = "Enable Sound Alerts"
        local tooltip = "Play a sound when a wishlist item drops."

        local setting = Settings.RegisterAddOnSetting(category, variable, "soundEnabled", ns.db.settings, Settings.VarType.Boolean, name, true)
        Settings.SetOnValueChangedCallback(variable, function(_, _, val)
            ns.db.settings.soundEnabled = val
        end)
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    -- Glow Effects
    do
        local variable = "LootWishlist_GlowEffects"
        local name = "Enable Glow Effects"
        local tooltip = "Show a glow effect on wishlist items in the loot window."

        local setting = Settings.RegisterAddOnSetting(category, variable, "glowEnabled", ns.db.settings, Settings.VarType.Boolean, name, true)
        Settings.SetOnValueChangedCallback(variable, function(_, _, val)
            ns.db.settings.glowEnabled = val
        end)
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    -- Alert Sound Dropdown
    do
        local variable = "LootWishlist_AlertSound"
        local name = "Alert Sound"
        local tooltip = "Sound to play when a wishlist item drops."

        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            for _, sound in ipairs(SOUND_OPTIONS) do
                container:Add(sound.value, sound.label)
            end
            return container:GetData()
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "alertSound", ns.db.settings, Settings.VarType.Number, name, 8959)
        Settings.SetOnValueChangedCallback(variable, function(_, _, val)
            ns.db.settings.alertSound = val
        end)
        Settings.CreateDropdown(category, setting, GetOptions, tooltip)
    end

    -- Browser Size Dropdown
    do
        local variable = "LootWishlist_BrowserSize"
        local name = "Item Browser Size"
        local tooltip = "Size of the Item Browser window. Requires reopening the browser to take effect."

        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            container:Add(1, "Normal")
            container:Add(2, "Large")
            return container:GetData()
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "browserSize", ns.db.settings, Settings.VarType.Number, name, 1)
        Settings.SetOnValueChangedCallback(variable, function(_, _, val)
            ns.db.settings.browserSize = val
            if ns.ItemBrowser then
                ns.ItemBrowser:Hide()
                ns.ItemBrowser = nil
                -- Clear row pools so they recreate with new sizes
                ns:ClearBrowserRowPools()
            end
        end)
        Settings.CreateDropdown(category, setting, GetOptions, tooltip)
    end

    -- Hide Minimap Icon
    do
        local variable = "LootWishlist_HideMinimapIcon"
        local name = "Hide Minimap Icon"
        local tooltip = "Hide the LootWishlist minimap button."

        local setting = Settings.RegisterAddOnSetting(category, variable, "hide", ns.db.settings.minimapIcon, Settings.VarType.Boolean, name, false)
        Settings.SetOnValueChangedCallback(variable, function(_, _, val)
            ns.db.settings.minimapIcon.hide = val
            local LDBIcon = LibStub("LibDBIcon-1.0")
            if val then
                LDBIcon:Hide("LootWishlist")
            else
                LDBIcon:Show("LootWishlist")
            end
        end)
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
end

function ns:OpenSettings()
    if ns.settingsCategory then
        Settings.OpenToCategory(ns.settingsCategory:GetID())
    end
end
