-- LootWishlist Core
-- Addon namespace and initialization

local addonName, ns = ...

-- Cache global functions
local wipe, print = wipe, print
local CreateFrame, StaticPopup_Show = CreateFrame, StaticPopup_Show
local ReloadUI = ReloadUI
local EventRegistry = EventRegistry

-- Addon namespace
LootWishlist = ns

-- Event frame (still needed for ADDON_LOADED which fires before EventRegistry is fully ready)
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        ns:InitializeDatabase()
        self:UnregisterEvent("ADDON_LOADED")

        -- Register remaining events using EventRegistry
        EventRegistry:RegisterFrameEventAndCallback(
            "PLAYER_LOGIN", ns.OnPlayerLogin, ns)
        EventRegistry:RegisterFrameEventAndCallback(
            "PLAYER_LOGOUT", ns.OnPlayerLogout, ns)
        EventRegistry:RegisterFrameEventAndCallback(
            "PLAYER_ENTERING_WORLD", ns.OnPlayerEnteringWorld, ns)
    end
end)

-- Event handlers
function ns:OnPlayerLogout()
    -- Remove checked items on logout
    self:RemoveCheckedItems()

    -- Cleanup all modules
    if self.CleanupEvents then self:CleanupEvents() end
    if self.CleanupMainWindow then self:CleanupMainWindow() end
    if self.CleanupItemBrowser then self:CleanupItemBrowser() end
end

function ns:OnPlayerEnteringWorld(event, isInitialLogin, isReloadingUi)
    -- Refresh MainWindow on zone transitions if it's shown
    if not isInitialLogin and not isReloadingUi then
        if ns.MainWindow and ns.MainWindow:IsShown() then
            ns:RefreshMainWindow()
        end
    end
end

-- Called after player login
function ns:OnPlayerLogin()
    -- Initialize subsystems
    ns:InitEvents()

    -- Initialize minimap icon
    ns:InitMinimapIcon()

    -- Initialize options panel
    ns:InitOptionsPanel()

    -- Print load message
    print("|cff00ccffLootWishlist|r loaded. Type |cff00ff00/lw|r for options.")
end

-- Initialize minimap icon using LibDBIcon
function ns:InitMinimapIcon()
    local LDB = LibStub("LibDataBroker-1.1")
    local LDBIcon = LibStub("LibDBIcon-1.0")

    local dataObj = LDB:NewDataObject("LootWishlist", {
        type = "launcher",
        icon = "Interface\\Icons\\INV_Misc_Bag_07",
        OnClick = function(_, button)
            if button == "LeftButton" then
                ns:ToggleMainWindow()
            elseif button == "RightButton" then
                ns:OpenSettings()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("LootWishlist")
            local profileName = ns:GetActiveWishlistName()
            local collected, total = ns:GetWishlistProgress()
            if total > 0 then
                local percent = math.floor((collected / total) * 100)
                tooltip:AddDoubleLine(
                    "|cffffffffProfile:|r " .. profileName,
                    string.format("%d/%d (%d%%)", collected, total, percent),
                    0, 1, 0,  -- Profile text color (green)
                    0.8, 0.8, 0.6  -- Progress text color (light gold)
                )
            else
                tooltip:AddLine("|cffffffffProfile:|r " .. profileName .. " (no items)", 0.6, 0.6, 0.6)
            end
            tooltip:AddLine("|cffffffffLeft-click|r to toggle window", 0.7, 0.7, 0.7)
            tooltip:AddLine("|cffffffffRight-click|r to open options", 0.7, 0.7, 0.7)
        end,
    })

    LDBIcon:Register("LootWishlist", dataObj, ns.db.settings.minimapIcon)
end

-- Slash commands
SLASH_LOOTWISHLIST1 = "/lw"
SLASH_LOOTWISHLIST2 = "/lootwishlist"

SlashCmdList["LOOTWISHLIST"] = function(msg)
    local cmd, args = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()

    if cmd == "" or cmd == "show" then
        ns:ToggleMainWindow()
    elseif cmd == "help" then
        ns:PrintHelp()
    elseif cmd == "config" or cmd == "settings" then
        ns:OpenSettings()
    elseif cmd == "add" then
        print("|cff00ccffLootWishlist|r: Use Browse panel to add items with track data.")
    elseif cmd == "test" then
        ns:TestAlert()
    elseif cmd == "reset" then
        ns:ResetDatabase()
    else
        print("|cff00ccffLootWishlist|r: Unknown command. Type |cff00ff00/lw help|r for options.")
    end
end

function ns:PrintHelp()
    print("|cff00ccffLootWishlist Commands:|r")
    print("  |cff00ff00/lw|r - Toggle main window")
    print("  |cff00ff00/lw help|r - Show this help")
    print("  |cff00ff00/lw config|r - Open settings")
    print("  |cff00ff00/lw test|r - Test alert system")
    print("  |cff00ff00/lw reset|r - Reset all data")
end

function ns:ToggleMainWindow()
    if ns.MainWindow then
        if ns.MainWindow:IsShown() then
            ns.MainWindow:Hide()
        else
            ns.MainWindow:Show()
        end
    else
        ns:CreateMainWindow()
    end
end

-- OpenSettings is defined in UI/Options.lua

function ns:TestAlert()
    if ns.ShowTestAlert then
        ns:ShowTestAlert()
    else
        print("|cff00ccffLootWishlist|r: Alert system not initialized.")
    end
end

-- Define StaticPopupDialogs once at load time (not recreated on each call)
StaticPopupDialogs["LOOTWISHLIST_RESET_CONFIRM"] = {
    text = "Reset all LootWishlist data? This cannot be undone.",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        wipe(LootWishlistDB)
        wipe(LootWishlistCharDB)
        ns:InitializeDatabase()
        print("|cff00ccffLootWishlist|r: Data reset.")
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["LOOTWISHLIST_DELETE_ALL_CONFIRM"] = {
    text = "Delete ALL LootWishlist data?\n\nThis will remove all wishlists, settings, and collected item tracking.\n\nType WISHLIST to confirm:",
    button1 = "Delete",
    button2 = "Cancel",
    hasEditBox = true,
    showAlert = true,
    OnShow = function(self)
        local acceptButton = self.button1 or (self.Buttons and self.Buttons[1])
        if acceptButton then acceptButton:Disable() end
        self.EditBox:SetText("")
        self.EditBox:SetFocus()
    end,
    EditBoxOnTextChanged = function(self)
        local parent = self:GetParent()
        local acceptButton = parent.button1 or (parent.Buttons and parent.Buttons[1])
        if acceptButton then
            if self:GetText():upper() == "WISHLIST" then
                acceptButton:Enable()
            else
                acceptButton:Disable()
            end
        end
    end,
    OnAccept = function()
        wipe(LootWishlistDB)
        wipe(LootWishlistCharDB)
        ns:InitializeDatabase()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function ns:ResetDatabase()
    StaticPopup_Show("LOOTWISHLIST_RESET_CONFIRM")
end

function ns:ShowDeleteAllDataDialog()
    StaticPopup_Show("LOOTWISHLIST_DELETE_ALL_CONFIRM")
end
