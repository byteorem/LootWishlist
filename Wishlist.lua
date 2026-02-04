-- LootWishlist Wishlist
-- Wishlist CRUD operations

local addonName, ns = ...

-- Cache global functions
local pairs, ipairs, type, tonumber = pairs, ipairs, type, tonumber
local tinsert, wipe = table.insert, wipe
local C_Item, CopyTable = C_Item, CopyTable

-- Item cache for async loading with LRU eviction
ns.itemCache = {}
local MAX_CACHE_SIZE = 500

-- O(1) LRU tracking: doubly linked list + hash map
local lruNodes = {}  -- itemID -> {prev, next, itemID}
local lruHead = nil  -- Oldest (first to evict)
local lruTail = nil  -- Most recently used
local lruSize = 0

-- Wishlist lookup index for O(1) item checks
-- Structure: wishlistIndex[itemID] = {wishlistName1 = true, wishlistName2 = true, ...}
local wishlistIndex = {}

-- Constants for validation
local MAX_WISHLIST_NAME_LENGTH = 50

-- LRU cache helpers - O(1) operations
local function TouchCache(itemID)
    local node = lruNodes[itemID]
    if not node then return end

    -- Already at tail (most recent), nothing to do
    if lruTail == node then return end

    -- Unlink node from current position
    if node.prev then
        node.prev.next = node.next
    else
        -- Node is head
        lruHead = node.next
    end
    if node.next then
        node.next.prev = node.prev
    end

    -- Append to tail (most recently used)
    node.prev = lruTail
    node.next = nil
    if lruTail then
        lruTail.next = node
    end
    lruTail = node
    if not lruHead then
        lruHead = node
    end
end

local function AddToLRU(itemID)
    if lruNodes[itemID] then
        TouchCache(itemID)
        return
    end

    local node = {prev = lruTail, next = nil, itemID = itemID}
    lruNodes[itemID] = node

    if lruTail then
        lruTail.next = node
    end
    lruTail = node
    if not lruHead then
        lruHead = node
    end
    lruSize = lruSize + 1
end

local function RemoveFromLRU(itemID)
    local node = lruNodes[itemID]
    if not node then return end

    if node.prev then
        node.prev.next = node.next
    else
        lruHead = node.next
    end
    if node.next then
        node.next.prev = node.prev
    else
        lruTail = node.prev
    end

    lruNodes[itemID] = nil
    lruSize = lruSize - 1
end

local function PruneCache()
    -- Remove oldest entries until under MAX_CACHE_SIZE
    while lruSize > MAX_CACHE_SIZE and lruHead do
        local oldestID = lruHead.itemID
        RemoveFromLRU(oldestID)
        ns.itemCache[oldestID] = nil
    end
end

-- Wishlist index helpers for O(1) lookups
local function RebuildIndex()
    wipe(wishlistIndex)
    if not ns.db or not ns.db.wishlists then return end

    for wishlistName, wishlist in pairs(ns.db.wishlists) do
        if wishlist.items then
            for _, entry in ipairs(wishlist.items) do
                if entry.itemID then
                    if not wishlistIndex[entry.itemID] then
                        wishlistIndex[entry.itemID] = {}
                    end
                    wishlistIndex[entry.itemID][wishlistName] = true
                end
            end
        end
    end
end

local function AddToIndex(itemID, wishlistName)
    if not itemID or not wishlistName then return end
    if not wishlistIndex[itemID] then
        wishlistIndex[itemID] = {}
    end
    wishlistIndex[itemID][wishlistName] = true
end

local function RemoveFromIndex(itemID, wishlistName)
    if not itemID or not wishlistName then return end
    if wishlistIndex[itemID] then
        wishlistIndex[itemID][wishlistName] = nil
        -- Clean up empty entries
        if not next(wishlistIndex[itemID]) then
            wishlistIndex[itemID] = nil
        end
    end
end

-- Export RebuildIndex for use after database initialization
ns.RebuildWishlistIndex = RebuildIndex

