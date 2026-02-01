-- LootWishlist Database
-- SavedVariables management

local addonName, ns = ...

-- Cache global functions
local pairs, ipairs, type = pairs, ipairs, type
local tinsert, wipe = table.insert, wipe

-- Database version for migrations
local DB_VERSION = 2

-- Default database structure
local DEFAULTS = {
    version = DB_VERSION,
    wishlists = {
        ["Default"] = {
            items = {},
        },
    },
    settings = {
        soundEnabled = true,
        glowEnabled = true,
        chatAlertEnabled = true,
        activeWishlist = "Default",
        alertSound = 8959, -- SOUNDKIT.RAID_WARNING
        browserSize = 1, -- 1 = Normal, 2 = Large
        collapsedGroups = {},  -- Persist collapse state
        minimapIcon = {
            hide = false,
            minimapPos = 220,
            lock = false,
        },
    },
}

local CHAR_DEFAULTS = {
    collected = {},
    checkedItems = {},
}

-- Deep merge: copy missing keys from source to target
local function DeepMerge(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            DeepMerge(target[key], value)
        else
            if target[key] == nil then
                target[key] = value
            end
        end
    end
    return target
end

-- Initialize database
function ns:InitializeDatabase()
    -- Initialize account-wide DB
    LootWishlistDB = LootWishlistDB or {}
    DeepMerge(LootWishlistDB, DEFAULTS)

    -- Initialize character-specific DB
    LootWishlistCharDB = LootWishlistCharDB or {}
    DeepMerge(LootWishlistCharDB, CHAR_DEFAULTS)

    -- Run migrations if needed
    self:MigrateDatabase()

    -- Store references
    self.db = LootWishlistDB
    self.charDB = LootWishlistCharDB
end

-- Database migrations
function ns:MigrateDatabase()
    local db = LootWishlistDB

    -- Version 1 -> 2 migration: Convert items from [itemID, ...] to [{itemID, sourceText}, ...]
    if db.version < 2 then
        for name, wishlist in pairs(db.wishlists) do
            local newItems = {}
            for _, entry in ipairs(wishlist.items) do
                if type(entry) == "number" then
                    -- Old format: just an itemID number
                    table.insert(newItems, {itemID = entry, sourceText = ""})
                elseif type(entry) == "table" and entry.itemID then
                    -- Already new format
                    table.insert(newItems, entry)
                end
            end
            wishlist.items = newItems
        end
        db.version = 2
    end

    db.version = DB_VERSION
end

-- Get active wishlist name
function ns:GetActiveWishlistName()
    return self.db.settings.activeWishlist or "Default"
end

-- Get active wishlist data
function ns:GetActiveWishlist()
    local name = self:GetActiveWishlistName()
    return self.db.wishlists[name]
end

-- Get all wishlist names
function ns:GetWishlistNames()
    local names = {}
    for name in pairs(self.db.wishlists) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

-- Get setting
function ns:GetSetting(key)
    return self.db.settings[key]
end

-- Set setting
function ns:SetSetting(key, value)
    self.db.settings[key] = value
end

-- Check if item is collected on this character
function ns:IsItemCollected(itemID)
    return self.charDB.collected[itemID] == true
end

-- Mark item as collected
function ns:MarkItemCollected(itemID)
    self.charDB.collected[itemID] = true
end

-- Unmark item as collected
function ns:UnmarkItemCollected(itemID)
    self.charDB.collected[itemID] = nil
end

-- Get all collected items
function ns:GetCollectedItems()
    return self.charDB.collected
end

-- Check if item is checked off
function ns:IsItemChecked(itemID)
    return self.charDB.checkedItems[itemID] == true
end

-- Toggle item checked state
function ns:ToggleItemChecked(itemID)
    if self.charDB.checkedItems[itemID] then
        self.charDB.checkedItems[itemID] = nil
    else
        self.charDB.checkedItems[itemID] = true
    end
end

-- Remove all checked items from active wishlist
function ns:RemoveCheckedItems()
    local checkedItems = self.charDB.checkedItems
    if not checkedItems or not next(checkedItems) then
        return
    end

    local wishlist = self:GetActiveWishlist()
    if not wishlist or not wishlist.items then
        return
    end

    -- Remove checked items from wishlist
    local newItems = {}
    for _, entry in ipairs(wishlist.items) do
        if not checkedItems[entry.itemID] then
            table.insert(newItems, entry)
        end
    end
    wishlist.items = newItems

    -- Clear checked items
    wipe(self.charDB.checkedItems)
end
