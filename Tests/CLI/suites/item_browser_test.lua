-- CLI Unit Tests for Item Browser
-- Mirrors the WoWUnit tests in Tests/ItemBrowserTests.lua
-- Run with: lua5.1 Tests/CLI/run.lua

local Tests = {}
local FilterType = Enum.ItemSlotFilterType

-------------------------------------------------------------------------------
-- PassesSearchFilter Tests (addresses past false positive issue)
-------------------------------------------------------------------------------

function Tests.PassesSearchFilter_ExactMatch()
    local searchIndex = {}
    searchIndex["test"] = { ["123|456"] = true }

    local result = ns.BrowserFilter:PassesSearchFilter(123, 456, "test", searchIndex)
    assert(result == true, "Expected true for exact match")
end

function Tests.PassesSearchFilter_NoMatch()
    local searchIndex = {}
    searchIndex["test"] = { ["123|456"] = true }

    local result = ns.BrowserFilter:PassesSearchFilter(999, 999, "test", searchIndex)
    assert(result == false, "Expected false for no match")
end

function Tests.PassesSearchFilter_EmptySearch()
    local result = ns.BrowserFilter:PassesSearchFilter(123, 456, "", {})
    assert(result == true, "Empty search should pass")
end

function Tests.PassesSearchFilter_NilSearch()
    local result = ns.BrowserFilter:PassesSearchFilter(123, 456, nil, {})
    assert(result == true, "Nil search should pass")
end

function Tests.PassesSearchFilter_CaseInsensitive()
    local searchIndex = {}
    searchIndex["test"] = { ["123|456"] = true }

    local result = ns.BrowserFilter:PassesSearchFilter(123, 456, "TEST", searchIndex)
    assert(result == true, "Search should be case insensitive")
end

function Tests.PassesSearchFilter_PartialMatch()
    local searchIndex = {}
    searchIndex["tes"] = { ["123|456"] = true }
    searchIndex["test"] = { ["123|456"] = true }

    local result = ns.BrowserFilter:PassesSearchFilter(123, 456, "tes", searchIndex)
    assert(result == true, "Partial match should pass")
end

function Tests.PassesSearchFilter_NoIndexEntryForSearch()
    local searchIndex = {}
    searchIndex["foo"] = { ["123|456"] = true }

    local result = ns.BrowserFilter:PassesSearchFilter(123, 456, "bar", searchIndex)
    assert(result == false, "No index entry should fail")
end

-------------------------------------------------------------------------------
-- PassesSearchFilterLegacy Tests (substring matching bugs)
-- Note: These functions return truthy values (position numbers from find())
-- rather than booleans, so we check truthiness not exact boolean values.
-------------------------------------------------------------------------------

function Tests.PassesSearchFilterLegacy_ExactMatch()
    local result = ns.BrowserFilter:PassesSearchFilterLegacy("Test Item", "Boss Name", "Test Item")
    assert(result, "Exact match should pass")
end

function Tests.PassesSearchFilterLegacy_PartialMatch()
    local result = ns.BrowserFilter:PassesSearchFilterLegacy("Test Item", "Boss Name", "Test")
    assert(result, "Partial match should pass")
end

function Tests.PassesSearchFilterLegacy_CaseInsensitive()
    local result = ns.BrowserFilter:PassesSearchFilterLegacy("Test Item", "Boss Name", "test")
    assert(result, "Case insensitive match should pass")
end

function Tests.PassesSearchFilterLegacy_MatchBossName()
    local result = ns.BrowserFilter:PassesSearchFilterLegacy("Test Item", "Boss Name", "Boss")
    assert(result, "Boss name match should pass")
end

function Tests.PassesSearchFilterLegacy_NoMatch()
    local result = ns.BrowserFilter:PassesSearchFilterLegacy("Test Item", "Boss Name", "xyz")
    assert(not result, "No match should fail")
end

function Tests.PassesSearchFilterLegacy_EmptySearch()
    local result = ns.BrowserFilter:PassesSearchFilterLegacy("Test Item", "Boss Name", "")
    assert(result, "Empty search should pass")
end

function Tests.PassesSearchFilterLegacy_NilSearch()
    local result = ns.BrowserFilter:PassesSearchFilterLegacy("Test Item", "Boss Name", nil)
    assert(result, "Nil search should pass")
end

function Tests.PassesSearchFilterLegacy_NilItemName()
    local result = ns.BrowserFilter:PassesSearchFilterLegacy(nil, "Boss Name", "Boss")
    assert(result, "Nil item name with boss match should pass")
end

function Tests.PassesSearchFilterLegacy_NilBothNames()
    local result = ns.BrowserFilter:PassesSearchFilterLegacy(nil, nil, "test")
    assert(not result, "Nil both names should fail")
end

-------------------------------------------------------------------------------
-- PassesSlotFilter Tests (enum-based)
-------------------------------------------------------------------------------

function Tests.PassesSlotFilter_AllFilter()
    local result = ns.BrowserFilter:PassesSlotFilter(FilterType.Head, "ALL")
    assert(result == true, "ALL filter should pass any slot")
end

function Tests.PassesSlotFilter_ExactMatch()
    local result = ns.BrowserFilter:PassesSlotFilter(FilterType.Head, "INVTYPE_HEAD")
    assert(result == true, "Exact match should pass")
end

function Tests.PassesSlotFilter_NoMatch()
    local result = ns.BrowserFilter:PassesSlotFilter(FilterType.Head, "INVTYPE_CHEST")
    assert(result == false, "Different slot should fail")
end

function Tests.PassesSlotFilter_WeaponMainHand()
    local result = ns.BrowserFilter:PassesSlotFilter(FilterType.MainHand, "WEAPON")
    assert(result == true, "MainHand should pass WEAPON filter")
end

function Tests.PassesSlotFilter_WeaponOffHand()
    local result = ns.BrowserFilter:PassesSlotFilter(FilterType.OffHand, "WEAPON")
    assert(result == true, "OffHand should pass WEAPON filter")
end

function Tests.PassesSlotFilter_NonWeaponForWeaponFilter()
    local result = ns.BrowserFilter:PassesSlotFilter(FilterType.Head, "WEAPON")
    assert(result == false, "Head should fail WEAPON filter")
end

function Tests.PassesSlotFilter_UnknownFilter()
    local result = ns.BrowserFilter:PassesSlotFilter(FilterType.Head, "UNKNOWN_FILTER")
    assert(result == true, "Unknown filter should allow all")
end

function Tests.PassesSlotFilter_NilFilterType()
    local result = ns.BrowserFilter:PassesSlotFilter(nil, "INVTYPE_HEAD")
    assert(result == false, "Nil filterType should fail")
end

-------------------------------------------------------------------------------
-- PassesSlotFilterLegacy Tests (string-based fallback)
-- Note: These functions return truthy values (position numbers from find())
-- rather than booleans, so we check truthiness not exact boolean values.
-------------------------------------------------------------------------------

function Tests.PassesSlotFilterLegacy_AllFilter()
    local result = ns.BrowserFilter:PassesSlotFilterLegacy("Head", "ALL")
    assert(result, "ALL filter should pass")
end

function Tests.PassesSlotFilterLegacy_ExactMatch()
    local result = ns.BrowserFilter:PassesSlotFilterLegacy("Head", "INVTYPE_HEAD")
    assert(result, "Exact match should pass")
end

function Tests.PassesSlotFilterLegacy_WeaponOneHand()
    local result = ns.BrowserFilter:PassesSlotFilterLegacy("One-Hand Weapon", "WEAPON")
    assert(result, "One-Hand Weapon should pass WEAPON filter")
end

function Tests.PassesSlotFilterLegacy_WeaponShield()
    local result = ns.BrowserFilter:PassesSlotFilterLegacy("Shield", "WEAPON")
    assert(result, "Shield should pass WEAPON filter")
end

