-- LootWishlist Item Browser Unit Tests
-- Requires WoWUnit addon to be installed
-- Tests run automatically at game startup

local _, ns = ...

if not WoWUnit then return end

local Tests = WoWUnit('LootWishlist')

-------------------------------------------------------------------------------
-- Test Helper: Mock Enum.ItemSlotFilterType
-------------------------------------------------------------------------------

-- WoWUnit runs in a WoW environment, so Enum should be available
-- But we create local references for clarity
local FilterType = Enum.ItemSlotFilterType

-------------------------------------------------------------------------------
-- PassesSearchFilter Tests (addresses past false positive issue)
-------------------------------------------------------------------------------

function Tests:PassesSearchFilter_ExactMatch()
    local searchIndex = {}
    searchIndex["test"] = { ["123|456"] = true }

    local result = ns.BrowserFilter:PassesSearchFilter(123, 456, "test", searchIndex)
    WoWUnit.IsTrue(result)
end

function Tests:PassesSearchFilter_NoMatch()
    local searchIndex = {}
    searchIndex["test"] = { ["123|456"] = true }

    local result = ns.BrowserFilter:PassesSearchFilter(999, 999, "test", searchIndex)
    WoWUnit.IsFalse(result)
end

function Tests:PassesSearchFilter_EmptySearch()
    local result = ns.BrowserFilter:PassesSearchFilter(123, 456, "", {})
    WoWUnit.IsTrue(result)
end

function Tests:PassesSearchFilter_NilSearch()
    local result = ns.BrowserFilter:PassesSearchFilter(123, 456, nil, {})
    WoWUnit.IsTrue(result)
end

function Tests:PassesSearchFilter_CaseInsensitive()
    local searchIndex = {}
    searchIndex["test"] = { ["123|456"] = true }

    local result = ns.BrowserFilter:PassesSearchFilter(123, 456, "TEST", searchIndex)
    WoWUnit.IsTrue(result)
end

function Tests:PassesSearchFilter_PartialMatch()
    local searchIndex = {}
    searchIndex["tes"] = { ["123|456"] = true }
    searchIndex["test"] = { ["123|456"] = true }

    local result = ns.BrowserFilter:PassesSearchFilter(123, 456, "tes", searchIndex)
    WoWUnit.IsTrue(result)
end

function Tests:PassesSearchFilter_NoIndexEntryForSearch()
    local searchIndex = {}
    searchIndex["foo"] = { ["123|456"] = true }

    local result = ns.BrowserFilter:PassesSearchFilter(123, 456, "bar", searchIndex)
    WoWUnit.IsFalse(result)
end

-------------------------------------------------------------------------------
-- PassesSearchFilterLegacy Tests (substring matching bugs)
-------------------------------------------------------------------------------

function Tests:PassesSearchFilterLegacy_ExactMatch()
    local result = ns.BrowserFilter:PassesSearchFilterLegacy("Test Item", "Boss Name", "Test Item")
    WoWUnit.IsTrue(result)
end

function Tests:PassesSearchFilterLegacy_PartialMatch()
    local result = ns.BrowserFilter:PassesSearchFilterLegacy("Test Item", "Boss Name", "Test")
    WoWUnit.IsTrue(result)
end

function Tests:PassesSearchFilterLegacy_CaseInsensitive()
    local result = ns.BrowserFilter:PassesSearchFilterLegacy("Test Item", "Boss Name", "test")
    WoWUnit.IsTrue(result)
end

function Tests:PassesSearchFilterLegacy_MatchBossName()
    local result = ns.BrowserFilter:PassesSearchFilterLegacy("Test Item", "Boss Name", "Boss")
    WoWUnit.IsTrue(result)
end

function Tests:PassesSearchFilterLegacy_NoMatch()
    local result = ns.BrowserFilter:PassesSearchFilterLegacy("Test Item", "Boss Name", "xyz")
    WoWUnit.IsFalse(result)
end

function Tests:PassesSearchFilterLegacy_EmptySearch()
    local result = ns.BrowserFilter:PassesSearchFilterLegacy("Test Item", "Boss Name", "")
    WoWUnit.IsTrue(result)
end

