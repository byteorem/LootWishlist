-- LootWishlist Core
-- Addon namespace and initialization

local addonName, ns = ...

-- Cache global functions
local pairs, ipairs, type, tostring = pairs, ipairs, type, tostring
local wipe, print = wipe, print
local CreateFrame, StaticPopup_Show = CreateFrame, StaticPopup_Show

-- Addon namespace
LootWishlist = ns
ns.addonName = addonName

-- Version info
ns.version = "1.0.0"

-- Event frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        ns:InitializeDatabase()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        ns:OnPlayerLogin()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_LOGOUT" then
        -- Remove checked items on logout
        ns:RemoveCheckedItems()
    end
end)

-- Called after player login
function ns:OnPlayerLogin()
    -- Initialize subsystems
    if ns.InitEvents then
        ns:InitEvents()
    end

    -- Initialize minimap icon
    ns:InitMinimapIcon()

    -- Initialize options panel
    if ns.InitOptionsPanel then
        ns:InitOptionsPanel()
    end

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
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("LootWishlist")
            tooltip:AddLine("|cffffffffLeft-click|r to toggle window", 0.7, 0.7, 0.7)
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
    elseif cmd == "add" and args ~= "" then
        local itemID = tonumber(args)
        if itemID then
            ns:AddItemToWishlist(itemID)
        else
            print("|cff00ccffLootWishlist|r: Invalid item ID.")
        end
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
    print("  |cff00ff00/lw add <itemID>|r - Add item by ID")
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

function ns:ResetDatabase()
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
    StaticPopup_Show("LOOTWISHLIST_RESET_CONFIRM")
end