-- Validate wishlist name
local function ValidateWishlistName(name, existingWishlists)
    if not name or name == "" then
        return false, "Wishlist name cannot be empty"
    end

    local trimmed = name:match("^%s*(.-)%s*$") or ""
    if trimmed == "" then
        return false, "Wishlist name cannot be only whitespace"
    end

    if #trimmed > MAX_WISHLIST_NAME_LENGTH then
        return false, "Wishlist name cannot exceed " .. MAX_WISHLIST_NAME_LENGTH .. " characters"
    end

    if existingWishlists[trimmed] then
        return false, "Wishlist already exists"
    end

    return true, trimmed
end

-- Create a new wishlist
function ns:CreateWishlist(name)
    local success, result = ValidateWishlistName(name, self.db.wishlists)
    if not success then
        return false, result
    end

    local cleanName = result
    self.db.wishlists[cleanName] = { items = {} }
    return true
end

-- Delete a wishlist
function ns:DeleteWishlist(name)
    if name == "Default" then
        return false, "Cannot delete the Default wishlist"
    end

    if not self.db.wishlists[name] then
        return false, "Wishlist does not exist"
    end

    -- Remove from index before deleting
    local wishlist = self.db.wishlists[name]
    if wishlist.items then
        for _, entry in ipairs(wishlist.items) do
            RemoveFromIndex(entry.itemID, name)
        end
    end

    self.db.wishlists[name] = nil

    -- Switch to Default if active wishlist was deleted
    if self:GetActiveWishlistName() == name then
        self:SetCharSetting("activeWishlist", "Default")
    end

    return true
end

-- Rename a wishlist
function ns:RenameWishlist(oldName, newName)
    if not newName or newName == "" then
        return false, "New name cannot be empty"
    end

    if oldName == "Default" then
        return false, "Cannot rename the Default wishlist"
    end

    if not self.db.wishlists[oldName] then
        return false, "Wishlist does not exist"
    end

    if self.db.wishlists[newName] then
        return false, "A wishlist with that name already exists"
    end

    self.db.wishlists[newName] = self.db.wishlists[oldName]
    self.db.wishlists[oldName] = nil

    -- Update index: remove old name, add new name
    local wishlist = self.db.wishlists[newName]
    if wishlist.items then
        for _, entry in ipairs(wishlist.items) do
            RemoveFromIndex(entry.itemID, oldName)
            AddToIndex(entry.itemID, newName)
        end
    end

    -- Update active wishlist if it was renamed
    if self:GetActiveWishlistName() == oldName then
        self:SetCharSetting("activeWishlist", newName)
    end

    return true
end

-- Duplicate a wishlist
function ns:DuplicateWishlist(name, newName)
    if not self.db.wishlists[name] then
        return false, "Wishlist does not exist"
    end

    if not newName or newName == "" then
        newName = name .. " Copy"
    end

    -- Ensure unique name
    local baseName = newName
    local counter = 1
    while self.db.wishlists[newName] do
        counter = counter + 1
        newName = baseName .. " " .. counter
    end

    -- Deep copy the wishlist
    self.db.wishlists[newName] = {
        items = CopyTable(self.db.wishlists[name].items),
    }

    -- Update index for new wishlist
    local wishlist = self.db.wishlists[newName]
    if wishlist.items then
        for _, entry in ipairs(wishlist.items) do
            AddToIndex(entry.itemID, newName)
        end
    end

    return true, newName
end

-- Set active wishlist
function ns:SetActiveWishlist(name)
    if not self.db.wishlists[name] then
        return false, "Wishlist does not exist"
    end

    self:SetCharSetting("activeWishlist", name)
    return true
end

