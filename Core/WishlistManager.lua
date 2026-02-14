-- LootWishlist Wishlist Manager
-- Wishlist CRUD operations

local _, ns = ...

local pairs, ipairs = pairs, ipairs

-- Constants for validation
local MAX_WISHLIST_NAME_LENGTH = 50

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

---Create a new wishlist
---@param name string Wishlist name
---@return boolean success
---@return string? error Error message on failure
function ns:CreateWishlist(name)
    local success, result = ValidateWishlistName(name, self.db.wishlists)
    if not success then
        return false, result
    end

    local cleanName = result
    self.db.wishlists[cleanName] = { items = {} }
    return true
end

---Delete a wishlist
---@param name string
---@return boolean success
---@return string? error
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
            ns.WishlistIndex_Remove(entry.itemID, name)
        end
    end

    self.db.wishlists[name] = nil

    -- Switch to Default if active wishlist was deleted
    if self:GetActiveWishlistName() == name then
        self:SetCharSetting("activeWishlist", "Default")
    end

    return true
end

---Rename a wishlist
---@param oldName string
---@param newName string
---@return boolean success
---@return string? error
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
            ns.WishlistIndex_Remove(entry.itemID, oldName)
            ns.WishlistIndex_Add(entry.itemID, newName)
        end
    end

    -- Update active wishlist if it was renamed
    if self:GetActiveWishlistName() == oldName then
        self:SetCharSetting("activeWishlist", newName)
    end

    return true
end

---Set active wishlist
---@param name string
---@return boolean success
---@return string? error
function ns:SetActiveWishlist(name)
    if not self.db.wishlists[name] then
        return false, "Wishlist does not exist"
    end

    self:SetCharSetting("activeWishlist", name)
    return true
end

---Add item to a wishlist
---@param itemID number
---@param wishlistName? string Defaults to active wishlist
---@param sourceText? string Source description (e.g. "Boss, Instance")
---@param itemLink? string Item link string
---@return boolean success
---@return string? error Error message on failure
function ns:AddItemToWishlist(itemID, wishlistName, sourceText, itemLink)
    wishlistName = wishlistName or self:GetActiveWishlistName()
    local wishlist = self.db.wishlists[wishlistName]

    if not wishlist then
        return false, "Wishlist does not exist"
    end

    -- Check if already in wishlist (same itemID and sourceText)
    for _, entry in ipairs(wishlist.items) do
        if entry.itemID == itemID and entry.sourceText == (sourceText or "") then
            return false, "Item already in wishlist"
        end
    end

    table.insert(wishlist.items, {
        itemID = itemID,
        sourceText = sourceText or "",
        itemLink = itemLink,
    })

    -- Update index
    ns.WishlistIndex_Add(itemID, wishlistName)

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

---Remove item from wishlist
---@param itemID number
---@param sourceText? string
---@param wishlistName? string
---@return boolean success
---@return string? error
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
                ns.WishlistIndex_Remove(itemID, wishlistName)
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

---Get items in a wishlist
---@param wishlistName? string
---@return WishlistItem[]
function ns:GetWishlistItems(wishlistName)
    wishlistName = wishlistName or self:GetActiveWishlistName()
    local wishlist = self.db.wishlists[wishlistName]

    if not wishlist then
        return {}
    end

    return wishlist.items
end

---Calculate wishlist progress
---@param wishlistName? string
---@return number collected
---@return number total
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
