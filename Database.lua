-- LootWishlist Database
-- SavedVariables management

local addonName, ns = ...

-- Cache global functions
local pairs, ipairs, type = pairs, ipairs, type
local tinsert, wipe = table.insert, wipe

-- Database version for migrations
local DB_VERSION = 6

-- Default database structure
-- Note: Constants.lua must be loaded before Database.lua
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
        alertSound = 8959, -- ns.Constants.SOUND.RAID_WARNING (hardcoded here since DEFAULTS is evaluated at load time)
        browserSize = 1, -- ns.Constants.BROWSER_SIZE_NORMAL
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
    activeWishlist = "Default",
}

-- Deep merge: copy missing keys from source to target
-- Type-safe: validates types before merging to prevent corrupted data propagation
local function DeepMerge(target, source)
    -- Validate inputs
    if type(target) ~= "table" or type(source) ~= "table" then
        return target
    end

    for key, value in pairs(source) do
        if type(value) == "table" then
            -- Only merge if target is also a table (or nil)
            if target[key] == nil then
                target[key] = {}
            end
            if type(target[key]) == "table" then
                DeepMerge(target[key], value)
            end
            -- If target[key] is not a table, preserve user's data (type mismatch)
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

    -- Rebuild wishlist lookup index for O(1) item checks
    if self.RebuildWishlistIndex then
        self:RebuildWishlistIndex()
    end
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

    -- Version 2 -> 3 migration: Add difficulty field to existing items
    if db.version < 3 then
        for name, wishlist in pairs(db.wishlists) do
            for _, entry in ipairs(wishlist.items) do
                entry.difficulty = entry.difficulty or "any"
            end
        end
        db.version = 3
    end

    -- Version 3 -> 4 migration: Convert difficulty to upgradeTrack
    if db.version < 4 then
        local legacyCount = 0
        for name, wishlist in pairs(db.wishlists) do
            for _, entry in ipairs(wishlist.items) do
                entry.difficulty = nil      -- Remove old field
                entry.upgradeTrack = nil    -- Set nil = no alerts until re-added
                legacyCount = legacyCount + 1
            end
        end
        db.version = 4

        -- Store count for one-time notification
        if legacyCount > 0 then
            db.pendingLegacyNotification = legacyCount
        end

        -- Remove old settings
        if db.settings then
            db.settings.defaultRaidDifficulty = nil
            db.settings.defaultDungeonDifficulty = nil
        end
    end

    -- Version 4 -> 5 migration: Move activeWishlist to per-character
    if db.version < 5 then
        if db.settings and db.settings.activeWishlist then
            LootWishlistCharDB.activeWishlist = db.settings.activeWishlist
            db.settings.activeWishlist = nil
        end
    end

    -- Version 5 -> 6 migration: Remove track feature
    if db.version < 6 then
        -- Remove upgradeTrack from all wishlist items
        for _, wishlist in pairs(db.wishlists) do
            for _, entry in ipairs(wishlist.items) do
                entry.upgradeTrack = nil
            end
        end
        -- Remove defaultTrack setting
        if db.settings then
            db.settings.defaultTrack = nil
        end
        -- Clear legacy notification (no longer relevant)
        db.pendingLegacyNotification = nil
    end

    db.version = DB_VERSION
end

-- Get active wishlist name
function ns:GetActiveWishlistName()
    if not self.charDB then return "Default" end
    return self.charDB.activeWishlist or "Default"
end

-- Get active wishlist data
function ns:GetActiveWishlist()
    if not self.db then return nil end
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
    if not self.db or not self.db.settings then return nil end
    return self.db.settings[key]
end

-- Set setting
function ns:SetSetting(key, value)
    if not self.db or not self.db.settings then return end
    self.db.settings[key] = value
end

-- Set character-specific setting
function ns:SetCharSetting(key, value)
    if not self.charDB then return end
    self.charDB[key] = value
end

-- Check if item is collected on this character
function ns:IsItemCollected(itemID)
    if not self.charDB or not self.charDB.collected then return false end
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
function ns:IsItemChecked(itemID, sourceText)
    local key = itemID .. "_" .. (sourceText or "")
    return self.charDB.checkedItems[key] == true
end

-- Toggle item checked state
function ns:ToggleItemChecked(itemID, sourceText)
    local key = itemID .. "_" .. (sourceText or "")
    if self.charDB.checkedItems[key] then
        self.charDB.checkedItems[key] = nil
    else
        self.charDB.checkedItems[key] = true
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
        local key = entry.itemID .. "_" .. (entry.sourceText or "")
        if not checkedItems[key] then
            table.insert(newItems, entry)
        end
    end
    wishlist.items = newItems

    -- Clear checked items
    wipe(self.charDB.checkedItems)
end