-- Add item to active wishlist
function ns:AddItemToWishlist(itemID, wishlistName, sourceText, upgradeTrack, itemLink)
    wishlistName = wishlistName or self:GetActiveWishlistName()
    local wishlist = self.db.wishlists[wishlistName]

    if not wishlist then
        return false, "Wishlist does not exist"
    end

    -- Check if already in wishlist (same itemID, sourceText, AND upgradeTrack)
    for _, entry in ipairs(wishlist.items) do
        if entry.itemID == itemID and entry.sourceText == (sourceText or "") and entry.upgradeTrack == upgradeTrack then
            return false, "Item already in wishlist"
        end
    end

    table.insert(wishlist.items, {
        itemID = itemID,
        sourceText = sourceText or "",
        upgradeTrack = upgradeTrack,
        itemLink = itemLink,
    })

    -- Update index
    AddToIndex(itemID, wishlistName)

    -- Cache item info
    self:CacheItemInfo(itemID)

    -- Notify state change
    ns.State:Notify(ns.StateEvents.ITEMS_CHANGED, {
        action = "add",
        wishlist = wishlistName,
        itemID = itemID,
        sourceText = sourceText,
    })

    return true
end

-- Remove item from wishlist
function ns:RemoveItemFromWishlist(itemID, sourceText, wishlistName)
    wishlistName = wishlistName or self:GetActiveWishlistName()
    local wishlist = self.db.wishlists[wishlistName]

    if not wishlist then
        return false, "Wishlist does not exist"
    end

    for i, entry in ipairs(wishlist.items) do
        if entry.itemID == itemID and entry.sourceText == (sourceText or "") then
            table.remove(wishlist.items, i)

            -- Update index: check if item still exists in this wishlist
            local stillExists = false
            for _, e in ipairs(wishlist.items) do
                if e.itemID == itemID then
                    stillExists = true
                    break
                end
            end
            if not stillExists then
                RemoveFromIndex(itemID, wishlistName)
            end

            -- Notify state change
            ns.State:Notify(ns.StateEvents.ITEMS_CHANGED, {
                action = "remove",
                wishlist = wishlistName,
                itemID = itemID,
                sourceText = sourceText,
            })

            return true
        end
    end

    return false, "Item not in wishlist"
end

-- Get items in active wishlist
function ns:GetWishlistItems(wishlistName)
    wishlistName = wishlistName or self:GetActiveWishlistName()
    local wishlist = self.db.wishlists[wishlistName]

    if not wishlist then
        return {}
    end

    return wishlist.items
end

-- Check if item is on any wishlist (O(1) lookup using index)
function ns:IsItemOnWishlist(itemID, wishlistName)
    -- Use index for fast lookup
    local itemWishlists = wishlistIndex[itemID]
    if not itemWishlists then
        return false
    end

    if wishlistName then
        -- Check specific wishlist
        return itemWishlists[wishlistName] == true
    end

    -- Return first wishlist that contains this item
    for name in pairs(itemWishlists) do
        return true, name
    end

    return false
end

-- Check if item with specific source is on wishlist
function ns:IsItemOnWishlistWithSource(itemID, sourceText, wishlistName, upgradeTrack)
    wishlistName = wishlistName or self:GetActiveWishlistName()
    local wishlist = self.db.wishlists[wishlistName]

    if not wishlist then
        return false
    end

    for _, entry in ipairs(wishlist.items) do
        if entry.itemID == itemID and entry.sourceText == (sourceText or "") then
            -- If upgradeTrack specified, also check track matches
            if upgradeTrack == nil or entry.upgradeTrack == upgradeTrack then
                return true
            end
        end
    end

    return false
end

-- Cache item info for async loading (with LRU eviction)
function ns:CacheItemInfo(itemID)
    if self.itemCache[itemID] then
        TouchCache(itemID)
        return self.itemCache[itemID]
    end

    local name, link, quality, iLevel, reqLevel, class, subclass,
          maxStack, equipSlot, texture, sellPrice, classID, subclassID,
          bindType, expacID, setID, isCraftingReagent = C_Item.GetItemInfo(itemID)

    if name then
        self.itemCache[itemID] = {
            itemID = itemID,
            name = name,
            link = link,
            quality = quality or 1,
            iLevel = iLevel or 0,
            equipSlot = equipSlot or "",
            texture = texture or 134400, -- Question mark icon
            classID = classID,
            subclassID = subclassID,
        }
        AddToLRU(itemID)
        PruneCache()
        return self.itemCache[itemID]
    end

    -- Item not cached yet, request it
    C_Item.RequestLoadItemDataByID(itemID)
    return nil