function Tests.PassesSlotFilterLegacy_WeaponOffHand()
    local result = ns.BrowserFilter:PassesSlotFilterLegacy("Off Hand", "WEAPON")
    assert(result, "Off Hand should pass WEAPON filter")
end

function Tests.PassesSlotFilterLegacy_WeaponHeldInOff()
    local result = ns.BrowserFilter:PassesSlotFilterLegacy("Held In Off-hand", "WEAPON")
    assert(result, "Held In Off-hand should pass WEAPON filter")
end

function Tests.PassesSlotFilterLegacy_NonWeaponForWeaponFilter()
    local result = ns.BrowserFilter:PassesSlotFilterLegacy("Head", "WEAPON")
    assert(not result, "Head should fail WEAPON filter")
end

-------------------------------------------------------------------------------
-- IsEquipment Tests (equipment filter)
-------------------------------------------------------------------------------

function Tests.IsEquipment_HeadSlot()
    local result = ns.BrowserFilter:IsEquipment(FilterType.Head, "")
    assert(result == true, "Head should be equipment")
end

function Tests.IsEquipment_NeckSlot()
    local result = ns.BrowserFilter:IsEquipment(FilterType.Neck, "")
    assert(result == true, "Neck should be equipment")
end

function Tests.IsEquipment_TrinketSlot()
    local result = ns.BrowserFilter:IsEquipment(FilterType.Trinket, "")
    assert(result == true, "Trinket should be equipment")
end

function Tests.IsEquipment_MainHandSlot()
    local result = ns.BrowserFilter:IsEquipment(FilterType.MainHand, "")
    assert(result == true, "MainHand should be equipment")
end

function Tests.IsEquipment_OtherType()
    local result = ns.BrowserFilter:IsEquipment(FilterType.Other, "")
    assert(result == false, "Other should not be equipment")
end

function Tests.IsEquipment_NilWithSlotString()
    local result = ns.BrowserFilter:IsEquipment(nil, "Head")
    assert(result == true, "Nil filterType with slot string should be equipment")
end

function Tests.IsEquipment_NilWithEmptySlot()
    local result = ns.BrowserFilter:IsEquipment(nil, "")
    assert(result == false, "Nil filterType with empty slot should not be equipment")
end

function Tests.IsEquipment_NilWithNilSlot()
    local result = ns.BrowserFilter:IsEquipment(nil, nil)
    assert(not result, "Nil filterType with nil slot should not be equipment")
end

-------------------------------------------------------------------------------
-- IsCacheValid Tests (addresses loadingState stuck issue)
-------------------------------------------------------------------------------

function Tests.IsCacheValid_NotReadyState()
    -- Save original state
    local originalState = ns.browserState.selectedInstance
    local originalCache = {
        loadingState = ns.BrowserCache.loadingState,
        instanceID = ns.BrowserCache.instanceID,
        classFilter = ns.BrowserCache.classFilter,
        difficultyID = ns.BrowserCache.difficultyID,
        expansion = ns.BrowserCache.expansion,
    }

    -- Setup test conditions
    ns.browserState.selectedInstance = 1234
    ns.BrowserCache.loadingState = "loading"
    ns.BrowserCache.instanceID = 1234
    ns.BrowserCache.classFilter = ns.browserState.classFilter
    ns.BrowserCache.difficultyID = ns.browserState.selectedDifficultyID
    ns.BrowserCache.expansion = ns.browserState.expansion

    local result = ns._test.IsCacheValid()
    assert(result == false, "Loading state should be invalid")

    -- Restore original state
    ns.browserState.selectedInstance = originalState
    ns.BrowserCache.loadingState = originalCache.loadingState
    ns.BrowserCache.instanceID = originalCache.instanceID
    ns.BrowserCache.classFilter = originalCache.classFilter
    ns.BrowserCache.difficultyID = originalCache.difficultyID
    ns.BrowserCache.expansion = originalCache.expansion
end

function Tests.IsCacheValid_InstanceMismatch()
    -- Save original state
    local originalState = ns.browserState.selectedInstance
    local originalCache = {
        loadingState = ns.BrowserCache.loadingState,
        instanceID = ns.BrowserCache.instanceID,
    }

    -- Setup test conditions
    ns.browserState.selectedInstance = 1234
    ns.BrowserCache.loadingState = "ready"
    ns.BrowserCache.instanceID = 5678  -- Different instance

    local result = ns._test.IsCacheValid()
    assert(result == false, "Instance mismatch should be invalid")

    -- Restore original state
    ns.browserState.selectedInstance = originalState
    ns.BrowserCache.loadingState = originalCache.loadingState
    ns.BrowserCache.instanceID = originalCache.instanceID
end

function Tests.IsCacheValid_ValidCache()
    -- Save original state
    local originalBrowserState = {
        selectedInstance = ns.browserState.selectedInstance,
        classFilter = ns.browserState.classFilter,
        selectedDifficultyID = ns.browserState.selectedDifficultyID,
        expansion = ns.browserState.expansion,
    }
    local originalCache = {
        loadingState = ns.BrowserCache.loadingState,
        instanceID = ns.BrowserCache.instanceID,
        classFilter = ns.BrowserCache.classFilter,
        difficultyID = ns.BrowserCache.difficultyID,
        expansion = ns.BrowserCache.expansion,
    }

    -- Setup: cache matches state exactly
    ns.browserState.selectedInstance = 1234
    ns.browserState.classFilter = 1
    ns.browserState.selectedDifficultyID = 14
    ns.browserState.expansion = 10

    ns.BrowserCache.loadingState = "ready"
    ns.BrowserCache.instanceID = 1234
    ns.BrowserCache.classFilter = 1
    ns.BrowserCache.difficultyID = 14
    ns.BrowserCache.expansion = 10

    local result = ns._test.IsCacheValid()
    assert(result == true, "All matching fields should be valid")

    -- Restore original state
    ns.browserState.selectedInstance = originalBrowserState.selectedInstance
    ns.browserState.classFilter = originalBrowserState.classFilter
    ns.browserState.selectedDifficultyID = originalBrowserState.selectedDifficultyID
    ns.browserState.expansion = originalBrowserState.expansion
    ns.BrowserCache.loadingState = originalCache.loadingState
    ns.BrowserCache.instanceID = originalCache.instanceID
    ns.BrowserCache.classFilter = originalCache.classFilter
    ns.BrowserCache.difficultyID = originalCache.difficultyID
    ns.BrowserCache.expansion = originalCache.expansion
end

function Tests.IsCacheValid_ClassMismatch()
    -- Save original state
    local originalBrowserState = {
        selectedInstance = ns.browserState.selectedInstance,
        classFilter = ns.browserState.classFilter,
        selectedDifficultyID = ns.browserState.selectedDifficultyID,
        expansion = ns.browserState.expansion,
    }
    local originalCache = {
        loadingState = ns.BrowserCache.loadingState,
        instanceID = ns.BrowserCache.instanceID,
        classFilter = ns.BrowserCache.classFilter,
        difficultyID = ns.BrowserCache.difficultyID,
        expansion = ns.BrowserCache.expansion,
    }

    -- Setup: cache is for class 1, state wants class 2
    ns.browserState.selectedInstance = 1234
    ns.browserState.classFilter = 2
    ns.browserState.selectedDifficultyID = 14
    ns.browserState.expansion = 10

    ns.BrowserCache.loadingState = "ready"
    ns.BrowserCache.instanceID = 1234
    ns.BrowserCache.classFilter = 1  -- Different class
    ns.BrowserCache.difficultyID = 14
    ns.BrowserCache.expansion = 10

    local result = ns._test.IsCacheValid()
    assert(result == false, "Class mismatch should invalidate")

    -- Restore original state
    ns.browserState.selectedInstance = originalBrowserState.selectedInstance
    ns.browserState.classFilter = originalBrowserState.classFilter
    ns.browserState.selectedDifficultyID = originalBrowserState.selectedDifficultyID
    ns.browserState.expansion = originalBrowserState.expansion
    ns.BrowserCache.loadingState = originalCache.loadingState
    ns.BrowserCache.instanceID = originalCache.instanceID
    ns.BrowserCache.classFilter = originalCache.classFilter
    ns.BrowserCache.difficultyID = originalCache.difficultyID
    ns.BrowserCache.expansion = originalCache.expansion