function Tests:PassesSearchFilterLegacy_NilSearch()
    local result = ns.BrowserFilter:PassesSearchFilterLegacy("Test Item", "Boss Name", nil)
    WoWUnit.IsTrue(result)
end

function Tests:PassesSearchFilterLegacy_NilItemName()
    local result = ns.BrowserFilter:PassesSearchFilterLegacy(nil, "Boss Name", "Boss")
    WoWUnit.IsTrue(result)
end

function Tests:PassesSearchFilterLegacy_NilBothNames()
    local result = ns.BrowserFilter:PassesSearchFilterLegacy(nil, nil, "test")
    WoWUnit.IsFalse(result)
end

-------------------------------------------------------------------------------
-- PassesSlotFilter Tests (enum-based)
-------------------------------------------------------------------------------

function Tests:PassesSlotFilter_AllFilter()
    local result = ns.BrowserFilter:PassesSlotFilter(FilterType.Head, "ALL")
    WoWUnit.IsTrue(result)
end

function Tests:PassesSlotFilter_ExactMatch()
    local result = ns.BrowserFilter:PassesSlotFilter(FilterType.Head, "INVTYPE_HEAD")
    WoWUnit.IsTrue(result)
end

function Tests:PassesSlotFilter_NoMatch()
    local result = ns.BrowserFilter:PassesSlotFilter(FilterType.Head, "INVTYPE_CHEST")
    WoWUnit.IsFalse(result)
end

function Tests:PassesSlotFilter_WeaponMainHand()
    local result = ns.BrowserFilter:PassesSlotFilter(FilterType.MainHand, "WEAPON")
    WoWUnit.IsTrue(result)
end

function Tests:PassesSlotFilter_WeaponOffHand()
    local result = ns.BrowserFilter:PassesSlotFilter(FilterType.OffHand, "WEAPON")
    WoWUnit.IsTrue(result)
end

function Tests:PassesSlotFilter_NonWeaponForWeaponFilter()
    local result = ns.BrowserFilter:PassesSlotFilter(FilterType.Head, "WEAPON")
    WoWUnit.IsFalse(result)
end

function Tests:PassesSlotFilter_UnknownFilter()
    local result = ns.BrowserFilter:PassesSlotFilter(FilterType.Head, "UNKNOWN_FILTER")
    WoWUnit.IsTrue(result)  -- Unknown filters allow all
end

function Tests:PassesSlotFilter_NilFilterType()
    local result = ns.BrowserFilter:PassesSlotFilter(nil, "INVTYPE_HEAD")
    WoWUnit.IsFalse(result)
end

-------------------------------------------------------------------------------
-- PassesSlotFilterLegacy Tests (string-based fallback)
-------------------------------------------------------------------------------

function Tests:PassesSlotFilterLegacy_AllFilter()
    local result = ns.BrowserFilter:PassesSlotFilterLegacy("Head", "ALL")
    WoWUnit.IsTrue(result)
end

function Tests:PassesSlotFilterLegacy_ExactMatch()
    local result = ns.BrowserFilter:PassesSlotFilterLegacy("Head", "INVTYPE_HEAD")
    WoWUnit.IsTrue(result)
end

function Tests:PassesSlotFilterLegacy_WeaponOneHand()
    local result = ns.BrowserFilter:PassesSlotFilterLegacy("One-Hand Weapon", "WEAPON")
    WoWUnit.IsTrue(result)
end

function Tests:PassesSlotFilterLegacy_WeaponShield()
    local result = ns.BrowserFilter:PassesSlotFilterLegacy("Shield", "WEAPON")
    WoWUnit.IsTrue(result)
end

function Tests:PassesSlotFilterLegacy_WeaponOffHand()
    local result = ns.BrowserFilter:PassesSlotFilterLegacy("Off Hand", "WEAPON")
    WoWUnit.IsTrue(result)
end

function Tests:PassesSlotFilterLegacy_WeaponHeldInOff()
    local result = ns.BrowserFilter:PassesSlotFilterLegacy("Held In Off-hand", "WEAPON")
    WoWUnit.IsTrue(result)
end

function Tests:PassesSlotFilterLegacy_NonWeaponForWeaponFilter()
    local result = ns.BrowserFilter:PassesSlotFilterLegacy("Head", "WEAPON")
    WoWUnit.IsFalse(result)
