-- LootWishlist WishlistEntry Model
-- Lightweight metatable-based model for wishlist items

local _, ns = ...

---@class WishlistEntry
---@field itemID number
---@field sourceText string
---@field itemLink? string
local WishlistEntry = {}
WishlistEntry.__index = WishlistEntry

---Create a new WishlistEntry
---@param itemID number
---@param sourceText? string
---@param itemLink? string
---@return WishlistEntry
function WishlistEntry.Create(itemID, sourceText, itemLink)
    return setmetatable({
        itemID = itemID,
        sourceText = sourceText or "",
        itemLink = itemLink,
    }, WishlistEntry)
end

---Create from an existing raw table (e.g. loaded from SavedVariables)
---@param raw table {itemID, sourceText, itemLink?}
---@return WishlistEntry?
function WishlistEntry.FromRaw(raw)
    if not raw or not raw.itemID then return nil end
    return setmetatable(raw, WishlistEntry)
end

---Get cached item info from the addon's item cache
---@return ItemCacheEntry?
function WishlistEntry:GetInfo()
    return ns:GetCachedItemInfo(self.itemID)
end

---Get a unique key for this entry (itemID + source)
---@return string
function WishlistEntry:GetKey()
    return self.itemID .. "_" .. self.sourceText
end

---Check if this entry matches another by itemID and sourceText
---@param other WishlistEntry|table
---@return boolean
function WishlistEntry:Matches(other)
    return self.itemID == other.itemID
        and self.sourceText == (other.sourceText or "")
end

---Serialize to a plain table (for SavedVariables)
---@return table
function WishlistEntry:Serialize()
    return {
        itemID = self.itemID,
        sourceText = self.sourceText,
        itemLink = self.itemLink,
    }
end

ns.WishlistEntry = WishlistEntry
