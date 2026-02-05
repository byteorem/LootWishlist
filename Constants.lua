-- LootWishlist Constants
-- Extracted constants and shared mappings

local addonName, ns = ...

ns.Constants = {
    -------------------------------------------------------------------------------
    -- Timing
    -------------------------------------------------------------------------------
    CLEANUP_INTERVAL_SECONDS = 60,
    GLOW_PULSE_INTERVAL = 0.5,
    ASYNC_LOAD_TIMEOUT = 2.0,
    ITEM_REFRESH_BATCH_DELAY = 0.1,

    -------------------------------------------------------------------------------
    -- Sound IDs
    -------------------------------------------------------------------------------
    SOUND = {
        RAID_WARNING = 8959,
    },

    -------------------------------------------------------------------------------
    -- Textures
    -------------------------------------------------------------------------------
    TEXTURE = {
        QUESTION_MARK = 134400,
    },

    -------------------------------------------------------------------------------
    -- UI Defaults
    -------------------------------------------------------------------------------
    MAX_NGRAM_PREFIX_LENGTH = 20,

    -------------------------------------------------------------------------------
    -- Difficulty IDs (preferred order for defaults)
    -------------------------------------------------------------------------------
    PREFERRED_DIFFICULTY_IDS = {1, 14, 2, 15}, -- Normal dungeon, Normal raid, Heroic dungeon, Heroic raid

    -------------------------------------------------------------------------------
    -- Slot Mappings (unified source of truth)
    -------------------------------------------------------------------------------
    SLOT_NAMES = {
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
        INVTYPE_FINGER = "Ring",
        INVTYPE_TRINKET = "Trinket",
        INVTYPE_WEAPON = "One-Hand",
        INVTYPE_SHIELD = "Off Hand",
        INVTYPE_2HWEAPON = "Two-Hand",
        INVTYPE_WEAPONMAINHAND = "Main Hand",
        INVTYPE_WEAPONOFFHAND = "Off Hand",
        INVTYPE_HOLDABLE = "Held In Off-hand",
        INVTYPE_RANGED = "Ranged",
        INVTYPE_RANGEDRIGHT = "Ranged",
    },

    -- Dropdown options for slot filter (unique entries, no duplicates)
    SLOT_DROPDOWN_OPTIONS = {
        {id = "ALL", name = "All Slots"},
        {id = "INVTYPE_HEAD", name = "Head"},
        {id = "INVTYPE_NECK", name = "Neck"},
        {id = "INVTYPE_SHOULDER", name = "Shoulder"},
        {id = "INVTYPE_CLOAK", name = "Back"},
        {id = "INVTYPE_CHEST", name = "Chest"},
        {id = "INVTYPE_WRIST", name = "Wrist"},
        {id = "INVTYPE_HAND", name = "Hands"},
        {id = "INVTYPE_WAIST", name = "Waist"},
        {id = "INVTYPE_LEGS", name = "Legs"},
        {id = "INVTYPE_FEET", name = "Feet"},
        {id = "INVTYPE_FINGER", name = "Ring"},
        {id = "INVTYPE_TRINKET", name = "Trinket"},
        {id = "WEAPON", name = "Weapons"},
    },

    -- Legacy slot data for PassesSlotFilterLegacy (includes ROBE for Chest matching)
    SLOT_DATA = {
        {id = "ALL", name = "All Slots"},
        {id = "INVTYPE_HEAD", name = "Head"},
        {id = "INVTYPE_NECK", name = "Neck"},
        {id = "INVTYPE_SHOULDER", name = "Shoulder"},
        {id = "INVTYPE_CLOAK", name = "Back"},
        {id = "INVTYPE_CHEST", name = "Chest"},
        {id = "INVTYPE_ROBE", name = "Chest"},
        {id = "INVTYPE_WRIST", name = "Wrist"},
        {id = "INVTYPE_HAND", name = "Hands"},
        {id = "INVTYPE_WAIST", name = "Waist"},
        {id = "INVTYPE_LEGS", name = "Legs"},
        {id = "INVTYPE_FEET", name = "Feet"},
        {id = "INVTYPE_FINGER", name = "Ring"},
        {id = "INVTYPE_TRINKET", name = "Trinket"},
        {id = "WEAPON", name = "Weapons"},
    },
}