end

-------------------------------------------------------------------------------
-- IsEquipment Tests (equipment filter)
-------------------------------------------------------------------------------

function Tests:IsEquipment_HeadSlot()
    local result = ns.BrowserFilter:IsEquipment(FilterType.Head, "")
    WoWUnit.IsTrue(result)
end

function Tests:IsEquipment_NeckSlot()
    local result = ns.BrowserFilter:IsEquipment(FilterType.Neck, "")
    WoWUnit.IsTrue(result)
end

function Tests:IsEquipment_TrinketSlot()
    local result = ns.BrowserFilter:IsEquipment(FilterType.Trinket, "")
    WoWUnit.IsTrue(result)
end

function Tests:IsEquipment_MainHandSlot()
    local result = ns.BrowserFilter:IsEquipment(FilterType.MainHand, "")
    WoWUnit.IsTrue(result)
end

function Tests:IsEquipment_OtherType()
    local result = ns.BrowserFilter:IsEquipment(FilterType.Other, "")
    WoWUnit.IsFalse(result)
end

function Tests:IsEquipment_NilWithSlotString()
    local result = ns.BrowserFilter:IsEquipment(nil, "Head")
    WoWUnit.IsTrue(result)
end

function Tests:IsEquipment_NilWithEmptySlot()
    local result = ns.BrowserFilter:IsEquipment(nil, "")
    WoWUnit.IsFalse(result)
end

function Tests:IsEquipment_NilWithNilSlot()
    local result = ns.BrowserFilter:IsEquipment(nil, nil)
    WoWUnit.IsFalse(result)
end

-------------------------------------------------------------------------------
-- IsCacheValid Tests (addresses loadingState stuck issue)
-------------------------------------------------------------------------------

function Tests:IsCacheValid_NotReadyState()
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
    WoWUnit.IsFalse(result)

    -- Restore original state
    ns.browserState.selectedInstance = originalState
    ns.BrowserCache.loadingState = originalCache.loadingState
    ns.BrowserCache.instanceID = originalCache.instanceID
    ns.BrowserCache.classFilter = originalCache.classFilter
    ns.BrowserCache.difficultyID = originalCache.difficultyID
    ns.BrowserCache.expansion = originalCache.expansion
end

function Tests:IsCacheValid_InstanceMismatch()
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
    WoWUnit.IsFalse(result)

    -- Restore original state
    ns.browserState.selectedInstance = originalState
    ns.BrowserCache.loadingState = originalCache.loadingState
    ns.BrowserCache.instanceID = originalCache.instanceID
end

-------------------------------------------------------------------------------
-- InvalidateCache Tests
-------------------------------------------------------------------------------

function Tests:InvalidateCache_ResetsState()
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

    WoWUnit.AreEqual("idle", ns.BrowserCache.loadingState)
    WoWUnit.IsTrue(ns.BrowserCache.instanceID == nil)
    WoWUnit.AreEqual(versionBefore + 1, ns.BrowserCache.version)

    -- Restore original state
    ns.BrowserCache.version = originalCache.version
    ns.BrowserCache.loadingState = originalCache.loadingState
    ns.BrowserCache.instanceID = originalCache.instanceID
end

-------------------------------------------------------------------------------
-- BuildSearchIndexEntry Tests
-------------------------------------------------------------------------------

function Tests:BuildSearchIndexEntry_SingleChar()
    local searchIndex = {}
    ns._test.BuildSearchIndexEntry(searchIndex, "123|456", "Test")

    WoWUnit.IsTrue(searchIndex["t"] ~= nil)
    WoWUnit.IsTrue(searchIndex["t"]["123|456"] == true)
end

function Tests:BuildSearchIndexEntry_MultipleChars()
    local searchIndex = {}
    ns._test.BuildSearchIndexEntry(searchIndex, "123|456", "Test")

    WoWUnit.IsTrue(searchIndex["t"] ~= nil)
    WoWUnit.IsTrue(searchIndex["te"] ~= nil)
    WoWUnit.IsTrue(searchIndex["tes"] ~= nil)
    WoWUnit.IsTrue(searchIndex["test"] ~= nil)
end

