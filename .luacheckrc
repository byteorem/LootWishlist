std = "lua51"
max_line_length = false

exclude_files = {
    "Libs/**",
}

ignore = {
    "211",  -- Unused local variable
    "212",  -- Unused argument (common in event handlers)
    "213",  -- Unused loop variable
    "431",  -- Shadowing upvalue (common in WoW UI callbacks)
    "432",  -- Shadowing upvalue argument (self in nested handlers)
}

-- Addon globals (writeable)
globals = {
    -- SavedVariables
    "LootWishlistDB",
    "LootWishlistCharDB",

    -- Addon namespace
    "LootWishlist",

    -- Slash commands
    "SlashCmdList",
    "SLASH_LOOTWISHLIST1",
    "SLASH_LOOTWISHLIST2",

    -- Static popup dialogs
    "StaticPopupDialogs",

    -- UI Frames (need write access for state sync)
    "EncounterJournal",
}

read_globals = {
    -- Libraries
    "LibStub",

    -- C_* Namespaces
    "C_Item",
    "C_Timer",
    "C_EncounterJournal",
    "C_ChallengeMode",
    "C_EncodingUtil",

    -- Encounter Journal
    "EJ_SelectTier", "EJ_SetLootFilter", "EJ_ResetLootFilter",
    "EJ_SetDifficulty", "EJ_GetDifficulty", "EJ_GetInstanceByIndex", "EJ_SelectInstance",
    "EJ_GetEncounterInfoByIndex", "EJ_SelectEncounter", "EJ_GetNumLoot",
    "EJ_GetNumTiers", "EJ_GetTierInfo", "EJ_GetCurrentTier",
    "EJ_GetCurrentInstance", "EJ_GetInstanceInfo",

    -- Enums
    "Enum",

    -- Frame Creation
    "CreateFrame", "CreateFramePool", "CreateColor",
    "CreateDataProvider", "CreateScrollBoxListLinearView",

    -- Item Loading (async)
    "Item", "ContinuableContainer",

    -- UI Parents/Objects
    "UIParent", "GameTooltip", "LootFrame",

    -- Dropdown Functions
    "UIDropDownMenu_Initialize", "UIDropDownMenu_CreateInfo",
    "UIDropDownMenu_AddButton", "UIDropDownMenu_SetText",
    "UIDropDownMenu_SetWidth", "ToggleDropDownMenu",

    -- Loot Functions
    "GetNumLootItems", "GetLootSlotType", "GetLootSlotInfo", "GetLootSlotLink",

    -- Utility Functions
    "GetTime", "UnitClass", "PlaySound", "ReloadUI",
    "StaticPopup_Show", "CopyTable",

    -- Glow Effects
    "ActionButton_ShowOverlayGlow", "ActionButton_HideOverlayGlow",

    -- Settings API (11.0+)
    "Settings", "ScrollUtil",

    -- Event Registry
    "EventRegistry",

    -- Modern Menu Utilities (11.0+)
    "MenuUtil",

    -- Color Manager (11.1.5+)
    "ColorManager",

    -- Fonts
    "GameFontNormal", "GameFontNormalSmall", "GameFontNormalLarge",
    "GameFontHighlight", "GameFontHighlightSmall",

    -- Lua Extensions (WoW)
    "wipe", "strsplit",

    -- 12.0+ compatibility
    "issecurevariable",
}