end

-- Get cached item info
function ns:GetCachedItemInfo(itemID)
    if self.itemCache[itemID] then
        TouchCache(itemID)
        return self.itemCache[itemID]
    end
    return self:CacheItemInfo(itemID)
end

-- Calculate wishlist progress
function ns:GetWishlistProgress(wishlistName)
    wishlistName = wishlistName or self:GetActiveWishlistName()
    local items = self:GetWishlistItems(wishlistName)
    local total = #items
    local collected = 0

    for _, entry in ipairs(items) do
        if self:IsItemCollected(entry.itemID) then
            collected = collected + 1
        end
    end

    return collected, total
end

-- Update upgrade track for a wishlist item
function ns:UpdateItemTrack(itemID, sourceText, newTrack, wishlistName)
    wishlistName = wishlistName or self:GetActiveWishlistName()
    local wishlist = self.db.wishlists[wishlistName]

    if not wishlist then
        return false, "Wishlist does not exist"
    end

    for _, entry in ipairs(wishlist.items) do
        if entry.itemID == itemID and entry.sourceText == (sourceText or "") then
            entry.upgradeTrack = newTrack
            return true
        end
    end

    return false, "Item not in wishlist"
end

-- Get item quality color (uses ColorManager API for accessibility/colorblind support)
function ns:GetItemQualityColor(quality)
    -- Use modern ColorManager API (11.1.5+) if available
    if ColorManager and ColorManager.GetColorDataForItemQuality then
        local colorData = ColorManager.GetColorDataForItemQuality(quality)
        if colorData then
            return {colorData.r, colorData.g, colorData.b}
        end
    end

    -- Fallback for older clients
    local colors = {
        [0] = {0.62, 0.62, 0.62}, -- Poor (gray)
        [1] = {1, 1, 1},          -- Common (white)
        [2] = {0.12, 1, 0},       -- Uncommon (green)
        [3] = {0, 0.44, 0.87},    -- Rare (blue)
        [4] = {0.64, 0.21, 0.93}, -- Epic (purple)
        [5] = {1, 0.5, 0},        -- Legendary (orange)
        [6] = {0.9, 0.8, 0.5},    -- Artifact (light gold)
        [7] = {0, 0.8, 1},        -- Heirloom (light blue)
    }
    return colors[quality] or colors[1]
end

-- Get slot name from inventory type
function ns:GetSlotName(equipSlot)
    local slotNames = {
        INVTYPE_HEAD = "Head",
        INVTYPE_NECK = "Neck",
        INVTYPE_SHOULDER = "Shoulder",
        INVTYPE_CLOAK = "Back",
        INVTYPE_CHEST = "Chest",
        INVTYPE_ROBE = "Chest",
        INVTYPE_WRIST = "Wrist",
        INVTYPE_HAND = "Hands",
        INVTYPE_WAIST = "Waist",
        INVTYPE_LEGS = "Legs",
        INVTYPE_FEET = "Feet",
        INVTYPE_FINGER = "Finger",
        INVTYPE_TRINKET = "Trinket",
        INVTYPE_WEAPON = "One-Hand",
        INVTYPE_SHIELD = "Off Hand",
        INVTYPE_2HWEAPON = "Two-Hand",
        INVTYPE_WEAPONMAINHAND = "Main Hand",
        INVTYPE_WEAPONOFFHAND = "Off Hand",
        INVTYPE_HOLDABLE = "Off Hand",
        INVTYPE_RANGED = "Ranged",
        INVTYPE_RANGEDRIGHT = "Ranged",
    }
    return slotNames[equipSlot] or ""
end

