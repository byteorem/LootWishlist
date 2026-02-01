-- LootWishlist Events
-- Loot detection and alerts

local addonName, ns = ...

-- Cache global functions
local pairs, wipe, tonumber = pairs, wipe, tonumber
local GetTime, GetNumLootItems = GetTime, GetNumLootItems
local GetLootSlotType, GetLootSlotInfo, GetLootSlotLink = GetLootSlotType, GetLootSlotInfo, GetLootSlotLink
local PlaySound, print = PlaySound, print
local C_Item, C_Timer = C_Item, C_Timer
local EventRegistry = EventRegistry
local ActionButton_ShowOverlayGlow, ActionButton_HideOverlayGlow = ActionButton_ShowOverlayGlow, ActionButton_HideOverlayGlow
local pcall = pcall

-- Safe secret value check (12.0.0+ compatibility)
local SafeIsSecretValue = issecretvalue or function() return false end

-- Active glow frames
local glowFrames = {}

-- Store callback handles for cleanup
local eventHandles = {}

-- Track pending loot checks
local pendingLootItems = {}

-- Throttle for BAG_UPDATE_DELAYED
local lastBagUpdate = 0
local BAG_UPDATE_THROTTLE = 0.5  -- seconds

-- Event handler functions
function ns:OnLootReady(event, autoLoot)
    self:CheckLootWindow()
end

function ns:OnLootOpened(event)
    self:CheckLootWindow()
end

function ns:OnLootSlotChanged(event, slot)
    self:CheckLootSlot(slot)
end

function ns:OnLootClosed(event)
    self:ClearLootGlows()
    wipe(pendingLootItems)
end

function ns:OnBagUpdateDelayed(event)
    -- Throttle rapid bag updates when looting multiple items
    local now = GetTime()
    if now - lastBagUpdate < BAG_UPDATE_THROTTLE then return end
    lastBagUpdate = now

    -- Check if any pending items were looted
    for itemID in pairs(pendingLootItems) do
        local count = C_Item.GetItemCount(itemID, true)
        if count > 0 then
            self:OnItemLooted(itemID)
        end
    end
end

function ns:OnChatMsgLoot(event, msg, ...)
    -- Parse loot message for item IDs
    local itemLink = msg:match("|c%x+|Hitem:(%d+).-|h")
    if itemLink then
        local itemID = tonumber(itemLink)
        if itemID and self:IsItemOnWishlist(itemID) then
            self:OnItemLooted(itemID)
        end
    end
end

-- Initialize events using EventRegistry callbacks
function ns:InitEvents()
    -- Register each event with its handler using EventRegistry
    eventHandles.lootReady = EventRegistry:RegisterFrameEventAndCallback(
        "LOOT_READY", self.OnLootReady, self)
    eventHandles.lootOpened = EventRegistry:RegisterFrameEventAndCallback(
        "LOOT_OPENED", self.OnLootOpened, self)
    eventHandles.lootSlotChanged = EventRegistry:RegisterFrameEventAndCallback(
        "LOOT_SLOT_CHANGED", self.OnLootSlotChanged, self)
    eventHandles.lootClosed = EventRegistry:RegisterFrameEventAndCallback(
        "LOOT_CLOSED", self.OnLootClosed, self)
    eventHandles.bagUpdateDelayed = EventRegistry:RegisterFrameEventAndCallback(
        "BAG_UPDATE_DELAYED", self.OnBagUpdateDelayed, self)
    eventHandles.chatMsgLoot = EventRegistry:RegisterFrameEventAndCallback(
        "CHAT_MSG_LOOT", self.OnChatMsgLoot, self)
end

-- Cleanup events (for potential addon unload scenarios)
function ns:CleanupEvents()
    for name, handle in pairs(eventHandles) do
        if handle then
            EventRegistry:UnregisterFrameEventAndCallback(handle)
            eventHandles[name] = nil
        end
    end
end

-- Check all loot slots
function ns:CheckLootWindow()
    local numLootItems = GetNumLootItems()

    for slot = 1, numLootItems do
        self:CheckLootSlot(slot)
    end
end

