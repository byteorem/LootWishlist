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

function Tests.PassesSlotFilter_WeaponTwoHand()
    local result = ns.BrowserFilter:PassesSlotFilter(FilterType.TwoHand, "WEAPON")
    assert(result == true, "TwoHand should pass WEAPON filter")
end

function Tests.PassesSlotFilter_WeaponOneHand()
    local result = ns.BrowserFilter:PassesSlotFilter(FilterType.OneHand, "WEAPON")
    assert(result == true, "OneHand should pass WEAPON filter")
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

return Tests
