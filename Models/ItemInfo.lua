-- LootWishlist ItemInfo Model
-- Wraps item cache data with convenience methods

local _, ns = ...

---@class ItemInfo
---@field itemID number
---@field name string
---@field link string
---@field quality number
---@field iLevel number
---@field equipSlot string
---@field texture number
---@field classID? number
---@field subclassID? number
local ItemInfo = {}
ItemInfo.__index = ItemInfo

-- Quality constants
ItemInfo.QUALITY_POOR = 0
ItemInfo.QUALITY_COMMON = 1
ItemInfo.QUALITY_UNCOMMON = 2
ItemInfo.QUALITY_RARE = 3
ItemInfo.QUALITY_EPIC = 4
ItemInfo.QUALITY_LEGENDARY = 5
ItemInfo.QUALITY_ARTIFACT = 6
ItemInfo.QUALITY_HEIRLOOM = 7

---Create an ItemInfo from raw cache data
---@param data table Raw item cache entry
---@return ItemInfo
function ItemInfo.FromCache(data)
    return setmetatable(data, ItemInfo)
end

---Check if this item is equippable gear
---@return boolean
function ItemInfo:IsEquipment()
    local slot = self.equipSlot
    return slot ~= nil and slot ~= "" and slot ~= "INVTYPE_NON_EQUIP"
end

---Get the display name for this item's equipment slot
---@return string
function ItemInfo:GetSlotName()
    return ns.Constants.SLOT_NAMES[self.equipSlot] or ""
end

---Get the quality color as {r, g, b}
---@return number[] rgb
function ItemInfo:GetQualityColor()
    return ns:GetItemQualityColor(self.quality)
end

ns.ItemInfo = ItemInfo
