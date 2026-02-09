-- WoW Enum definitions for CLI testing
-- Subset of enums needed for ItemBrowser tests
-- Values match actual WoW API: https://warcraft.wiki.gg/wiki/Enum.ItemSlotFilterType

Enum = {
    ItemSlotFilterType = {
        Head = 0,
        Neck = 1,
        Shoulder = 2,
        Back = 3,       -- "Cloak" in API docs
        Chest = 4,
        Wrist = 5,
        Hands = 6,      -- "Hand" in API docs
        Waist = 7,
        Legs = 8,
        Feet = 9,
        MainHand = 10,
        OffHand = 11,
        Finger = 12,
        Trinket = 13,
        Other = 14,
        NoFilter = 15,
    },
}