end

function Tests.IsCacheValid_DifficultyMismatch()
    -- Save original state
    local originalBrowserState = {
        selectedInstance = ns.browserState.selectedInstance,
        classFilter = ns.browserState.classFilter,
        selectedDifficultyID = ns.browserState.selectedDifficultyID,
        expansion = ns.browserState.expansion,
    }
    local originalCache = {
        loadingState = ns.BrowserCache.loadingState,
        instanceID = ns.BrowserCache.instanceID,
        classFilter = ns.BrowserCache.classFilter,
        difficultyID = ns.BrowserCache.difficultyID,
        expansion = ns.BrowserCache.expansion,
    }

    -- Setup: cache has difficulty 14 (Normal), state wants 15 (Heroic)
    ns.browserState.selectedInstance = 1234
    ns.browserState.classFilter = 1
    ns.browserState.selectedDifficultyID = 15
    ns.browserState.expansion = 10

    ns.BrowserCache.loadingState = "ready"
    ns.BrowserCache.instanceID = 1234
    ns.BrowserCache.classFilter = 1
    ns.BrowserCache.difficultyID = 14  -- Different difficulty
    ns.BrowserCache.expansion = 10

    local result = ns._test.IsCacheValid()
    assert(result == false, "Difficulty mismatch should invalidate")

    -- Restore original state
    ns.browserState.selectedInstance = originalBrowserState.selectedInstance
    ns.browserState.classFilter = originalBrowserState.classFilter
    ns.browserState.selectedDifficultyID = originalBrowserState.selectedDifficultyID
    ns.browserState.expansion = originalBrowserState.expansion
    ns.BrowserCache.loadingState = originalCache.loadingState
    ns.BrowserCache.instanceID = originalCache.instanceID
    ns.BrowserCache.classFilter = originalCache.classFilter
    ns.BrowserCache.difficultyID = originalCache.difficultyID
    ns.BrowserCache.expansion = originalCache.expansion
end

function Tests.IsCacheValid_ExpansionMismatch()
    -- Save original state
    local originalBrowserState = {
        selectedInstance = ns.browserState.selectedInstance,
        classFilter = ns.browserState.classFilter,
        selectedDifficultyID = ns.browserState.selectedDifficultyID,
        expansion = ns.browserState.expansion,
    }
    local originalCache = {
        loadingState = ns.BrowserCache.loadingState,
        instanceID = ns.BrowserCache.instanceID,
        classFilter = ns.BrowserCache.classFilter,
        difficultyID = ns.BrowserCache.difficultyID,
        expansion = ns.BrowserCache.expansion,
    }

    -- Setup: cache has expansion 9, state wants 10
    ns.browserState.selectedInstance = 1234
    ns.browserState.classFilter = 1
    ns.browserState.selectedDifficultyID = 14
    ns.browserState.expansion = 10

    ns.BrowserCache.loadingState = "ready"
    ns.BrowserCache.instanceID = 1234
    ns.BrowserCache.classFilter = 1
    ns.BrowserCache.difficultyID = 14
    ns.BrowserCache.expansion = 9  -- Different expansion

    local result = ns._test.IsCacheValid()
    assert(result == false, "Expansion mismatch should invalidate")

    -- Restore original state
    ns.browserState.selectedInstance = originalBrowserState.selectedInstance
    ns.browserState.classFilter = originalBrowserState.classFilter
    ns.browserState.selectedDifficultyID = originalBrowserState.selectedDifficultyID
    ns.browserState.expansion = originalBrowserState.expansion
    ns.BrowserCache.loadingState = originalCache.loadingState
    ns.BrowserCache.instanceID = originalCache.instanceID
    ns.BrowserCache.classFilter = originalCache.classFilter
    ns.BrowserCache.difficultyID = originalCache.difficultyID
    ns.BrowserCache.expansion = originalCache.expansion
end

-------------------------------------------------------------------------------
-- InvalidateCache Tests
-------------------------------------------------------------------------------

function Tests.InvalidateCache_ResetsState()
    -- Save original state
    local originalCache = {
        version = ns.BrowserCache.version,
        loadingState = ns.BrowserCache.loadingState,
        instanceID = ns.BrowserCache.instanceID,
    }

    -- Setup test conditions
    ns.BrowserCache.loadingState = "ready"
    ns.BrowserCache.instanceID = 1234
    local versionBefore = ns.BrowserCache.version

    ns._test.InvalidateCache()

    assert(ns.BrowserCache.loadingState == "idle", "loadingState should be idle")
    assert(ns.BrowserCache.instanceID == nil, "instanceID should be nil")
    assert(ns.BrowserCache.version == versionBefore + 1, "version should increment")

    -- Restore original state
    ns.BrowserCache.version = originalCache.version
    ns.BrowserCache.loadingState = originalCache.loadingState
    ns.BrowserCache.instanceID = originalCache.instanceID
end

function Tests.InvalidateCache_VersionIncrementsEachCall()
    -- Save original state
    local originalVersion = ns.BrowserCache.version

    local v1 = ns.BrowserCache.version
    ns._test.InvalidateCache()
    local v2 = ns.BrowserCache.version
    ns._test.InvalidateCache()
    local v3 = ns.BrowserCache.version

    assert(v2 == v1 + 1, "First invalidate should increment")
    assert(v3 == v2 + 1, "Second invalidate should increment again")

    -- Restore original state
    ns.BrowserCache.version = originalVersion
end

function Tests.InvalidateCache_ClearsSearchIndex()
    -- Save original state
    local originalSearchIndex = ns.BrowserCache.searchIndex
    local originalVersion = ns.BrowserCache.version

    -- Setup test conditions
    ns.BrowserCache.searchIndex = {}
    ns.BrowserCache.searchIndex["test"] = { ["123|456"] = true }

    ns._test.InvalidateCache()

    assert(ns.BrowserCache.searchIndex["test"] == nil, "Search index should be cleared")

    -- Restore original state
    ns.BrowserCache.searchIndex = originalSearchIndex
    ns.BrowserCache.version = originalVersion
end