-- Check a specific loot slot
function ns:CheckLootSlot(slot)
    if not slot then return end

    local lootSlotType = GetLootSlotType(slot)
    if not lootSlotType or lootSlotType ~= Enum.LootSlotType.Item then
        return
    end

    local lootIcon, lootName = GetLootSlotInfo(slot)

    -- Skip if loot info unavailable (locked/unavailable items return nil)
    if not lootIcon or not lootName then
        return
    end

    local lootLink = GetLootSlotLink(slot)
    if not lootLink then return end

    -- Skip secret values (12.0.0+)
    if SafeIsSecretValue(lootName) or SafeIsSecretValue(lootLink) then
        return
    end

    local itemID = tonumber(lootLink:match("item:(%d+)"))
    if not itemID then return end

    local isOnWishlist, wishlistName = self:IsItemOnWishlist(itemID)
    if not isOnWishlist then return end

    if self:IsItemCollected(itemID) then return end

    self:ShowLootAlert(slot, itemID, lootLink, wishlistName)
    pendingLootItems[itemID] = true
end

-- Show alert for wishlist item
function ns:ShowLootAlert(slot, itemID, itemLink, wishlistName)
    -- Chat alert
    if self:GetSetting("chatAlertEnabled") then
        print("|cff00ff00[LootWishlist]|r Wishlist item found: " .. itemLink)
    end

    -- Sound alert
    if self:GetSetting("soundEnabled") then
        local soundID = self:GetSetting("alertSound") or 8959
        PlaySound(soundID, "Master")
    end

    -- Glow effect on loot frame
    if self:GetSetting("glowEnabled") then
        self:ShowLootGlow(slot)
    end
end

-- Show glow on loot frame button
function ns:ShowLootGlow(slot)
    -- Try to find the loot frame button
    local button = _G["LootButton" .. slot]

    if button and button:IsShown() then
        if LootFrame.SpellHighlightAnim then
            -- Use built-in highlight if available (with pcall for safety)
            local success = pcall(ActionButton_ShowOverlayGlow, button)
            if success then
                glowFrames[slot] = button
            end
        else
            -- Create custom glow
            self:CreateCustomGlow(button, slot)
        end
    end
end

-- Create custom glow effect using C_Timer
function ns:CreateCustomGlow(button, slot)
    local glow = button.WishlistGlow
    if not glow then
        glow = button:CreateTexture(nil, "OVERLAY")
        glow:SetAllPoints()
        glow:SetAtlas("bags-glow-flash")
        glow:SetBlendMode("ADD")
        glow:SetAlpha(0)
        button.WishlistGlow = glow
    end

    glow:Show()

    -- Cancel existing timer
    if glow.pulseTimer then
        glow.pulseTimer:Cancel()
        glow.pulseTimer = nil
    end

    -- Pulse animation using C_Timer
    local fadingIn = true
    local function PulseGlow()
        if not glow or not glow:IsShown() then
            if glow and glow.pulseTimer then
                glow.pulseTimer:Cancel()
                glow.pulseTimer = nil
            end
            return
        end
        glow:SetAlpha(fadingIn and 0.8 or 0)
        fadingIn = not fadingIn
    end

    PulseGlow()
    glow.pulseTimer = C_Timer.NewTicker(0.5, PulseGlow)
    glowFrames[slot] = button
end

-- Clear all loot glows
function ns:ClearLootGlows()
    for slot, button in pairs(glowFrames) do
        if button then
            pcall(function()
                if button.WishlistGlow then
                    if button.WishlistGlow.pulseTimer then
                        button.WishlistGlow.pulseTimer:Cancel()
                        button.WishlistGlow.pulseTimer = nil
                    end
                    button.WishlistGlow:Hide()
                    button.WishlistGlow:SetAlpha(0)
                end
            end)
            pcall(ActionButton_HideOverlayGlow, button)
        end
    end
    wipe(glowFrames)
end

-- Handle item looted
function ns:OnItemLooted(itemID)
    if not self:IsItemOnWishlist(itemID) then return end
    if self:IsItemCollected(itemID) then return end

    -- Mark as collected
    self:MarkItemCollected(itemID)
    pendingLootItems[itemID] = nil

    -- Get item info for message
    local info = self:GetCachedItemInfo(itemID)
    local itemName = info and info.link or ("Item " .. itemID)

    print("|cff00ff00[LootWishlist]|r Collected: " .. itemName)

    -- Update UI if open
    if ns.MainWindow and ns.MainWindow:IsShown() then
        ns:RefreshMainWindow()
    end
end

-- Test alert system
function ns:ShowTestAlert()
    print("|cff00ff00[LootWishlist]|r Testing alert system...")

    -- Chat alert
    if self:GetSetting("chatAlertEnabled") then
        print("|cff00ff00[LootWishlist]|r Wishlist item found: |cff0070dd[Test Item]|r")
    end

    -- Sound alert
    if self:GetSetting("soundEnabled") then
        local soundID = self:GetSetting("alertSound") or 8959
        PlaySound(soundID, "Master")
    end

    print("|cff00ff00[LootWishlist]|r Alert test complete.")
end
