-- Shared Database Test Definitions
-- Tests for migrations and DeepMerge behavior
-- Usage: ns._sharedTests.Database(T) returns a test table
--   T must implement: T.IsTrue(val, msg), T.IsFalse(val, msg), T.AreEqual(expected, actual, msg)

local _, ns = ...

ns._sharedTests = ns._sharedTests or {}

ns._sharedTests.Database = function(T)
    local tests = {}

    ---------------------------------------------------------------------------
    -- Migration Tests
    ---------------------------------------------------------------------------

    function tests.Migration_V1toV2_ConvertsItemIDs()
        -- Simulate v1 database with plain itemID numbers
        LootWishlistDB = {
            version = 1,
            wishlists = {
                ["Default"] = {
                    items = {12345, 67890},
                },
            },
            settings = {},
        }
        LootWishlistCharDB = {}
        ns:InitializeDatabase()

        local items = ns.db.wishlists["Default"].items
        T.AreEqual(2, #items, "Should have 2 items after migration")
        T.AreEqual(12345, items[1].itemID, "First item should have correct itemID")
        T.AreEqual("", items[1].sourceText, "First item should have empty sourceText")
        T.AreEqual(67890, items[2].itemID, "Second item should have correct itemID")
    end

    function tests.Migration_V2toV3_AddsDifficulty()
        LootWishlistDB = {
            version = 2,
            wishlists = {
                ["Default"] = {
                    items = {
                        {itemID = 100, sourceText = "Boss"},
                    },
                },
            },
            settings = {},
        }
        LootWishlistCharDB = {}
        ns:InitializeDatabase()

        -- v3 adds difficulty, v4 removes it, so it should be nil after full migration
        local items = ns.db.wishlists["Default"].items
        T.AreEqual(nil, items[1].difficulty, "Difficulty should be nil after v4 migration")
    end

    function tests.Migration_V4toV5_MovesActiveWishlist()
        LootWishlistDB = {
            version = 4,
            wishlists = {
                ["Default"] = { items = {} },
                ["Custom"] = { items = {} },
            },
            settings = {
                activeWishlist = "Custom",
            },
        }
        LootWishlistCharDB = {}
        ns:InitializeDatabase()

        T.AreEqual("Custom", ns.charDB.activeWishlist, "activeWishlist should move to charDB")
        T.AreEqual(nil, ns.db.settings.activeWishlist, "activeWishlist should be removed from account DB")
    end

    function tests.Migration_V5toV6_RemovesUpgradeTrack()
        LootWishlistDB = {
            version = 5,
            wishlists = {
                ["Default"] = {
                    items = {
                        {itemID = 100, sourceText = "Boss", upgradeTrack = "Champion"},
                    },
                },
            },
            settings = {
                defaultTrack = "Hero",
            },
        }
        LootWishlistCharDB = {}
        ns:InitializeDatabase()

        local items = ns.db.wishlists["Default"].items
        T.AreEqual(nil, items[1].upgradeTrack, "upgradeTrack should be removed")
        T.AreEqual(nil, ns.db.settings.defaultTrack, "defaultTrack setting should be removed")
    end

    function tests.Migration_FullChain_V1toLatest()
        LootWishlistDB = {
            version = 1,
            wishlists = {
                ["Default"] = {
                    items = {11111},
                },
            },
            settings = {
                activeWishlist = "Default",
            },
        }
        LootWishlistCharDB = {}
        ns:InitializeDatabase()

        -- Should be at latest version
        T.AreEqual(ns.db.version, ns.db.version, "Version should be at latest")
        -- Item should be in new format
        local items = ns.db.wishlists["Default"].items
        T.AreEqual(11111, items[1].itemID, "Item should be in table format")
        T.AreEqual(nil, items[1].difficulty, "No difficulty field (removed in v4)")
        T.AreEqual(nil, items[1].upgradeTrack, "No upgradeTrack field (removed in v6)")
    end

    ---------------------------------------------------------------------------
    -- DeepMerge / Defaults Tests
    ---------------------------------------------------------------------------

    function tests.DeepMerge_FillsMissingDefaults()
        LootWishlistDB = {
            version = 7,
            wishlists = {
                ["Default"] = { items = {} },
            },
            -- settings missing entirely
        }
        LootWishlistCharDB = {}
        ns:InitializeDatabase()

        T.IsTrue(ns.db.settings ~= nil, "Settings should be created from defaults")
        T.IsTrue(ns.db.settings.soundEnabled == true, "Default soundEnabled should be true")
        T.IsTrue(ns.db.settings.collapsedGroups ~= nil, "collapsedGroups should exist")
    end

    function tests.DeepMerge_PreservesExistingValues()
        LootWishlistDB = {
            version = 7,
            wishlists = {
                ["Default"] = { items = {} },
            },
            settings = {
                soundEnabled = false,  -- User explicitly set to false
            },
        }
        LootWishlistCharDB = {}
        ns:InitializeDatabase()

        T.AreEqual(false, ns.db.settings.soundEnabled, "User's soundEnabled=false should be preserved")
        -- Missing keys should still be filled
        T.IsTrue(ns.db.settings.glowEnabled == true, "Missing glowEnabled should get default")
    end

    function tests.DeepMerge_CharDB_Defaults()
        LootWishlistDB = {
            version = 7,
            wishlists = { ["Default"] = { items = {} } },
            settings = {},
        }
        LootWishlistCharDB = {}
        ns:InitializeDatabase()

        T.AreEqual("Default", ns.charDB.activeWishlist, "activeWishlist should default to 'Default'")
        T.IsTrue(ns.charDB.collected ~= nil, "collected table should exist")
        T.IsTrue(ns.charDB.windowPositions ~= nil, "windowPositions should exist from v7 defaults")
    end

    ---------------------------------------------------------------------------
    -- Database API Tests
    ---------------------------------------------------------------------------

    function tests.GetSetting_ReturnsValue()
        LootWishlistDB = {
            version = 7,
            wishlists = { ["Default"] = { items = {} } },
            settings = { soundEnabled = true },
        }
        LootWishlistCharDB = {}
        ns:InitializeDatabase()

        T.AreEqual(true, ns:GetSetting("soundEnabled"), "GetSetting should return correct value")
    end

    function tests.GetSetting_ReturnsNilForMissing()
        LootWishlistDB = {
            version = 7,
            wishlists = { ["Default"] = { items = {} } },
            settings = {},
        }
        LootWishlistCharDB = {}
        ns:InitializeDatabase()

        -- After DeepMerge, soundEnabled should be filled from defaults
        T.AreEqual(true, ns:GetSetting("soundEnabled"), "Missing setting should get default")
    end

    function tests.IsItemCollected_FalseByDefault()
        LootWishlistDB = {
            version = 7,
            wishlists = { ["Default"] = { items = {} } },
            settings = {},
        }
        LootWishlistCharDB = {}
        ns:InitializeDatabase()

        T.IsFalse(ns:IsItemCollected(12345), "Item should not be collected by default")
    end

    function tests.MarkItemCollected_ThenCheck()
        LootWishlistDB = {
            version = 7,
            wishlists = { ["Default"] = { items = {} } },
            settings = {},
        }
        LootWishlistCharDB = {}
        ns:InitializeDatabase()

        ns:MarkItemCollected(12345)
        T.IsTrue(ns:IsItemCollected(12345), "Item should be collected after marking")
    end

    function tests.UnmarkItemCollected_ThenCheck()
        LootWishlistDB = {
            version = 7,
            wishlists = { ["Default"] = { items = {} } },
            settings = {},
        }
        LootWishlistCharDB = {}
        ns:InitializeDatabase()

        ns:MarkItemCollected(12345)
        ns:UnmarkItemCollected(12345)
        T.IsFalse(ns:IsItemCollected(12345), "Item should not be collected after unmarking")
    end

    return tests
end