function Tests.InvalidateCache_ClearsBosses()
    -- Save original state
    local originalBosses = ns.BrowserCache.bosses
    local originalVersion = ns.BrowserCache.version

    -- Setup test conditions
    ns.BrowserCache.bosses = {}
    table.insert(ns.BrowserCache.bosses, { bossID = 1, name = "Test" })

    ns._test.InvalidateCache()

    assert(#ns.BrowserCache.bosses == 0, "Bosses should be cleared")

    -- Restore original state
    ns.BrowserCache.bosses = originalBosses
    ns.BrowserCache.version = originalVersion
end

-------------------------------------------------------------------------------
-- BuildSearchIndexEntry Tests
-------------------------------------------------------------------------------

function Tests.BuildSearchIndexEntry_SingleChar()
    local searchIndex = {}
    ns._test.BuildSearchIndexEntry(searchIndex, "123|456", "Test")

    assert(searchIndex["t"] ~= nil, "Should have 't' entry")
    assert(searchIndex["t"]["123|456"] == true, "Should map to item key")
end

function Tests.BuildSearchIndexEntry_MultipleChars()
    local searchIndex = {}
    ns._test.BuildSearchIndexEntry(searchIndex, "123|456", "Test")

    assert(searchIndex["t"] ~= nil, "Should have 't' entry")
    assert(searchIndex["te"] ~= nil, "Should have 'te' entry")
    assert(searchIndex["tes"] ~= nil, "Should have 'tes' entry")
    assert(searchIndex["test"] ~= nil, "Should have 'test' entry")
end

function Tests.BuildSearchIndexEntry_CaseInsensitive()
    local searchIndex = {}
    ns._test.BuildSearchIndexEntry(searchIndex, "123|456", "TEST")

    assert(searchIndex["t"] ~= nil, "Should have lowercase 't' entry")
    assert(searchIndex["test"] ~= nil, "Should have lowercase 'test' entry")
end

function Tests.BuildSearchIndexEntry_MultipleItems()
    local searchIndex = {}
    ns._test.BuildSearchIndexEntry(searchIndex, "111|222", "Test")
    ns._test.BuildSearchIndexEntry(searchIndex, "333|444", "Testing")

    assert(searchIndex["test"]["111|222"] == true, "First item should be in test")
    assert(searchIndex["test"]["333|444"] == true, "Second item should be in test")
end

function Tests.BuildSearchIndexEntry_MaxLength()
    local searchIndex = {}
    local longName = "ThisIsAVeryLongItemNameThatExceedsLimit"
    ns._test.BuildSearchIndexEntry(searchIndex, "123|456", longName)

    -- Should only index up to MAX_NGRAM_PREFIX_LENGTH (20)
    local maxLen = ns.Constants.MAX_NGRAM_PREFIX_LENGTH
    local expectedPrefix = longName:lower():sub(1, maxLen)
    assert(searchIndex[expectedPrefix] ~= nil, "Should have max length prefix")

    -- Should NOT have longer prefix
    local longerPrefix = longName:lower():sub(1, maxLen + 1)
    assert(searchIndex[longerPrefix] == nil, "Should not have prefix beyond max")
end

-------------------------------------------------------------------------------
-- GetFilteredData Tests
-------------------------------------------------------------------------------

function Tests.GetFilteredData_EmptyCache()
    -- Save original state
    local originalBosses = ns.BrowserCache.bosses

    -- Setup test conditions
    ns.BrowserCache.bosses = {}

    local result = ns.BrowserFilter:GetFilteredData()

    assert(#result == 0, "Empty cache should return empty result")

    -- Restore original state
    ns.BrowserCache.bosses = originalBosses
end

function Tests.GetFilteredData_AllPassFilters()
    -- Save original state
    local originalBosses = ns.BrowserCache.bosses
    local originalSearchIndex = ns.BrowserCache.searchIndex
    local originalSlotFilter = ns.browserState.slotFilter
    local originalSearchText = ns.browserState.searchText
    local originalEquipmentOnly = ns.browserState.equipmentOnlyFilter

    -- Setup test conditions
    ns.browserState.slotFilter = "ALL"
    ns.browserState.searchText = ""
    ns.browserState.equipmentOnlyFilter = false
    ns.BrowserCache.searchIndex = {}
    ns.BrowserCache.bosses = {
        {
            bossID = 1,
            name = "Test Boss",
            loot = {
                {itemID = 100, name = "Item A", filterType = FilterType.Head, slot = "Head"},
                {itemID = 101, name = "Item B", filterType = FilterType.Chest, slot = "Chest"},
            }
        }
    }

    local result = ns.BrowserFilter:GetFilteredData()

    assert(#result == 1, "Should have 1 boss")
    assert(#result[1].loot == 2, "Should have 2 items")

    -- Restore original state
    ns.BrowserCache.bosses = originalBosses
    ns.BrowserCache.searchIndex = originalSearchIndex
    ns.browserState.slotFilter = originalSlotFilter
    ns.browserState.searchText = originalSearchText
    ns.browserState.equipmentOnlyFilter = originalEquipmentOnly
end

function Tests.GetFilteredData_SlotFilterApplied()
    -- Save original state
    local originalBosses = ns.BrowserCache.bosses
    local originalSearchIndex = ns.BrowserCache.searchIndex
    local originalSlotFilter = ns.browserState.slotFilter
    local originalSearchText = ns.browserState.searchText
    local originalEquipmentOnly = ns.browserState.equipmentOnlyFilter

    -- Setup test conditions
    ns.browserState.slotFilter = "INVTYPE_HEAD"
    ns.browserState.searchText = ""
    ns.browserState.equipmentOnlyFilter = false
    ns.BrowserCache.searchIndex = {}
    ns.BrowserCache.bosses = {
        {
            bossID = 1,
            name = "Test Boss",
            loot = {
                {itemID = 100, name = "Head Item", filterType = FilterType.Head, slot = "Head"},
                {itemID = 101, name = "Chest Item", filterType = FilterType.Chest, slot = "Chest"},
            }
        }
    }

    local result = ns.BrowserFilter:GetFilteredData()

    assert(#result == 1, "Should have 1 boss")
    assert(#result[1].loot == 1, "Should have 1 item after filter")
    assert(result[1].loot[1].itemID == 100, "Should be head item")

    -- Restore original state
    ns.BrowserCache.bosses = originalBosses
    ns.BrowserCache.searchIndex = originalSearchIndex
    ns.browserState.slotFilter = originalSlotFilter
    ns.browserState.searchText = originalSearchText
    ns.browserState.equipmentOnlyFilter = originalEquipmentOnly
end

function Tests.GetFilteredData_EquipmentOnlyFilter()
    -- Save original state
    local originalBosses = ns.BrowserCache.bosses
    local originalSearchIndex = ns.BrowserCache.searchIndex
    local originalSlotFilter = ns.browserState.slotFilter
    local originalSearchText = ns.browserState.searchText
    local originalEquipmentOnly = ns.browserState.equipmentOnlyFilter

    -- Setup test conditions
    ns.browserState.slotFilter = "ALL"
    ns.browserState.searchText = ""
    ns.browserState.equipmentOnlyFilter = true
    ns.BrowserCache.searchIndex = {}
    ns.BrowserCache.bosses = {
        {
            bossID = 1,
            name = "Test Boss",
            loot = {
                {itemID = 100, name = "Gear Item", filterType = FilterType.Head, slot = "Head"},
                {itemID = 101, name = "Mount Item", filterType = FilterType.Other, slot = ""},
            }
        }
    }

    local result = ns.BrowserFilter:GetFilteredData()

    assert(#result == 1, "Should have 1 boss")
    assert(#result[1].loot == 1, "Should have 1 item after filter")
    assert(result[1].loot[1].itemID == 100, "Should be gear item")

    -- Restore original state
    ns.BrowserCache.bosses = originalBosses
    ns.BrowserCache.searchIndex = originalSearchIndex
    ns.browserState.slotFilter = originalSlotFilter
    ns.browserState.searchText = originalSearchText
    ns.browserState.equipmentOnlyFilter = originalEquipmentOnly
end

function Tests.GetFilteredData_NoMatchingItems()
    -- Save original state
    local originalBosses = ns.BrowserCache.bosses
    local originalSearchIndex = ns.BrowserCache.searchIndex
    local originalSlotFilter = ns.browserState.slotFilter
    local originalSearchText = ns.browserState.searchText
    local originalEquipmentOnly = ns.browserState.equipmentOnlyFilter

    -- Setup test conditions
    ns.browserState.slotFilter = "INVTYPE_TRINKET"  -- No trinkets in data
    ns.browserState.searchText = ""
    ns.browserState.equipmentOnlyFilter = false
    ns.BrowserCache.searchIndex = {}
    ns.BrowserCache.bosses = {
        {
            bossID = 1,
            name = "Test Boss",
            loot = {
                {itemID = 100, name = "Head Item", filterType = FilterType.Head, slot = "Head"},
            }
        }
    }

    local result = ns.BrowserFilter:GetFilteredData()

    assert(#result == 0, "Boss should be excluded when no items pass filter")

    -- Restore original state
    ns.BrowserCache.bosses = originalBosses
    ns.BrowserCache.searchIndex = originalSearchIndex
    ns.browserState.slotFilter = originalSlotFilter
    ns.browserState.searchText = originalSearchText
    ns.browserState.equipmentOnlyFilter = originalEquipmentOnly
end

-------------------------------------------------------------------------------
-- EnsureBrowserStateValid Tests (multi-tier instance handling)
-------------------------------------------------------------------------------

function Tests.EnsureBrowserStateValid_MultiTierInstance()
    -- Save original state
    local originalState = {
        expansion = ns.browserState.expansion,
        instanceType = ns.browserState.instanceType,
        selectedInstance = ns.browserState.selectedInstance,
    }
    local originalGetInstances = ns.GetInstancesForTier

    -- Setup: instance 1278 appears in both tier 1 (Current Season) and tier 3 (The War Within)
    -- User is on tier 3, instance 1278 should be valid even though _instanceInfo has tierID=1
    ns.browserState.expansion = 3
    ns.browserState.instanceType = "raid"
    ns.browserState.selectedInstance = 1278

    -- Mock GetInstancesForTier to return 1278 as valid for tier 3
    ns.GetInstancesForTier = function(self, tierID, isRaid)
        if tierID == 3 and isRaid then
            return {{id = 1278, name = "Khaz Algar"}, {id = 1302, name = "Manaforge Omega"}}
        end
        return {}
    end

    -- Run validation
    ns:EnsureBrowserStateValid()

    -- Instance 1278 should NOT be changed (it's valid for tier 3)
    assert(ns.browserState.selectedInstance == 1278,
        "Expected instance 1278 to remain selected, got " .. tostring(ns.browserState.selectedInstance))

    -- Restore original state
    ns.browserState.expansion = originalState.expansion
    ns.browserState.instanceType = originalState.instanceType
    ns.browserState.selectedInstance = originalState.selectedInstance
    ns.GetInstancesForTier = originalGetInstances
end

function Tests.EnsureBrowserStateValid_InstanceNotInTier()
    -- Save original state
    local originalState = {
        expansion = ns.browserState.expansion,
        instanceType = ns.browserState.instanceType,
        selectedInstance = ns.browserState.selectedInstance,
    }
    local originalGetInstances = ns.GetInstancesForTier
    local originalGetFirst = ns.GetFirstInstanceForCurrentState

    -- Setup: user switched to tier 11 (Dragonflight) but instance 1278 is NOT in that tier
    ns.browserState.expansion = 11
    ns.browserState.instanceType = "raid"
    ns.browserState.selectedInstance = 1278

    -- Mock: tier 11 doesn't have instance 1278
    ns.GetInstancesForTier = function(self, tierID, isRaid)
        if tierID == 11 and isRaid then
            return {{id = 999, name = "Dragonflight Raid"}}
        end
        return {}
    end

    -- Mock: first instance for tier 11 is 999
    ns.GetFirstInstanceForCurrentState = function(self, state)
        return 999
    end

    -- Run validation
    ns:EnsureBrowserStateValid()

    -- Instance should be changed to 999 (first instance in tier 11)
    assert(ns.browserState.selectedInstance == 999,
        "Expected instance to be reset to 999, got " .. tostring(ns.browserState.selectedInstance))

    -- Restore original state
    ns.browserState.expansion = originalState.expansion
    ns.browserState.instanceType = originalState.instanceType
    ns.browserState.selectedInstance = originalState.selectedInstance
    ns.GetInstancesForTier = originalGetInstances
    ns.GetFirstInstanceForCurrentState = originalGetFirst
end

-------------------------------------------------------------------------------
-- Integration: EnsureBrowserStateValid auto-selects instance when nil
-------------------------------------------------------------------------------

function Tests.Integration_EnsureValid_SetsInstanceWhenNil()
    -- Save original state
    local originalState = {
        expansion = ns.browserState.expansion,
        instanceType = ns.browserState.instanceType,
        selectedInstance = ns.browserState.selectedInstance,
        selectedDifficultyID = ns.browserState.selectedDifficultyID,
        selectedDifficultyIndex = ns.browserState.selectedDifficultyIndex,
    }
    local originalGetFirst = ns.GetFirstInstanceForCurrentState
    local originalGetInstances = ns.GetInstancesForTier
    local originalCacheVersion = ns.BrowserCache.version

    -- Setup: expansion set, instance nil
    ns.browserState.expansion = 3
    ns.browserState.instanceType = "raid"
    ns.browserState.selectedInstance = nil
    ns.browserState.selectedDifficultyID = 14
    ns.browserState.selectedDifficultyIndex = 1

    ns.GetFirstInstanceForCurrentState = function(self, state)
        return 1278
    end
    ns.GetInstancesForTier = function(self, tierID, isRaid)
        return {{id = 1278, name = "Khaz Algar"}}
    end

    ns:EnsureBrowserStateValid()

    assert(ns.browserState.selectedInstance == 1278,
        "Expected instance 1278, got " .. tostring(ns.browserState.selectedInstance))

    -- Restore
    ns.browserState.expansion = originalState.expansion
    ns.browserState.instanceType = originalState.instanceType
    ns.browserState.selectedInstance = originalState.selectedInstance
    ns.browserState.selectedDifficultyID = originalState.selectedDifficultyID
    ns.browserState.selectedDifficultyIndex = originalState.selectedDifficultyIndex
    ns.GetFirstInstanceForCurrentState = originalGetFirst
    ns.GetInstancesForTier = originalGetInstances
    ns.BrowserCache.version = originalCacheVersion
end

-------------------------------------------------------------------------------
-- Integration: RefreshLeftPanel does NOT mutate state
-------------------------------------------------------------------------------

function Tests.Integration_RefreshLeftPanel_NoStateMutation()
    -- Save original state
    local originalState = {
        expansion = ns.browserState.expansion,
        instanceType = ns.browserState.instanceType,
        selectedInstance = ns.browserState.selectedInstance,
    }
    local originalGetInstances = ns.GetInstancesForTier

    -- Setup: state fully resolved
    ns.browserState.expansion = 3
    ns.browserState.instanceType = "raid"
    ns.browserState.selectedInstance = 1278

    ns.GetInstancesForTier = function(self, tierID, isRaid)
        return {{id = 1278, name = "Khaz Algar"}, {id = 1302, name = "Manaforge Omega"}}
    end

    -- Snapshot state before
    local expBefore = ns.browserState.expansion
    local instBefore = ns.browserState.selectedInstance

    ns:RefreshLeftPanel()

    -- State must not have changed
    assert(ns.browserState.expansion == expBefore,
        "RefreshLeftPanel mutated expansion: " .. tostring(ns.browserState.expansion))
    assert(ns.browserState.selectedInstance == instBefore,
        "RefreshLeftPanel mutated selectedInstance: " .. tostring(ns.browserState.selectedInstance))

    -- Restore
    ns.browserState.expansion = originalState.expansion
    ns.browserState.instanceType = originalState.instanceType
    ns.browserState.selectedInstance = originalState.selectedInstance
    ns.GetInstancesForTier = originalGetInstances
end

-------------------------------------------------------------------------------
-- Integration: Tier switch auto-selects first instance when current is invalid
-------------------------------------------------------------------------------

function Tests.Integration_TierSwitch_AutoSelectsFirstInstance()
    -- Save original state
    local originalState = {
        expansion = ns.browserState.expansion,
        instanceType = ns.browserState.instanceType,
        selectedInstance = ns.browserState.selectedInstance,
        selectedDifficultyID = ns.browserState.selectedDifficultyID,
        selectedDifficultyIndex = ns.browserState.selectedDifficultyIndex,
    }
    local originalGetFirst = ns.GetFirstInstanceForCurrentState
    local originalGetInstances = ns.GetInstancesForTier
    local originalCacheVersion = ns.BrowserCache.version

    -- Setup: switch to tier 11 where instance 1278 doesn't exist
    ns.browserState.expansion = 11
    ns.browserState.instanceType = "raid"
    ns.browserState.selectedInstance = 1278
    ns.browserState.selectedDifficultyID = 14
    ns.browserState.selectedDifficultyIndex = 1

    ns.GetInstancesForTier = function(self, tierID, isRaid)
        if tierID == 11 then
            return {{id = 500, name = "Dragonflight Raid"}}
        end
        return {}
    end
    ns.GetFirstInstanceForCurrentState = function(self, state)
        return 500
    end

    ns:EnsureBrowserStateValid()

    assert(ns.browserState.selectedInstance == 500,
        "Expected instance reset to 500, got " .. tostring(ns.browserState.selectedInstance))

    -- Restore
    ns.browserState.expansion = originalState.expansion
    ns.browserState.instanceType = originalState.instanceType
    ns.browserState.selectedInstance = originalState.selectedInstance
    ns.browserState.selectedDifficultyID = originalState.selectedDifficultyID
    ns.browserState.selectedDifficultyIndex = originalState.selectedDifficultyIndex
    ns.GetFirstInstanceForCurrentState = originalGetFirst
    ns.GetInstancesForTier = originalGetInstances
    ns.BrowserCache.version = originalCacheVersion
end

-------------------------------------------------------------------------------
-- Integration: Tier switch preserves valid instance
-------------------------------------------------------------------------------

function Tests.Integration_TierSwitch_KeepsValidInstance()
    -- Save original state
    local originalState = {
        expansion = ns.browserState.expansion,
        instanceType = ns.browserState.instanceType,
        selectedInstance = ns.browserState.selectedInstance,
        selectedDifficultyID = ns.browserState.selectedDifficultyID,
        selectedDifficultyIndex = ns.browserState.selectedDifficultyIndex,
    }
    local originalGetInstances = ns.GetInstancesForTier
    local originalCacheVersion = ns.BrowserCache.version

    -- Setup: instance 1278 exists in both tier 1 and tier 3
    ns.browserState.expansion = 3
    ns.browserState.instanceType = "raid"
    ns.browserState.selectedInstance = 1278
    ns.browserState.selectedDifficultyID = 14
    ns.browserState.selectedDifficultyIndex = 1

    ns.GetInstancesForTier = function(self, tierID, isRaid)
        if tierID == 3 then
            return {{id = 1278, name = "Khaz Algar"}, {id = 1302, name = "Manaforge Omega"}}
        end
        return {}
    end

    ns:EnsureBrowserStateValid()

    assert(ns.browserState.selectedInstance == 1278,
        "Expected instance 1278 preserved, got " .. tostring(ns.browserState.selectedInstance))

    -- Restore
    ns.browserState.expansion = originalState.expansion
    ns.browserState.instanceType = originalState.instanceType
    ns.browserState.selectedInstance = originalState.selectedInstance
    ns.browserState.selectedDifficultyID = originalState.selectedDifficultyID
    ns.browserState.selectedDifficultyIndex = originalState.selectedDifficultyIndex
    ns.GetInstancesForTier = originalGetInstances
    ns.BrowserCache.version = originalCacheVersion
end

-------------------------------------------------------------------------------
-- CacheInstanceData uses state.expansion (not _instanceInfo.tierID)
-------------------------------------------------------------------------------

function Tests.CacheInstanceData_UsesStateExpansionAsTier()
    -- Verifies the fix: after EnsureBrowserStateValid(), state.expansion is the
    -- correct tier for multi-tier instances, not _instanceInfo.tierID.
    -- Instance 1278 has _instanceInfo.tierID=11, but user is on tier 13.

    -- Save original state
    local originalState = {
        expansion = ns.browserState.expansion,
        instanceType = ns.browserState.instanceType,
        selectedInstance = ns.browserState.selectedInstance,
        selectedDifficultyID = ns.browserState.selectedDifficultyID,
        selectedDifficultyIndex = ns.browserState.selectedDifficultyIndex,
    }
    local originalGetInstances = ns.GetInstancesForTier
    local originalInstanceInfo = ns.Data._instanceInfo

    -- Setup: user is on tier 13 (TWW), instance 1278 has _instanceInfo.tierID=11
    ns.browserState.expansion = 13
    ns.browserState.instanceType = "raid"
    ns.browserState.selectedInstance = 1278
    ns.browserState.selectedDifficultyID = 14
    ns.browserState.selectedDifficultyIndex = 1

    -- Mock _instanceInfo with wrong tierID (simulates last-write-wins)
    ns.Data._instanceInfo = {
        [1278] = { tierID = 11, name = "Khaz Algar" },
    }

    -- Mock: tier 13 has instance 1278
    ns.GetInstancesForTier = function(self, tierID, isRaid)
        if tierID == 13 and isRaid then
            return {{id = 1278, name = "Khaz Algar"}}
        end
        return {}
    end

    -- Run validation (ensures instance is valid for tier 13)
    ns:EnsureBrowserStateValid()

    -- After validation, state.expansion should be 13 (the UI tier)
    -- NOT 11 (from _instanceInfo.tierID)
    assert(ns.browserState.expansion == 13,
        "Expected expansion=13 (UI tier), got " .. tostring(ns.browserState.expansion))
    assert(ns.browserState.selectedInstance == 1278,
        "Expected instance 1278 to remain selected, got " .. tostring(ns.browserState.selectedInstance))

    -- The key invariant: state.expansion (13) is what CacheInstanceData should use
    -- for EJ_SelectTier, NOT _instanceInfo[1278].tierID (11)
    local correctTierForEJ = ns.browserState.expansion
    local wrongTierFromInfo = ns.Data._instanceInfo[1278].tierID
    assert(correctTierForEJ ~= wrongTierFromInfo,
        "Test setup error: tiers should differ to prove the fix works")
    assert(correctTierForEJ == 13,
        "CacheInstanceData should use tier 13 (state.expansion), not " .. tostring(correctTierForEJ))

    -- Restore original state
    ns.browserState.expansion = originalState.expansion
    ns.browserState.instanceType = originalState.instanceType
    ns.browserState.selectedInstance = originalState.selectedInstance
    ns.browserState.selectedDifficultyID = originalState.selectedDifficultyID
    ns.browserState.selectedDifficultyIndex = originalState.selectedDifficultyIndex
    ns.GetInstancesForTier = originalGetInstances
    ns.Data._instanceInfo = originalInstanceInfo
end

-------------------------------------------------------------------------------
-- Integration: No double cache invalidation from RefreshLeftPanel
-------------------------------------------------------------------------------

function Tests.Integration_NoCacheDoubleInvalidation()
    -- Save original state
    local originalState = {
        expansion = ns.browserState.expansion,
        instanceType = ns.browserState.instanceType,
        selectedInstance = ns.browserState.selectedInstance,
    }
    local originalGetInstances = ns.GetInstancesForTier
    local originalCacheVersion = ns.BrowserCache.version

    -- Setup: state fully resolved
    ns.browserState.expansion = 3
    ns.browserState.instanceType = "raid"
    ns.browserState.selectedInstance = 1278

    ns.GetInstancesForTier = function(self, tierID, isRaid)
        return {{id = 1278, name = "Khaz Algar"}}
    end

    -- Snapshot cache version before
    local versionBefore = ns.BrowserCache.version

    ns:RefreshLeftPanel()

    -- Cache version must not have changed (no InvalidateCache call)
    assert(ns.BrowserCache.version == versionBefore,
        "RefreshLeftPanel caused cache invalidation: version " ..
        versionBefore .. " -> " .. ns.BrowserCache.version)

    -- Restore
    ns.browserState.expansion = originalState.expansion
    ns.browserState.instanceType = originalState.instanceType
    ns.browserState.selectedInstance = originalState.selectedInstance
    ns.GetInstancesForTier = originalGetInstances
    ns.BrowserCache.version = originalCacheVersion
end

-------------------------------------------------------------------------------
-- NeedsEJRetry Tests (EJ class filter retry mechanism)
-------------------------------------------------------------------------------

function Tests.NeedsEJRetry_NilFilterTypeWithClassFilter()
    local bosses = {
        { bossID = 1, name = "Boss", loot = {{ itemID = 100, filterType = nil }} },
    }
    local result = ns._test.NeedsEJRetry(bosses, 8, 0)
    assert(result == true, "Nil filterType with active class filter should need retry")
end

function Tests.NeedsEJRetry_ValidFilterType()
    local bosses = {
        { bossID = 1, name = "Boss", loot = {{ itemID = 100, filterType = 2 }} },
    }
    local result = ns._test.NeedsEJRetry(bosses, 8, 0)
    assert(result == false, "Valid filterType should not need retry")
end

function Tests.NeedsEJRetry_AllClasses()
    local bosses = {
        { bossID = 1, name = "Boss", loot = {{ itemID = 100, filterType = nil }} },
    }
    local result = ns._test.NeedsEJRetry(bosses, 0, 0)
    assert(result == false, "classFilter=0 (All Classes) should not need retry")
end

function Tests.NeedsEJRetry_MaxRetriesReached()
    local bosses = {
        { bossID = 1, name = "Boss", loot = {{ itemID = 100, filterType = nil }} },
    }
    local result = ns._test.NeedsEJRetry(bosses, 8, 1)
    assert(result == false, "retryCount >= 1 should not retry")
end

function Tests.NeedsEJRetry_EmptyBosses()
    local result = ns._test.NeedsEJRetry({}, 8, 0)
    assert(result == false, "Empty bosses should not need retry")
end

function Tests.NeedsEJRetry_NilBosses()
    local result = ns._test.NeedsEJRetry(nil, 8, 0)
    assert(result == false, "Nil bosses should not need retry")
end

function Tests.NeedsEJRetry_BossWithNoLoot()
    local bosses = {
        { bossID = 1, name = "Boss", loot = {} },
    }
    local result = ns._test.NeedsEJRetry(bosses, 8, 0)
    assert(result == false, "Boss with empty loot should not need retry")
end

function Tests.NeedsEJRetry_MixedFilterTypes()
    local bosses = {
        { bossID = 1, name = "Boss1", loot = {{ itemID = 100, filterType = 2 }} },
        { bossID = 2, name = "Boss2", loot = {{ itemID = 200, filterType = nil }} },
    }
    local result = ns._test.NeedsEJRetry(bosses, 8, 0)
    assert(result == true, "Any boss with nil filterType on first item should need retry")
end

-------------------------------------------------------------------------------
-- EnsureBrowserStateValid preserves difficulty through world boss transition
-------------------------------------------------------------------------------

function Tests.EnsureBrowserStateValid_PreservesDifficultyForWorldBoss()
    -- Save original state
    local originalState = {
        expansion = ns.browserState.expansion,
        instanceType = ns.browserState.instanceType,
        selectedInstance = ns.browserState.selectedInstance,
        selectedDifficultyID = ns.browserState.selectedDifficultyID,
        selectedDifficultyIndex = ns.browserState.selectedDifficultyIndex,
        _preservedDifficultyID = ns.browserState._preservedDifficultyID,
    }
    local originalGetDifficulties = ns.GetDifficultiesForInstance
    local originalGetInstances = ns.GetInstancesForTier
    local originalGetInstanceInfo = ns.GetInstanceInfo

    -- Setup: Heroic (15) selected on instance 1302
    ns.browserState.expansion = 3
    ns.browserState.instanceType = "raid"
    ns.browserState.selectedInstance = 1302
    ns.browserState.selectedDifficultyID = 15
    ns.browserState.selectedDifficultyIndex = 2
    ns.browserState._preservedDifficultyID = nil

    -- Mock: 1302 has Normal+Heroic, 1278 is a world boss (1 difficulty in static data)
    ns.GetDifficultiesForInstance = function(self, instanceID)
        if instanceID == 1302 then
            return {{id = 14, name = "Normal"}, {id = 15, name = "Heroic"}}
        elseif instanceID == 1278 then
            return {{id = 14, name = "Normal"}}
        end
        return {}
    end
    ns.GetInstancesForTier = function(self, tierID, isRaid)
        return {{id = 1278, name = "Khaz Algar"}, {id = 1302, name = "Manaforge Omega"}}
    end
    -- Mock: 1278 is a world boss (shouldDisplayDifficulty = false)
    ns.GetInstanceInfo = function(self, instanceID)
        if instanceID == 1278 then
            return {shouldDisplayDifficulty = false}
        end
        return {shouldDisplayDifficulty = true}
    end

    -- Step 1: Switch to world boss
    ns.browserState.selectedInstance = 1278
    ns:EnsureBrowserStateValid()

    -- World boss: selectedDifficultyID should be valid for API (14), preserved saves user's (15)
    assert(ns.browserState.selectedDifficultyID == 14,
        "World boss should set difficultyID=14 for API, got " .. tostring(ns.browserState.selectedDifficultyID))
    assert(ns.browserState._preservedDifficultyID == 15,
        "World boss should preserve original difficultyID=15, got " .. tostring(ns.browserState._preservedDifficultyID))

    -- Step 2: Switch back to normal raid
    ns.browserState.selectedInstance = 1302
    ns:EnsureBrowserStateValid()

    assert(ns.browserState.selectedDifficultyID == 15,
        "After return from world boss, difficultyID should be 15, got " .. tostring(ns.browserState.selectedDifficultyID))
    assert(ns.browserState.selectedDifficultyIndex == 2,
        "After return from world boss, difficultyIndex should be 2, got " .. tostring(ns.browserState.selectedDifficultyIndex))
    assert(ns.browserState._preservedDifficultyID == nil,
        "After return from world boss, _preservedDifficultyID should be nil, got " .. tostring(ns.browserState._preservedDifficultyID))

    -- Restore
    ns.browserState.expansion = originalState.expansion
    ns.browserState.instanceType = originalState.instanceType
    ns.browserState.selectedInstance = originalState.selectedInstance
    ns.browserState.selectedDifficultyID = originalState.selectedDifficultyID
    ns.browserState.selectedDifficultyIndex = originalState.selectedDifficultyIndex
    ns.browserState._preservedDifficultyID = originalState._preservedDifficultyID
    ns.GetDifficultiesForInstance = originalGetDifficulties
    ns.GetInstancesForTier = originalGetInstances
    ns.GetInstanceInfo = originalGetInstanceInfo
end

-------------------------------------------------------------------------------
-- World boss: repeated EnsureBrowserStateValid calls don't overwrite preserved
-------------------------------------------------------------------------------

function Tests.WorldBossMultipleCallsNoOverwrite()
    -- Save original state
    local originalState = {
        expansion = ns.browserState.expansion,
        instanceType = ns.browserState.instanceType,
        selectedInstance = ns.browserState.selectedInstance,
        selectedDifficultyID = ns.browserState.selectedDifficultyID,
        selectedDifficultyIndex = ns.browserState.selectedDifficultyIndex,
        _preservedDifficultyID = ns.browserState._preservedDifficultyID,
    }
    local originalGetDifficulties = ns.GetDifficultiesForInstance
    local originalGetInstances = ns.GetInstancesForTier
    local originalGetInstanceInfo = ns.GetInstanceInfo

    -- Setup: Heroic (15) on a normal raid
    ns.browserState.expansion = 3
    ns.browserState.instanceType = "raid"
    ns.browserState.selectedInstance = 1278
    ns.browserState.selectedDifficultyID = 15
    ns.browserState.selectedDifficultyIndex = 2
    ns.browserState._preservedDifficultyID = nil

    ns.GetDifficultiesForInstance = function(self, instanceID)
        if instanceID == 1278 then
            return {{id = 14, name = "Normal"}}
        end
        return {}
    end
    ns.GetInstancesForTier = function(self, tierID, isRaid)
        return {{id = 1278, name = "Khaz Algar"}}
    end
    ns.GetInstanceInfo = function(self, instanceID)
        return {shouldDisplayDifficulty = false}
    end

    -- First call: should preserve 15, set selectedDifficultyID to 14
    ns:EnsureBrowserStateValid()
    assert(ns.browserState._preservedDifficultyID == 15,
        "First call should preserve 15, got " .. tostring(ns.browserState._preservedDifficultyID))
    assert(ns.browserState.selectedDifficultyID == 14,
        "First call should set API difficulty to 14, got " .. tostring(ns.browserState.selectedDifficultyID))

    -- Second call: should NOT overwrite _preservedDifficultyID (still 15, not 14)
    ns:EnsureBrowserStateValid()
    assert(ns.browserState._preservedDifficultyID == 15,
        "Second call should NOT overwrite preserved (still 15), got " .. tostring(ns.browserState._preservedDifficultyID))
    assert(ns.browserState.selectedDifficultyID == 14,
        "Second call should keep API difficulty at 14, got " .. tostring(ns.browserState.selectedDifficultyID))

    -- Restore
    ns.browserState.expansion = originalState.expansion
    ns.browserState.instanceType = originalState.instanceType
    ns.browserState.selectedInstance = originalState.selectedInstance
    ns.browserState.selectedDifficultyID = originalState.selectedDifficultyID
    ns.browserState.selectedDifficultyIndex = originalState.selectedDifficultyIndex
    ns.browserState._preservedDifficultyID = originalState._preservedDifficultyID
    ns.GetDifficultiesForInstance = originalGetDifficulties
    ns.GetInstancesForTier = originalGetInstances
    ns.GetInstanceInfo = originalGetInstanceInfo
end

-------------------------------------------------------------------------------
-- Switching between two world bosses preserves original difficulty
-------------------------------------------------------------------------------

function Tests.SwitchBetweenWorldBosses()
    -- Save original state
    local originalState = {
        expansion = ns.browserState.expansion,
        instanceType = ns.browserState.instanceType,
        selectedInstance = ns.browserState.selectedInstance,
        selectedDifficultyID = ns.browserState.selectedDifficultyID,
        selectedDifficultyIndex = ns.browserState.selectedDifficultyIndex,
        _preservedDifficultyID = ns.browserState._preservedDifficultyID,
    }
    local originalGetDifficulties = ns.GetDifficultiesForInstance
    local originalGetInstances = ns.GetInstancesForTier
    local originalGetInstanceInfo = ns.GetInstanceInfo

    -- Setup: Heroic (15) selected, switching to first world boss
    ns.browserState.expansion = 3
    ns.browserState.instanceType = "raid"
    ns.browserState.selectedInstance = 1278
    ns.browserState.selectedDifficultyID = 15
    ns.browserState.selectedDifficultyIndex = 2
    ns.browserState._preservedDifficultyID = nil

    -- Mock: both 1278 and 2000 are world bosses
    ns.GetDifficultiesForInstance = function(self, instanceID)
        return {{id = 14, name = "Normal"}}
    end
    ns.GetInstancesForTier = function(self, tierID, isRaid)
        return {{id = 1278, name = "World Boss A"}, {id = 2000, name = "World Boss B"}, {id = 1302, name = "Raid"}}
    end
    ns.GetInstanceInfo = function(self, instanceID)
        if instanceID == 1278 or instanceID == 2000 then
            return {shouldDisplayDifficulty = false}
        end
        return {shouldDisplayDifficulty = true}
    end

    -- Switch to first world boss
    ns:EnsureBrowserStateValid()
    assert(ns.browserState._preservedDifficultyID == 15,
        "First world boss should preserve 15, got " .. tostring(ns.browserState._preservedDifficultyID))

    -- Switch to second world boss
    ns.browserState.selectedInstance = 2000
    ns:EnsureBrowserStateValid()
    assert(ns.browserState._preservedDifficultyID == 15,
        "Second world boss should still preserve 15, got " .. tostring(ns.browserState._preservedDifficultyID))
    assert(ns.browserState.selectedDifficultyID == 14,
        "Second world boss should use API difficulty 14, got " .. tostring(ns.browserState.selectedDifficultyID))

    -- Restore
    ns.browserState.expansion = originalState.expansion
    ns.browserState.instanceType = originalState.instanceType
    ns.browserState.selectedInstance = originalState.selectedInstance
    ns.browserState.selectedDifficultyID = originalState.selectedDifficultyID
    ns.browserState.selectedDifficultyIndex = originalState.selectedDifficultyIndex
    ns.browserState._preservedDifficultyID = originalState._preservedDifficultyID
    ns.GetDifficultiesForInstance = originalGetDifficulties
    ns.GetInstancesForTier = originalGetInstances
    ns.GetInstanceInfo = originalGetInstanceInfo
end

-------------------------------------------------------------------------------
-- Preserved difficulty not available on new raid falls to SetDefaultDifficulty
-------------------------------------------------------------------------------

function Tests.PreservedDifficultyNotAvailableOnNewRaid()
    -- Save original state
    local originalState = {
        expansion = ns.browserState.expansion,
        instanceType = ns.browserState.instanceType,
        selectedInstance = ns.browserState.selectedInstance,
        selectedDifficultyID = ns.browserState.selectedDifficultyID,
        selectedDifficultyIndex = ns.browserState.selectedDifficultyIndex,
        _preservedDifficultyID = ns.browserState._preservedDifficultyID,
    }
    local originalGetDifficulties = ns.GetDifficultiesForInstance
    local originalGetInstances = ns.GetInstancesForTier
    local originalGetInstanceInfo = ns.GetInstanceInfo

    -- Setup: _preservedDifficultyID = 16 (Mythic), switching to a raid that only has Normal
    ns.browserState.expansion = 3
    ns.browserState.instanceType = "raid"
    ns.browserState.selectedInstance = 1278
    ns.browserState.selectedDifficultyID = 14
    ns.browserState.selectedDifficultyIndex = 1
    ns.browserState._preservedDifficultyID = 16  -- Mythic, pre-set as if coming from world boss

    -- Mock: 1278 is world boss, 1302 only has Normal
    ns.GetDifficultiesForInstance = function(self, instanceID)
        if instanceID == 1302 then
            return {{id = 14, name = "Normal"}}
        elseif instanceID == 1278 then
            return {{id = 14, name = "Normal"}}
        end
        return {}
    end
    ns.GetInstancesForTier = function(self, tierID, isRaid)
        return {{id = 1278, name = "World Boss"}, {id = 1302, name = "Easy Raid"}}
    end
    ns.GetInstanceInfo = function(self, instanceID)
        if instanceID == 1278 then
            return {shouldDisplayDifficulty = false}
        end
        return {shouldDisplayDifficulty = true}
    end

    -- Switch to normal raid that doesn't have Mythic (16)
    ns.browserState.selectedInstance = 1302
    ns:EnsureBrowserStateValid()

    -- _preservedDifficultyID should be cleared
    assert(ns.browserState._preservedDifficultyID == nil,
        "Preserved difficulty should be cleared after restore, got " .. tostring(ns.browserState._preservedDifficultyID))
    -- FindDifficultyByID(difficulties, 16) returns nil, so SetDefaultDifficulty should run
    -- Default for a raid with only Normal should be 14
    assert(ns.browserState.selectedDifficultyID == 14,
        "Should fall to default difficulty 14, got " .. tostring(ns.browserState.selectedDifficultyID))

    -- Restore
    ns.browserState.expansion = originalState.expansion
    ns.browserState.instanceType = originalState.instanceType
    ns.browserState.selectedInstance = originalState.selectedInstance
    ns.browserState.selectedDifficultyID = originalState.selectedDifficultyID
    ns.browserState.selectedDifficultyIndex = originalState.selectedDifficultyIndex
    ns.browserState._preservedDifficultyID = originalState._preservedDifficultyID
    ns.GetDifficultiesForInstance = originalGetDifficulties
    ns.GetInstancesForTier = originalGetInstances
    ns.GetInstanceInfo = originalGetInstanceInfo
end

return Tests
