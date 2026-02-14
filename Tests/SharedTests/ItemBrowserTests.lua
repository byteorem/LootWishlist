-- Shared Item Browser Test Definitions
-- Single source of truth for both CLI and WoWUnit test runners
-- Usage: ns._sharedTests.ItemBrowser(T) returns a test table
--   T must implement: T.IsTrue(val, msg), T.IsFalse(val, msg), T.AreEqual(expected, actual, msg)

local _, ns = ...

ns._sharedTests = ns._sharedTests or {}

ns._sharedTests.ItemBrowser = function(T)
    local tests = {}
    local FilterType = Enum.ItemSlotFilterType

    ---------------------------------------------------------------------------
    -- PassesSearchFilter Tests (addresses past false positive issue)
    ---------------------------------------------------------------------------

    function tests.PassesSearchFilter_ExactMatch()
        local searchIndex = {}
        searchIndex["test"] = { ["123|456"] = true }

        local result = ns.BrowserFilter:PassesSearchFilter(123, 456, "test", searchIndex)
        T.IsTrue(result, "Expected true for exact match")
    end

    function tests.PassesSearchFilter_NoMatch()
        local searchIndex = {}
        searchIndex["test"] = { ["123|456"] = true }

        local result = ns.BrowserFilter:PassesSearchFilter(999, 999, "test", searchIndex)
        T.IsFalse(result, "Expected false for no match")
    end

    function tests.PassesSearchFilter_EmptySearch()
        local result = ns.BrowserFilter:PassesSearchFilter(123, 456, "", {})
        T.IsTrue(result, "Empty search should pass")
    end

    function tests.PassesSearchFilter_NilSearch()
        local result = ns.BrowserFilter:PassesSearchFilter(123, 456, nil, {})
        T.IsTrue(result, "Nil search should pass")
    end

    function tests.PassesSearchFilter_CaseInsensitive()
        local searchIndex = {}
        searchIndex["test"] = { ["123|456"] = true }

        local result = ns.BrowserFilter:PassesSearchFilter(123, 456, "TEST", searchIndex)
        T.IsTrue(result, "Search should be case insensitive")
    end

    function tests.PassesSearchFilter_PartialMatch()
        local searchIndex = {}
        searchIndex["tes"] = { ["123|456"] = true }
        searchIndex["test"] = { ["123|456"] = true }

        local result = ns.BrowserFilter:PassesSearchFilter(123, 456, "tes", searchIndex)
        T.IsTrue(result, "Partial match should pass")
    end

    function tests.PassesSearchFilter_NoIndexEntryForSearch()
        local searchIndex = {}
        searchIndex["foo"] = { ["123|456"] = true }

        local result = ns.BrowserFilter:PassesSearchFilter(123, 456, "bar", searchIndex)
        T.IsFalse(result, "No index entry should fail")
    end

    ---------------------------------------------------------------------------
    -- PassesSearchFilterLegacy Tests (substring matching bugs)
    -- Note: These functions return truthy values (position numbers from find())
    -- rather than booleans, so we check truthiness not exact boolean values.
    ---------------------------------------------------------------------------

    function tests.PassesSearchFilterLegacy_ExactMatch()
        local result = ns.BrowserFilter:PassesSearchFilterLegacy("Test Item", "Boss Name", "Test Item")
        T.IsTrue(result, "Exact match should pass")
    end

    function tests.PassesSearchFilterLegacy_PartialMatch()
        local result = ns.BrowserFilter:PassesSearchFilterLegacy("Test Item", "Boss Name", "Test")
        T.IsTrue(result, "Partial match should pass")
    end

    function tests.PassesSearchFilterLegacy_CaseInsensitive()
        local result = ns.BrowserFilter:PassesSearchFilterLegacy("Test Item", "Boss Name", "test")
        T.IsTrue(result, "Case insensitive match should pass")
    end

    function tests.PassesSearchFilterLegacy_MatchBossName()
        local result = ns.BrowserFilter:PassesSearchFilterLegacy("Test Item", "Boss Name", "Boss")
        T.IsTrue(result, "Boss name match should pass")
    end

    function tests.PassesSearchFilterLegacy_NoMatch()
        local result = ns.BrowserFilter:PassesSearchFilterLegacy("Test Item", "Boss Name", "xyz")
        T.IsFalse(result, "No match should fail")
    end

    function tests.PassesSearchFilterLegacy_EmptySearch()
        local result = ns.BrowserFilter:PassesSearchFilterLegacy("Test Item", "Boss Name", "")
        T.IsTrue(result, "Empty search should pass")
    end

    function tests.PassesSearchFilterLegacy_NilSearch()
        local result = ns.BrowserFilter:PassesSearchFilterLegacy("Test Item", "Boss Name", nil)
        T.IsTrue(result, "Nil search should pass")
    end

    function tests.PassesSearchFilterLegacy_NilItemName()
        local result = ns.BrowserFilter:PassesSearchFilterLegacy(nil, "Boss Name", "Boss")
        T.IsTrue(result, "Nil item name with boss match should pass")
    end

    function tests.PassesSearchFilterLegacy_NilBothNames()
        local result = ns.BrowserFilter:PassesSearchFilterLegacy(nil, nil, "test")
        T.IsFalse(result, "Nil both names should fail")
    end

    ---------------------------------------------------------------------------
    -- PassesSlotFilter Tests (enum-based)
    ---------------------------------------------------------------------------

    function tests.PassesSlotFilter_AllFilter()
        local result = ns.BrowserFilter:PassesSlotFilter(FilterType.Head, "ALL")
        T.IsTrue(result, "ALL filter should pass any slot")
    end

    function tests.PassesSlotFilter_ExactMatch()
        local result = ns.BrowserFilter:PassesSlotFilter(FilterType.Head, "INVTYPE_HEAD")
        T.IsTrue(result, "Exact match should pass")
    end

    function tests.PassesSlotFilter_NoMatch()
        local result = ns.BrowserFilter:PassesSlotFilter(FilterType.Head, "INVTYPE_CHEST")
        T.IsFalse(result, "Different slot should fail")
    end

    function tests.PassesSlotFilter_WeaponMainHand()
        local result = ns.BrowserFilter:PassesSlotFilter(FilterType.MainHand, "WEAPON")
        T.IsTrue(result, "MainHand should pass WEAPON filter")
    end

    function tests.PassesSlotFilter_WeaponOffHand()
        local result = ns.BrowserFilter:PassesSlotFilter(FilterType.OffHand, "WEAPON")
        T.IsTrue(result, "OffHand should pass WEAPON filter")
    end

    function tests.PassesSlotFilter_NonWeaponForWeaponFilter()
        local result = ns.BrowserFilter:PassesSlotFilter(FilterType.Head, "WEAPON")
        T.IsFalse(result, "Head should fail WEAPON filter")
    end

    function tests.PassesSlotFilter_UnknownFilter()
        local result = ns.BrowserFilter:PassesSlotFilter(FilterType.Head, "UNKNOWN_FILTER")
        T.IsTrue(result, "Unknown filter should allow all")
    end

    function tests.PassesSlotFilter_NilFilterType()
        local result = ns.BrowserFilter:PassesSlotFilter(nil, "INVTYPE_HEAD")
        T.IsFalse(result, "Nil filterType should fail")
    end

    ---------------------------------------------------------------------------
    -- PassesSlotFilterLegacy Tests (string-based fallback)
    -- Note: These functions return truthy values (position numbers from find())
    -- rather than booleans, so we check truthiness not exact boolean values.
    ---------------------------------------------------------------------------

    function tests.PassesSlotFilterLegacy_AllFilter()
        local result = ns.BrowserFilter:PassesSlotFilterLegacy("Head", "ALL")
        T.IsTrue(result, "ALL filter should pass")
    end

    function tests.PassesSlotFilterLegacy_ExactMatch()
        local result = ns.BrowserFilter:PassesSlotFilterLegacy("Head", "INVTYPE_HEAD")
        T.IsTrue(result, "Exact match should pass")
    end

    function tests.PassesSlotFilterLegacy_WeaponOneHand()
        local result = ns.BrowserFilter:PassesSlotFilterLegacy("One-Hand Weapon", "WEAPON")
        T.IsTrue(result, "One-Hand Weapon should pass WEAPON filter")
    end

    function tests.PassesSlotFilterLegacy_WeaponShield()
        local result = ns.BrowserFilter:PassesSlotFilterLegacy("Shield", "WEAPON")
        T.IsTrue(result, "Shield should pass WEAPON filter")
    end

    function tests.PassesSlotFilterLegacy_WeaponOffHand()
        local result = ns.BrowserFilter:PassesSlotFilterLegacy("Off Hand", "WEAPON")
        T.IsTrue(result, "Off Hand should pass WEAPON filter")
    end

    function tests.PassesSlotFilterLegacy_WeaponHeldInOff()
        local result = ns.BrowserFilter:PassesSlotFilterLegacy("Held In Off-hand", "WEAPON")
        T.IsTrue(result, "Held In Off-hand should pass WEAPON filter")
    end

    function tests.PassesSlotFilterLegacy_NonWeaponForWeaponFilter()
        local result = ns.BrowserFilter:PassesSlotFilterLegacy("Head", "WEAPON")
        T.IsFalse(result, "Head should fail WEAPON filter")
    end

    ---------------------------------------------------------------------------
    -- IsEquipment Tests (equipment filter)
    ---------------------------------------------------------------------------

    function tests.IsEquipment_HeadSlot()
        local result = ns.BrowserFilter:IsEquipment(FilterType.Head, "")
        T.IsTrue(result, "Head should be equipment")
    end

    function tests.IsEquipment_NeckSlot()
        local result = ns.BrowserFilter:IsEquipment(FilterType.Neck, "")
        T.IsTrue(result, "Neck should be equipment")
    end

    function tests.IsEquipment_TrinketSlot()
        local result = ns.BrowserFilter:IsEquipment(FilterType.Trinket, "")
        T.IsTrue(result, "Trinket should be equipment")
    end

    function tests.IsEquipment_MainHandSlot()
        local result = ns.BrowserFilter:IsEquipment(FilterType.MainHand, "")
        T.IsTrue(result, "MainHand should be equipment")
    end

    function tests.IsEquipment_OtherType()
        local result = ns.BrowserFilter:IsEquipment(FilterType.Other, "")
        T.IsFalse(result, "Other should not be equipment")
    end

    function tests.IsEquipment_NilWithSlotString()
        local result = ns.BrowserFilter:IsEquipment(nil, "Head")
        T.IsTrue(result, "Nil filterType with slot string should be equipment")
    end

    function tests.IsEquipment_NilWithEmptySlot()
        local result = ns.BrowserFilter:IsEquipment(nil, "")
        T.IsFalse(result, "Nil filterType with empty slot should not be equipment")
    end

    function tests.IsEquipment_NilWithNilSlot()
        local result = ns.BrowserFilter:IsEquipment(nil, nil)
        T.IsFalse(result, "Nil filterType with nil slot should not be equipment")
    end

    ---------------------------------------------------------------------------
    -- IsCacheValid Tests (addresses loadingState stuck issue)
    ---------------------------------------------------------------------------

    function tests.IsCacheValid_NotReadyState()
        local originalState = ns.browserState.selectedInstance
        local originalCache = {
            loadingState = ns.BrowserCache.loadingState,
            instanceID = ns.BrowserCache.instanceID,
            classFilter = ns.BrowserCache.classFilter,
            difficultyID = ns.BrowserCache.difficultyID,
            expansion = ns.BrowserCache.expansion,
        }

        ns.browserState.selectedInstance = 1234
        ns.BrowserCache.loadingState = "loading"
        ns.BrowserCache.instanceID = 1234
        ns.BrowserCache.classFilter = ns.browserState.classFilter
        ns.BrowserCache.difficultyID = ns.browserState.selectedDifficultyID
        ns.BrowserCache.expansion = ns.browserState.expansion

        local result = ns._test.IsCacheValid()
        T.IsFalse(result, "Loading state should be invalid")

        ns.browserState.selectedInstance = originalState
        ns.BrowserCache.loadingState = originalCache.loadingState
        ns.BrowserCache.instanceID = originalCache.instanceID
        ns.BrowserCache.classFilter = originalCache.classFilter
        ns.BrowserCache.difficultyID = originalCache.difficultyID
        ns.BrowserCache.expansion = originalCache.expansion
    end

    function tests.IsCacheValid_InstanceMismatch()
        local originalState = ns.browserState.selectedInstance
        local originalCache = {
            loadingState = ns.BrowserCache.loadingState,
            instanceID = ns.BrowserCache.instanceID,
        }

        ns.browserState.selectedInstance = 1234
        ns.BrowserCache.loadingState = "ready"
        ns.BrowserCache.instanceID = 5678

        local result = ns._test.IsCacheValid()
        T.IsFalse(result, "Instance mismatch should be invalid")

        ns.browserState.selectedInstance = originalState
        ns.BrowserCache.loadingState = originalCache.loadingState
        ns.BrowserCache.instanceID = originalCache.instanceID
    end

    function tests.IsCacheValid_ValidCache()
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
        T.IsTrue(result, "All matching fields should be valid")

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

    function tests.IsCacheValid_ClassMismatch()
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

        ns.browserState.selectedInstance = 1234
        ns.browserState.classFilter = 2
        ns.browserState.selectedDifficultyID = 14
        ns.browserState.expansion = 10

        ns.BrowserCache.loadingState = "ready"
        ns.BrowserCache.instanceID = 1234
        ns.BrowserCache.classFilter = 1
        ns.BrowserCache.difficultyID = 14
        ns.BrowserCache.expansion = 10

        local result = ns._test.IsCacheValid()
        T.IsFalse(result, "Class mismatch should invalidate")

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

    function tests.IsCacheValid_DifficultyMismatch()
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

        ns.browserState.selectedInstance = 1234
        ns.browserState.classFilter = 1
        ns.browserState.selectedDifficultyID = 15
        ns.browserState.expansion = 10

        ns.BrowserCache.loadingState = "ready"
        ns.BrowserCache.instanceID = 1234
        ns.BrowserCache.classFilter = 1
        ns.BrowserCache.difficultyID = 14
        ns.BrowserCache.expansion = 10

        local result = ns._test.IsCacheValid()
        T.IsFalse(result, "Difficulty mismatch should invalidate")

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

    function tests.IsCacheValid_ExpansionMismatch()
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

        ns.browserState.selectedInstance = 1234
        ns.browserState.classFilter = 1
        ns.browserState.selectedDifficultyID = 14
        ns.browserState.expansion = 10

        ns.BrowserCache.loadingState = "ready"
        ns.BrowserCache.instanceID = 1234
        ns.BrowserCache.classFilter = 1
        ns.BrowserCache.difficultyID = 14
        ns.BrowserCache.expansion = 9

        local result = ns._test.IsCacheValid()
        T.IsFalse(result, "Expansion mismatch should invalidate")

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

    ---------------------------------------------------------------------------
    -- InvalidateCache Tests
    ---------------------------------------------------------------------------

    function tests.InvalidateCache_ResetsState()
        local originalCache = {
            version = ns.BrowserCache.version,
            loadingState = ns.BrowserCache.loadingState,
            instanceID = ns.BrowserCache.instanceID,
        }

        ns.BrowserCache.loadingState = "ready"
        ns.BrowserCache.instanceID = 1234
        local versionBefore = ns.BrowserCache.version

        ns._test.InvalidateCache()

        T.AreEqual("idle", ns.BrowserCache.loadingState, "loadingState should be idle")
        T.IsTrue(ns.BrowserCache.instanceID == nil, "instanceID should be nil")
        T.AreEqual(versionBefore + 1, ns.BrowserCache.version, "version should increment")

        ns.BrowserCache.version = originalCache.version
        ns.BrowserCache.loadingState = originalCache.loadingState
        ns.BrowserCache.instanceID = originalCache.instanceID
    end

    function tests.InvalidateCache_VersionIncrementsEachCall()
        local originalVersion = ns.BrowserCache.version

        local v1 = ns.BrowserCache.version
        ns._test.InvalidateCache()
        local v2 = ns.BrowserCache.version
        ns._test.InvalidateCache()
        local v3 = ns.BrowserCache.version

        T.AreEqual(v1 + 1, v2, "First invalidate should increment")
        T.AreEqual(v2 + 1, v3, "Second invalidate should increment again")

        ns.BrowserCache.version = originalVersion
    end

    function tests.InvalidateCache_ClearsSearchIndex()
        local originalSearchIndex = ns.BrowserCache.searchIndex
        local originalVersion = ns.BrowserCache.version

        ns.BrowserCache.searchIndex = {}
        ns.BrowserCache.searchIndex["test"] = { ["123|456"] = true }

        ns._test.InvalidateCache()

        T.IsTrue(ns.BrowserCache.searchIndex["test"] == nil, "Search index should be cleared")

        ns.BrowserCache.searchIndex = originalSearchIndex
        ns.BrowserCache.version = originalVersion
    end

    function tests.InvalidateCache_ClearsBosses()
        local originalBosses = ns.BrowserCache.bosses
        local originalVersion = ns.BrowserCache.version

        ns.BrowserCache.bosses = {}
        table.insert(ns.BrowserCache.bosses, { bossID = 1, name = "Test" })

        ns._test.InvalidateCache()

        T.AreEqual(0, #ns.BrowserCache.bosses, "Bosses should be cleared")

        ns.BrowserCache.bosses = originalBosses
        ns.BrowserCache.version = originalVersion
    end

    ---------------------------------------------------------------------------
    -- BuildSearchIndexEntry Tests
    ---------------------------------------------------------------------------

    function tests.BuildSearchIndexEntry_SingleChar()
        local searchIndex = {}
        ns._test.BuildSearchIndexEntry(searchIndex, "123|456", "Test")

        T.IsTrue(searchIndex["t"] ~= nil, "Should have 't' entry")
        T.IsTrue(searchIndex["t"]["123|456"] == true, "Should map to item key")
    end

    function tests.BuildSearchIndexEntry_MultipleChars()
        local searchIndex = {}
        ns._test.BuildSearchIndexEntry(searchIndex, "123|456", "Test")

        T.IsTrue(searchIndex["t"] ~= nil, "Should have 't' entry")
        T.IsTrue(searchIndex["te"] ~= nil, "Should have 'te' entry")
        T.IsTrue(searchIndex["tes"] ~= nil, "Should have 'tes' entry")
        T.IsTrue(searchIndex["test"] ~= nil, "Should have 'test' entry")
    end

    function tests.BuildSearchIndexEntry_CaseInsensitive()
        local searchIndex = {}
        ns._test.BuildSearchIndexEntry(searchIndex, "123|456", "TEST")

        T.IsTrue(searchIndex["t"] ~= nil, "Should have lowercase 't' entry")
        T.IsTrue(searchIndex["test"] ~= nil, "Should have lowercase 'test' entry")
    end

    function tests.BuildSearchIndexEntry_MultipleItems()
        local searchIndex = {}
        ns._test.BuildSearchIndexEntry(searchIndex, "111|222", "Test")
        ns._test.BuildSearchIndexEntry(searchIndex, "333|444", "Testing")

        T.IsTrue(searchIndex["test"]["111|222"] == true, "First item should be in test")
        T.IsTrue(searchIndex["test"]["333|444"] == true, "Second item should be in test")
    end

    function tests.BuildSearchIndexEntry_MaxLength()
        local searchIndex = {}
        local longName = "ThisIsAVeryLongItemNameThatExceedsLimit"
        ns._test.BuildSearchIndexEntry(searchIndex, "123|456", longName)

        local maxLen = ns.Constants.MAX_NGRAM_PREFIX_LENGTH
        local expectedPrefix = longName:lower():sub(1, maxLen)
        T.IsTrue(searchIndex[expectedPrefix] ~= nil, "Should have max length prefix")

        local longerPrefix = longName:lower():sub(1, maxLen + 1)
        T.IsTrue(searchIndex[longerPrefix] == nil, "Should not have prefix beyond max")
    end

    ---------------------------------------------------------------------------
    -- GetFilteredData Tests
    ---------------------------------------------------------------------------

    function tests.GetFilteredData_EmptyCache()
        local originalBosses = ns.BrowserCache.bosses

        ns.BrowserCache.bosses = {}

        local result = ns.BrowserFilter:GetFilteredData()

        T.AreEqual(0, #result, "Empty cache should return empty result")

        ns.BrowserCache.bosses = originalBosses
    end

    function tests.GetFilteredData_AllPassFilters()
        local originalBosses = ns.BrowserCache.bosses
        local originalSearchIndex = ns.BrowserCache.searchIndex
        local originalSlotFilter = ns.browserState.slotFilter
        local originalSearchText = ns.browserState.searchText
        local originalEquipmentOnly = ns.browserState.equipmentOnlyFilter

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

        T.AreEqual(1, #result, "Should have 1 boss")
        T.AreEqual(2, #result[1].loot, "Should have 2 items")

        ns.BrowserCache.bosses = originalBosses
        ns.BrowserCache.searchIndex = originalSearchIndex
        ns.browserState.slotFilter = originalSlotFilter
        ns.browserState.searchText = originalSearchText
        ns.browserState.equipmentOnlyFilter = originalEquipmentOnly
    end

    function tests.GetFilteredData_SlotFilterApplied()
        local originalBosses = ns.BrowserCache.bosses
        local originalSearchIndex = ns.BrowserCache.searchIndex
        local originalSlotFilter = ns.browserState.slotFilter
        local originalSearchText = ns.browserState.searchText
        local originalEquipmentOnly = ns.browserState.equipmentOnlyFilter

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

        T.AreEqual(1, #result, "Should have 1 boss")
        T.AreEqual(1, #result[1].loot, "Should have 1 item after filter")
        T.AreEqual(100, result[1].loot[1].itemID, "Should be head item")

        ns.BrowserCache.bosses = originalBosses
        ns.BrowserCache.searchIndex = originalSearchIndex
        ns.browserState.slotFilter = originalSlotFilter
        ns.browserState.searchText = originalSearchText
        ns.browserState.equipmentOnlyFilter = originalEquipmentOnly
    end

    function tests.GetFilteredData_EquipmentOnlyFilter()
        local originalBosses = ns.BrowserCache.bosses
        local originalSearchIndex = ns.BrowserCache.searchIndex
        local originalSlotFilter = ns.browserState.slotFilter
        local originalSearchText = ns.browserState.searchText
        local originalEquipmentOnly = ns.browserState.equipmentOnlyFilter

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

        T.AreEqual(1, #result, "Should have 1 boss")
        T.AreEqual(1, #result[1].loot, "Should have 1 item after filter")
        T.AreEqual(100, result[1].loot[1].itemID, "Should be gear item")

        ns.BrowserCache.bosses = originalBosses
        ns.BrowserCache.searchIndex = originalSearchIndex
        ns.browserState.slotFilter = originalSlotFilter
        ns.browserState.searchText = originalSearchText
        ns.browserState.equipmentOnlyFilter = originalEquipmentOnly
    end

    function tests.GetFilteredData_NoMatchingItems()
        local originalBosses = ns.BrowserCache.bosses
        local originalSearchIndex = ns.BrowserCache.searchIndex
        local originalSlotFilter = ns.browserState.slotFilter
        local originalSearchText = ns.browserState.searchText
        local originalEquipmentOnly = ns.browserState.equipmentOnlyFilter

        ns.browserState.slotFilter = "INVTYPE_TRINKET"
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

        T.AreEqual(0, #result, "Boss should be excluded when no items pass filter")

        ns.BrowserCache.bosses = originalBosses
        ns.BrowserCache.searchIndex = originalSearchIndex
        ns.browserState.slotFilter = originalSlotFilter
        ns.browserState.searchText = originalSearchText
        ns.browserState.equipmentOnlyFilter = originalEquipmentOnly
    end

    ---------------------------------------------------------------------------
    -- EnsureBrowserStateValid Tests (multi-tier instance handling)
    ---------------------------------------------------------------------------

    function tests.EnsureBrowserStateValid_MultiTierInstance()
        local originalState = {
            expansion = ns.browserState.expansion,
            instanceType = ns.browserState.instanceType,
            selectedInstance = ns.browserState.selectedInstance,
        }
        local originalGetInstances = ns.GetInstancesForTier

        ns.browserState.expansion = 3
        ns.browserState.instanceType = "raid"
        ns.browserState.selectedInstance = 1278

        ns.GetInstancesForTier = function(self, tierID, isRaid)
            if tierID == 3 and isRaid then
                return {{id = 1278, name = "Khaz Algar"}, {id = 1302, name = "Manaforge Omega"}}
            end
            return {}
        end

        ns:EnsureBrowserStateValid()

        T.AreEqual(1278, ns.browserState.selectedInstance,
            "Expected instance 1278 to remain selected, got " .. tostring(ns.browserState.selectedInstance))

        ns.browserState.expansion = originalState.expansion
        ns.browserState.instanceType = originalState.instanceType
        ns.browserState.selectedInstance = originalState.selectedInstance
        ns.GetInstancesForTier = originalGetInstances
    end

    function tests.EnsureBrowserStateValid_InstanceNotInTier()
        local originalState = {
            expansion = ns.browserState.expansion,
            instanceType = ns.browserState.instanceType,
            selectedInstance = ns.browserState.selectedInstance,
        }
        local originalGetInstances = ns.GetInstancesForTier
        local originalGetFirst = ns.GetFirstInstanceForCurrentState

        ns.browserState.expansion = 11
        ns.browserState.instanceType = "raid"
        ns.browserState.selectedInstance = 1278

        ns.GetInstancesForTier = function(self, tierID, isRaid)
            if tierID == 11 and isRaid then
                return {{id = 999, name = "Dragonflight Raid"}}
            end
            return {}
        end

        ns.GetFirstInstanceForCurrentState = function(self, state)
            return 999
        end

        ns:EnsureBrowserStateValid()

        T.AreEqual(999, ns.browserState.selectedInstance,
            "Expected instance to be reset to 999, got " .. tostring(ns.browserState.selectedInstance))

        ns.browserState.expansion = originalState.expansion
        ns.browserState.instanceType = originalState.instanceType
        ns.browserState.selectedInstance = originalState.selectedInstance
        ns.GetInstancesForTier = originalGetInstances
        ns.GetFirstInstanceForCurrentState = originalGetFirst
    end

    ---------------------------------------------------------------------------
    -- Integration: EnsureBrowserStateValid auto-selects instance when nil
    ---------------------------------------------------------------------------

    function tests.Integration_EnsureValid_SetsInstanceWhenNil()
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

        T.AreEqual(1278, ns.browserState.selectedInstance,
            "Expected instance 1278, got " .. tostring(ns.browserState.selectedInstance))

        ns.browserState.expansion = originalState.expansion
        ns.browserState.instanceType = originalState.instanceType
        ns.browserState.selectedInstance = originalState.selectedInstance
        ns.browserState.selectedDifficultyID = originalState.selectedDifficultyID
        ns.browserState.selectedDifficultyIndex = originalState.selectedDifficultyIndex
        ns.GetFirstInstanceForCurrentState = originalGetFirst
        ns.GetInstancesForTier = originalGetInstances
        ns.BrowserCache.version = originalCacheVersion
    end

    ---------------------------------------------------------------------------
    -- Integration: RefreshLeftPanel does NOT mutate state
    ---------------------------------------------------------------------------

    function tests.Integration_RefreshLeftPanel_NoStateMutation()
        local originalState = {
            expansion = ns.browserState.expansion,
            instanceType = ns.browserState.instanceType,
            selectedInstance = ns.browserState.selectedInstance,
        }
        local originalGetInstances = ns.GetInstancesForTier

        ns.browserState.expansion = 3
        ns.browserState.instanceType = "raid"
        ns.browserState.selectedInstance = 1278

        ns.GetInstancesForTier = function(self, tierID, isRaid)
            return {{id = 1278, name = "Khaz Algar"}, {id = 1302, name = "Manaforge Omega"}}
        end

        local expBefore = ns.browserState.expansion
        local instBefore = ns.browserState.selectedInstance

        ns:RefreshLeftPanel()

        T.AreEqual(expBefore, ns.browserState.expansion,
            "RefreshLeftPanel mutated expansion: " .. tostring(ns.browserState.expansion))
        T.AreEqual(instBefore, ns.browserState.selectedInstance,
            "RefreshLeftPanel mutated selectedInstance: " .. tostring(ns.browserState.selectedInstance))

        ns.browserState.expansion = originalState.expansion
        ns.browserState.instanceType = originalState.instanceType
        ns.browserState.selectedInstance = originalState.selectedInstance
        ns.GetInstancesForTier = originalGetInstances
    end

    ---------------------------------------------------------------------------
    -- Integration: Tier switch auto-selects first instance when current is invalid
    ---------------------------------------------------------------------------

    function tests.Integration_TierSwitch_AutoSelectsFirstInstance()
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

        T.AreEqual(500, ns.browserState.selectedInstance,
            "Expected instance reset to 500, got " .. tostring(ns.browserState.selectedInstance))

        ns.browserState.expansion = originalState.expansion
        ns.browserState.instanceType = originalState.instanceType
        ns.browserState.selectedInstance = originalState.selectedInstance
        ns.browserState.selectedDifficultyID = originalState.selectedDifficultyID
        ns.browserState.selectedDifficultyIndex = originalState.selectedDifficultyIndex
        ns.GetFirstInstanceForCurrentState = originalGetFirst
        ns.GetInstancesForTier = originalGetInstances
        ns.BrowserCache.version = originalCacheVersion
    end

    ---------------------------------------------------------------------------
    -- Integration: Tier switch preserves valid instance
    ---------------------------------------------------------------------------

    function tests.Integration_TierSwitch_KeepsValidInstance()
        local originalState = {
            expansion = ns.browserState.expansion,
            instanceType = ns.browserState.instanceType,
            selectedInstance = ns.browserState.selectedInstance,
            selectedDifficultyID = ns.browserState.selectedDifficultyID,
            selectedDifficultyIndex = ns.browserState.selectedDifficultyIndex,
        }
        local originalGetInstances = ns.GetInstancesForTier
        local originalCacheVersion = ns.BrowserCache.version

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

        T.AreEqual(1278, ns.browserState.selectedInstance,
            "Expected instance 1278 preserved, got " .. tostring(ns.browserState.selectedInstance))

        ns.browserState.expansion = originalState.expansion
        ns.browserState.instanceType = originalState.instanceType
        ns.browserState.selectedInstance = originalState.selectedInstance
        ns.browserState.selectedDifficultyID = originalState.selectedDifficultyID
        ns.browserState.selectedDifficultyIndex = originalState.selectedDifficultyIndex
        ns.GetInstancesForTier = originalGetInstances
        ns.BrowserCache.version = originalCacheVersion
    end

    ---------------------------------------------------------------------------
    -- CacheInstanceData uses state.expansion (not _instanceInfo.tierID)
    ---------------------------------------------------------------------------

    function tests.CacheInstanceData_UsesStateExpansionAsTier()
        local originalState = {
            expansion = ns.browserState.expansion,
            instanceType = ns.browserState.instanceType,
            selectedInstance = ns.browserState.selectedInstance,
            selectedDifficultyID = ns.browserState.selectedDifficultyID,
            selectedDifficultyIndex = ns.browserState.selectedDifficultyIndex,
        }
        local originalGetInstances = ns.GetInstancesForTier
        local originalInstanceInfo = ns.Data._instanceInfo

        ns.browserState.expansion = 13
        ns.browserState.instanceType = "raid"
        ns.browserState.selectedInstance = 1278
        ns.browserState.selectedDifficultyID = 14
        ns.browserState.selectedDifficultyIndex = 1

        ns.Data._instanceInfo = {
            [1278] = { tierID = 11, name = "Khaz Algar" },
        }

        ns.GetInstancesForTier = function(self, tierID, isRaid)
            if tierID == 13 and isRaid then
                return {{id = 1278, name = "Khaz Algar"}}
            end
            return {}
        end

        ns:EnsureBrowserStateValid()

        T.AreEqual(13, ns.browserState.expansion,
            "Expected expansion=13 (UI tier), got " .. tostring(ns.browserState.expansion))
        T.AreEqual(1278, ns.browserState.selectedInstance,
            "Expected instance 1278 to remain selected, got " .. tostring(ns.browserState.selectedInstance))

        local correctTierForEJ = ns.browserState.expansion
        local wrongTierFromInfo = ns.Data._instanceInfo[1278].tierID
        T.IsTrue(correctTierForEJ ~= wrongTierFromInfo,
            "Test setup error: tiers should differ to prove the fix works")
        T.AreEqual(13, correctTierForEJ,
            "CacheInstanceData should use tier 13 (state.expansion), not " .. tostring(correctTierForEJ))

        ns.browserState.expansion = originalState.expansion
        ns.browserState.instanceType = originalState.instanceType
        ns.browserState.selectedInstance = originalState.selectedInstance
        ns.browserState.selectedDifficultyID = originalState.selectedDifficultyID
        ns.browserState.selectedDifficultyIndex = originalState.selectedDifficultyIndex
        ns.GetInstancesForTier = originalGetInstances
        ns.Data._instanceInfo = originalInstanceInfo
    end

    ---------------------------------------------------------------------------
    -- Integration: No double cache invalidation from RefreshLeftPanel
    ---------------------------------------------------------------------------

    function tests.Integration_NoCacheDoubleInvalidation()
        local originalState = {
            expansion = ns.browserState.expansion,
            instanceType = ns.browserState.instanceType,
            selectedInstance = ns.browserState.selectedInstance,
        }
        local originalGetInstances = ns.GetInstancesForTier
        local originalCacheVersion = ns.BrowserCache.version

        ns.browserState.expansion = 3
        ns.browserState.instanceType = "raid"
        ns.browserState.selectedInstance = 1278

        ns.GetInstancesForTier = function(self, tierID, isRaid)
            return {{id = 1278, name = "Khaz Algar"}}
        end

        local versionBefore = ns.BrowserCache.version

        ns:RefreshLeftPanel()

        T.AreEqual(versionBefore, ns.BrowserCache.version,
            "RefreshLeftPanel caused cache invalidation: version " ..
            versionBefore .. " -> " .. ns.BrowserCache.version)

        ns.browserState.expansion = originalState.expansion
        ns.browserState.instanceType = originalState.instanceType
        ns.browserState.selectedInstance = originalState.selectedInstance
        ns.GetInstancesForTier = originalGetInstances
        ns.BrowserCache.version = originalCacheVersion
    end

    ---------------------------------------------------------------------------
    -- NeedsEJRetry Tests (EJ class filter retry mechanism)
    ---------------------------------------------------------------------------

    function tests.NeedsEJRetry_NilFilterTypeWithClassFilter()
        local bosses = {
            { bossID = 1, name = "Boss", loot = {{ itemID = 100, filterType = nil }} },
        }
        local result = ns._test.NeedsEJRetry(bosses, 8, 0)
        T.IsTrue(result, "Nil filterType with active class filter should need retry")
    end

    function tests.NeedsEJRetry_ValidFilterType()
        local bosses = {
            { bossID = 1, name = "Boss", loot = {{ itemID = 100, filterType = 2 }} },
        }
        local result = ns._test.NeedsEJRetry(bosses, 8, 0)
        T.IsFalse(result, "Valid filterType should not need retry")
    end

    function tests.NeedsEJRetry_AllClasses()
        local bosses = {
            { bossID = 1, name = "Boss", loot = {{ itemID = 100, filterType = nil }} },
        }
        local result = ns._test.NeedsEJRetry(bosses, 0, 0)
        T.IsFalse(result, "classFilter=0 (All Classes) should not need retry")
    end

    function tests.NeedsEJRetry_MaxRetriesReached()
        local bosses = {
            { bossID = 1, name = "Boss", loot = {{ itemID = 100, filterType = nil }} },
        }
        local result = ns._test.NeedsEJRetry(bosses, 8, 1)
        T.IsFalse(result, "retryCount >= 1 should not retry")
    end

    function tests.NeedsEJRetry_EmptyBosses()
        local result = ns._test.NeedsEJRetry({}, 8, 0)
        T.IsFalse(result, "Empty bosses should not need retry")
    end

    function tests.NeedsEJRetry_NilBosses()
        local result = ns._test.NeedsEJRetry(nil, 8, 0)
        T.IsFalse(result, "Nil bosses should not need retry")
    end

    function tests.NeedsEJRetry_BossWithNoLoot()
        local bosses = {
            { bossID = 1, name = "Boss", loot = {} },
        }
        local result = ns._test.NeedsEJRetry(bosses, 8, 0)
        T.IsFalse(result, "Boss with empty loot should not need retry")
    end

    function tests.NeedsEJRetry_MixedFilterTypes()
        local bosses = {
            { bossID = 1, name = "Boss1", loot = {{ itemID = 100, filterType = 2 }} },
            { bossID = 2, name = "Boss2", loot = {{ itemID = 200, filterType = nil }} },
        }
        local result = ns._test.NeedsEJRetry(bosses, 8, 0)
        T.IsTrue(result, "Any boss with nil filterType on first item should need retry")
    end

    ---------------------------------------------------------------------------
    -- EnsureBrowserStateValid preserves difficulty through world boss transition
    ---------------------------------------------------------------------------

    function tests.EnsureBrowserStateValid_PreservesDifficultyForWorldBoss()
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

        ns.browserState.expansion = 3
        ns.browserState.instanceType = "raid"
        ns.browserState.selectedInstance = 1302
        ns.browserState.selectedDifficultyID = 15
        ns.browserState.selectedDifficultyIndex = 2
        ns.browserState._preservedDifficultyID = nil

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
        ns.GetInstanceInfo = function(self, instanceID)
            if instanceID == 1278 then
                return {shouldDisplayDifficulty = false}
            end
            return {shouldDisplayDifficulty = true}
        end

        -- Step 1: Switch to world boss
        ns.browserState.selectedInstance = 1278
        ns:EnsureBrowserStateValid()

        T.AreEqual(14, ns.browserState.selectedDifficultyID,
            "World boss should set difficultyID=14 for API, got " .. tostring(ns.browserState.selectedDifficultyID))
        T.AreEqual(15, ns.browserState._preservedDifficultyID,
            "World boss should preserve original difficultyID=15, got " .. tostring(ns.browserState._preservedDifficultyID))

        -- Step 2: Switch back to normal raid
        ns.browserState.selectedInstance = 1302
        ns:EnsureBrowserStateValid()

        T.AreEqual(15, ns.browserState.selectedDifficultyID,
            "After return from world boss, difficultyID should be 15, got " .. tostring(ns.browserState.selectedDifficultyID))
        T.AreEqual(2, ns.browserState.selectedDifficultyIndex,
            "After return from world boss, difficultyIndex should be 2, got " .. tostring(ns.browserState.selectedDifficultyIndex))
        T.IsTrue(ns.browserState._preservedDifficultyID == nil,
            "After return from world boss, _preservedDifficultyID should be nil, got " .. tostring(ns.browserState._preservedDifficultyID))

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

    ---------------------------------------------------------------------------
    -- World boss: repeated EnsureBrowserStateValid calls don't overwrite preserved
    ---------------------------------------------------------------------------

    function tests.WorldBossMultipleCallsNoOverwrite()
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

        -- First call
        ns:EnsureBrowserStateValid()
        T.AreEqual(15, ns.browserState._preservedDifficultyID,
            "First call should preserve 15, got " .. tostring(ns.browserState._preservedDifficultyID))
        T.AreEqual(14, ns.browserState.selectedDifficultyID,
            "First call should set API difficulty to 14, got " .. tostring(ns.browserState.selectedDifficultyID))

        -- Second call
        ns:EnsureBrowserStateValid()
        T.AreEqual(15, ns.browserState._preservedDifficultyID,
            "Second call should NOT overwrite preserved (still 15), got " .. tostring(ns.browserState._preservedDifficultyID))
        T.AreEqual(14, ns.browserState.selectedDifficultyID,
            "Second call should keep API difficulty at 14, got " .. tostring(ns.browserState.selectedDifficultyID))

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

    ---------------------------------------------------------------------------
    -- Switching between two world bosses preserves original difficulty
    ---------------------------------------------------------------------------

    function tests.SwitchBetweenWorldBosses()
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

        ns.browserState.expansion = 3
        ns.browserState.instanceType = "raid"
        ns.browserState.selectedInstance = 1278
        ns.browserState.selectedDifficultyID = 15
        ns.browserState.selectedDifficultyIndex = 2
        ns.browserState._preservedDifficultyID = nil

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
        T.AreEqual(15, ns.browserState._preservedDifficultyID,
            "First world boss should preserve 15, got " .. tostring(ns.browserState._preservedDifficultyID))

        -- Switch to second world boss
        ns.browserState.selectedInstance = 2000
        ns:EnsureBrowserStateValid()
        T.AreEqual(15, ns.browserState._preservedDifficultyID,
            "Second world boss should still preserve 15, got " .. tostring(ns.browserState._preservedDifficultyID))
        T.AreEqual(14, ns.browserState.selectedDifficultyID,
            "Second world boss should use API difficulty 14, got " .. tostring(ns.browserState.selectedDifficultyID))

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

    ---------------------------------------------------------------------------
    -- Preserved difficulty not available on new raid falls to SetDefaultDifficulty
    ---------------------------------------------------------------------------

    function tests.PreservedDifficultyNotAvailableOnNewRaid()
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

        ns.browserState.expansion = 3
        ns.browserState.instanceType = "raid"
        ns.browserState.selectedInstance = 1278
        ns.browserState.selectedDifficultyID = 14
        ns.browserState.selectedDifficultyIndex = 1
        ns.browserState._preservedDifficultyID = 16

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

        ns.browserState.selectedInstance = 1302
        ns:EnsureBrowserStateValid()

        T.IsTrue(ns.browserState._preservedDifficultyID == nil,
            "Preserved difficulty should be cleared after restore, got " .. tostring(ns.browserState._preservedDifficultyID))
        T.AreEqual(14, ns.browserState.selectedDifficultyID,
            "Should fall to default difficulty 14, got " .. tostring(ns.browserState.selectedDifficultyID))

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

    return tests
end