function Tests:BuildSearchIndexEntry_CaseInsensitive()
    local searchIndex = {}
    ns._test.BuildSearchIndexEntry(searchIndex, "123|456", "TEST")

    WoWUnit.IsTrue(searchIndex["t"] ~= nil)
    WoWUnit.IsTrue(searchIndex["test"] ~= nil)
end

function Tests:BuildSearchIndexEntry_MultipleItems()
    local searchIndex = {}
    ns._test.BuildSearchIndexEntry(searchIndex, "111|222", "Test")
    ns._test.BuildSearchIndexEntry(searchIndex, "333|444", "Testing")

    WoWUnit.IsTrue(searchIndex["test"]["111|222"] == true)
    WoWUnit.IsTrue(searchIndex["test"]["333|444"] == true)
end

function Tests:BuildSearchIndexEntry_MaxLength()
    local searchIndex = {}
    local longName = "ThisIsAVeryLongItemNameThatExceedsLimit"
    ns._test.BuildSearchIndexEntry(searchIndex, "123|456", longName)

    -- Should only index up to MAX_NGRAM_PREFIX_LENGTH (20)
    local maxLen = ns.Constants.MAX_NGRAM_PREFIX_LENGTH
    local expectedPrefix = longName:lower():sub(1, maxLen)
    WoWUnit.IsTrue(searchIndex[expectedPrefix] ~= nil)

    -- Should NOT have longer prefix
    local longerPrefix = longName:lower():sub(1, maxLen + 1)
    WoWUnit.IsTrue(searchIndex[longerPrefix] == nil)
end

-------------------------------------------------------------------------------
-- GetFilteredData Tests
-------------------------------------------------------------------------------

function Tests:GetFilteredData_EmptyCache()
    -- Save original state
    local originalBosses = ns.BrowserCache.bosses

    -- Setup test conditions
    ns.BrowserCache.bosses = {}

    local result = ns.BrowserFilter:GetFilteredData()

    WoWUnit.AreEqual(0, #result)

    -- Restore original state
    ns.BrowserCache.bosses = originalBosses
end

function Tests:GetFilteredData_AllPassFilters()
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

    WoWUnit.AreEqual(1, #result)
    WoWUnit.AreEqual(2, #result[1].loot)

    -- Restore original state
    ns.BrowserCache.bosses = originalBosses
    ns.BrowserCache.searchIndex = originalSearchIndex
    ns.browserState.slotFilter = originalSlotFilter
    ns.browserState.searchText = originalSearchText
    ns.browserState.equipmentOnlyFilter = originalEquipmentOnly
end

function Tests:GetFilteredData_SlotFilterApplied()
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

    WoWUnit.AreEqual(1, #result)
    WoWUnit.AreEqual(1, #result[1].loot)
    WoWUnit.AreEqual(100, result[1].loot[1].itemID)

    -- Restore original state
    ns.BrowserCache.bosses = originalBosses
    ns.BrowserCache.searchIndex = originalSearchIndex
    ns.browserState.slotFilter = originalSlotFilter
    ns.browserState.searchText = originalSearchText
    ns.browserState.equipmentOnlyFilter = originalEquipmentOnly
end

function Tests:GetFilteredData_EquipmentOnlyFilter()
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

    WoWUnit.AreEqual(1, #result)
    WoWUnit.AreEqual(1, #result[1].loot)
    WoWUnit.AreEqual(100, result[1].loot[1].itemID)

    -- Restore original state
    ns.BrowserCache.bosses = originalBosses
    ns.BrowserCache.searchIndex = originalSearchIndex
    ns.browserState.slotFilter = originalSlotFilter
    ns.browserState.searchText = originalSearchText
    ns.browserState.equipmentOnlyFilter = originalEquipmentOnly
end

function Tests:GetFilteredData_NoMatchingItems()
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

    WoWUnit.AreEqual(0, #result)  -- Boss excluded since no items pass filter

    -- Restore original state
    ns.BrowserCache.bosses = originalBosses
    ns.BrowserCache.searchIndex = originalSearchIndex
    ns.browserState.slotFilter = originalSlotFilter
    ns.browserState.searchText = originalSearchText
    ns.browserState.equipmentOnlyFilter = originalEquipmentOnly
end
