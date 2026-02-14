-- LootWishlist Wishlist Index
-- O(1) lookup index for checking if items are on wishlists

local _, ns = ...

local pairs, ipairs = pairs, ipairs
local wipe = wipe

-- Wishlist lookup index for O(1) item checks
-- Structure: wishlistIndex[itemID] = {wishlistName1 = true, wishlistName2 = true, ...}
local wishlistIndex = {}

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

---@param itemID number
---@param wishlistName string
function ns.WishlistIndex_Add(itemID, wishlistName)
    if not itemID or not wishlistName then return end
    if not wishlistIndex[itemID] then
        wishlistIndex[itemID] = {}
    end
    wishlistIndex[itemID][wishlistName] = true
end

---@param itemID number
---@param wishlistName string
function ns.WishlistIndex_Remove(itemID, wishlistName)
    if not itemID or not wishlistName then return end
    if wishlistIndex[itemID] then
        wishlistIndex[itemID][wishlistName] = nil
        if not next(wishlistIndex[itemID]) then
            wishlistIndex[itemID] = nil
        end
    end
end

---Check if item is on any wishlist (O(1) lookup using index)
---@param itemID number
---@param wishlistName? string Check specific wishlist only
---@return boolean isOnWishlist
---@return string? wishlistName First wishlist containing the item
function ns:IsItemOnWishlist(itemID, wishlistName)
    local itemWishlists = wishlistIndex[itemID]
    if not itemWishlists then
        return false
    end

    if wishlistName then
        return itemWishlists[wishlistName] == true
    end

    for name in pairs(itemWishlists) do
        return true, name
    end

    return false
end

---Check if item with specific source is on wishlist
---@param itemID number
---@param sourceText? string
---@param wishlistName? string
---@return boolean
function ns:IsItemOnWishlistWithSource(itemID, sourceText, wishlistName)
    wishlistName = wishlistName or self:GetActiveWishlistName()
    local wishlist = self.db.wishlists[wishlistName]

    if not wishlist then
        return false
    end

    for _, entry in ipairs(wishlist.items) do
        if entry.itemID == itemID and entry.sourceText == (sourceText or "") then
            return true
        end
    end

    return false
end

-- Export RebuildIndex for use after database initialization
ns.RebuildWishlistIndex = RebuildIndex
