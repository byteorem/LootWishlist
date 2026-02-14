-- LootWishlist Item Cache
-- LRU cache for async item data loading

local _, ns = ...

local C_Item = C_Item

---@class ItemCacheEntry
---@field itemID number
---@field name string
---@field link string Item link with color codes
---@field quality number 0=Poor, 1=Common, ..., 7=Heirloom
---@field iLevel number Item level
---@field equipSlot string Inventory type (e.g. "INVTYPE_HEAD")
---@field texture number Icon texture ID
---@field classID? number Item class ID
---@field subclassID? number Item subclass ID

---@type table<number, ItemCacheEntry>
ns.itemCache = {}
local MAX_CACHE_SIZE = 500

-- O(1) LRU tracking: doubly linked list + hash map
local lruNodes = {}  -- itemID -> {prev, next, itemID}
local lruHead = nil  -- Oldest (first to evict)
local lruTail = nil  -- Most recently used
local lruSize = 0

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

---Cache item info for async loading (with LRU eviction)
---@param itemID number
---@return ItemCacheEntry? info Cached info, or nil if not yet loaded
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
            texture = texture or ns.Constants.TEXTURE.QUESTION_MARK,
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

---Get cached item info
---@param itemID number
---@return ItemCacheEntry?
function ns:GetCachedItemInfo(itemID)
    if self.itemCache[itemID] then
        TouchCache(itemID)
        return self.itemCache[itemID]
    end
    return self:CacheItemInfo(itemID)
end

---Get item quality color (uses ColorManager API for accessibility/colorblind support)
---@param quality number Item quality (0-7)
---@return number[] rgb {r, g, b} color values
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

---Get slot name from inventory type
---@param equipSlot string
---@return string
function ns:GetSlotName(equipSlot)
    return ns.Constants.SLOT_NAMES[equipSlot] or ""
end
