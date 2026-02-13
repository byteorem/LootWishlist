-- Shared Wishlist Test Definitions
-- Tests for Wishlist CRUD operations and index maintenance
-- Usage: ns._sharedTests.Wishlist(T) returns a test table
--   T must implement: T.IsTrue(val, msg), T.IsFalse(val, msg), T.AreEqual(expected, actual, msg)

local _, ns = ...

ns._sharedTests = ns._sharedTests or {}

ns._sharedTests.Wishlist = function(T)
    local tests = {}

    -- Helper to reset DB state before each test
    local function SetupDB()
        ns.db = {
            wishlists = {
                ["Default"] = { items = {} },
            },
            settings = {
                soundEnabled = true,
                glowEnabled = true,
                chatAlertEnabled = true,
                alertSound = 8959,
                browserSize = 1,
                debugEnabled = false,
                collapsedGroups = {},
                minimapIcon = { hide = false },
            },
        }
        ns.charDB = {
            collected = {},
            checkedItems = {},
            activeWishlist = "Default",
            windowPositions = {},
        }
        ns.itemCache = {}
        -- Rebuild index after DB setup
        if ns.RebuildWishlistIndex then
            ns:RebuildWishlistIndex()
        end
    end

    ---------------------------------------------------------------------------
    -- CreateWishlist Tests
    ---------------------------------------------------------------------------

    function tests.CreateWishlist_Success()
        SetupDB()
        local ok = ns:CreateWishlist("Raid Gear")
        T.IsTrue(ok, "Expected CreateWishlist to succeed")
        T.IsTrue(ns.db.wishlists["Raid Gear"] ~= nil, "Wishlist should exist")
        T.IsTrue(ns.db.wishlists["Raid Gear"].items ~= nil, "Wishlist should have items table")
    end

    function tests.CreateWishlist_EmptyName()
        SetupDB()
        local ok, err = ns:CreateWishlist("")
        T.IsFalse(ok, "Expected CreateWishlist to fail for empty name")
    end

    function tests.CreateWishlist_Duplicate()
        SetupDB()
        ns:CreateWishlist("Raid Gear")
        local ok, err = ns:CreateWishlist("Raid Gear")
        T.IsFalse(ok, "Expected CreateWishlist to fail for duplicate name")
    end

    ---------------------------------------------------------------------------
    -- DeleteWishlist Tests
    ---------------------------------------------------------------------------

    function tests.DeleteWishlist_Success()
        SetupDB()
        ns:CreateWishlist("ToDelete")
        local ok = ns:DeleteWishlist("ToDelete")
        T.IsTrue(ok, "Expected DeleteWishlist to succeed")
        T.IsTrue(ns.db.wishlists["ToDelete"] == nil, "Wishlist should be removed")
    end

    function tests.DeleteWishlist_CannotDeleteDefault()
        SetupDB()
        local ok, err = ns:DeleteWishlist("Default")
        T.IsFalse(ok, "Expected DeleteWishlist to fail for Default")
    end

    function tests.DeleteWishlist_NonExistent()
        SetupDB()
        local ok, err = ns:DeleteWishlist("DoesNotExist")
        T.IsFalse(ok, "Expected DeleteWishlist to fail for nonexistent wishlist")
    end

    function tests.DeleteWishlist_SwitchesToDefault()
        SetupDB()
        ns:CreateWishlist("Active")
        ns:SetActiveWishlist("Active")
        ns:DeleteWishlist("Active")
        T.AreEqual("Default", ns:GetActiveWishlistName(), "Should switch to Default after deleting active")
    end

    function tests.DeleteWishlist_RemovesFromIndex()
        SetupDB()
        ns:CreateWishlist("IndexTest")
        ns:AddItemToWishlist(12345, "IndexTest", "Boss, Instance")
        T.IsTrue(ns:IsItemOnWishlist(12345), "Item should be on wishlist before delete")
        ns:DeleteWishlist("IndexTest")
        T.IsFalse(ns:IsItemOnWishlist(12345), "Item should not be on any wishlist after delete")
    end

    ---------------------------------------------------------------------------
    -- RenameWishlist Tests
    ---------------------------------------------------------------------------

    function tests.RenameWishlist_Success()
        SetupDB()
        ns:CreateWishlist("OldName")
        local ok = ns:RenameWishlist("OldName", "NewName")
        T.IsTrue(ok, "Expected RenameWishlist to succeed")
        T.IsTrue(ns.db.wishlists["NewName"] ~= nil, "New name should exist")
        T.IsTrue(ns.db.wishlists["OldName"] == nil, "Old name should be gone")
    end

    function tests.RenameWishlist_CannotRenameDefault()
        SetupDB()
        local ok, err = ns:RenameWishlist("Default", "NotDefault")
        T.IsFalse(ok, "Expected RenameWishlist to fail for Default")
    end

    function tests.RenameWishlist_UpdatesIndex()
        SetupDB()
        ns:CreateWishlist("OldName")
        ns:AddItemToWishlist(99999, "OldName", "Source")
        ns:RenameWishlist("OldName", "NewName")
        -- Item should still be on wishlist via new name
        T.IsTrue(ns:IsItemOnWishlist(99999), "Item should still be on wishlist after rename")
    end

    function tests.RenameWishlist_UpdatesActiveWishlist()
        SetupDB()
        ns:CreateWishlist("WillRename")
        ns:SetActiveWishlist("WillRename")
        ns:RenameWishlist("WillRename", "Renamed")
        T.AreEqual("Renamed", ns:GetActiveWishlistName(), "Active wishlist should update after rename")
    end

    ---------------------------------------------------------------------------
    -- AddItemToWishlist Tests
    ---------------------------------------------------------------------------

    function tests.AddItem_Success()
        SetupDB()
        local ok = ns:AddItemToWishlist(12345, nil, "Boss, Instance")
        T.IsTrue(ok, "Expected AddItemToWishlist to succeed")
        T.AreEqual(1, #ns:GetWishlistItems(), "Should have 1 item")
    end

    function tests.AddItem_UpdatesIndex()
        SetupDB()
        ns:AddItemToWishlist(12345, nil, "Boss, Instance")
        T.IsTrue(ns:IsItemOnWishlist(12345), "Item should be findable via index")
    end

    function tests.AddItem_DuplicatePrevented()
        SetupDB()
        ns:AddItemToWishlist(12345, nil, "Boss, Instance")
        local ok, err = ns:AddItemToWishlist(12345, nil, "Boss, Instance")
        T.IsFalse(ok, "Expected duplicate add to fail")
        T.AreEqual(1, #ns:GetWishlistItems(), "Should still have 1 item")
    end

    function tests.AddItem_DifferentSourceAllowed()
        SetupDB()
        ns:AddItemToWishlist(12345, nil, "Boss1, Instance1")
        local ok = ns:AddItemToWishlist(12345, nil, "Boss2, Instance2")
        T.IsTrue(ok, "Same item with different source should be allowed")
        T.AreEqual(2, #ns:GetWishlistItems(), "Should have 2 items")
    end

    function tests.AddItem_ToSpecificWishlist()
        SetupDB()
        ns:CreateWishlist("Custom")
        local ok = ns:AddItemToWishlist(12345, "Custom", "Source")
        T.IsTrue(ok, "Expected add to specific wishlist to succeed")
        T.AreEqual(1, #ns:GetWishlistItems("Custom"), "Custom wishlist should have 1 item")
        T.AreEqual(0, #ns:GetWishlistItems("Default"), "Default should be empty")
    end

    ---------------------------------------------------------------------------
    -- RemoveItemFromWishlist Tests
    ---------------------------------------------------------------------------

    function tests.RemoveItem_Success()
        SetupDB()
        ns:AddItemToWishlist(12345, nil, "Boss, Instance")
        local ok = ns:RemoveItemFromWishlist(12345, "Boss, Instance")
        T.IsTrue(ok, "Expected RemoveItemFromWishlist to succeed")
        T.AreEqual(0, #ns:GetWishlistItems(), "Should have 0 items")
    end

    function tests.RemoveItem_UpdatesIndex()
        SetupDB()
        ns:AddItemToWishlist(12345, nil, "Boss, Instance")
        ns:RemoveItemFromWishlist(12345, "Boss, Instance")
        T.IsFalse(ns:IsItemOnWishlist(12345), "Item should not be in index after removal")
    end

    function tests.RemoveItem_NonExistent()
        SetupDB()
        local ok, err = ns:RemoveItemFromWishlist(99999, "Source")
        T.IsFalse(ok, "Expected removal of nonexistent item to fail")
    end

    function tests.RemoveItem_KeepsOtherSources()
        SetupDB()
        ns:AddItemToWishlist(12345, nil, "Boss1, Instance1")
        ns:AddItemToWishlist(12345, nil, "Boss2, Instance2")
        ns:RemoveItemFromWishlist(12345, "Boss1, Instance1")
        T.IsTrue(ns:IsItemOnWishlist(12345), "Item should still be in index (other source remains)")
        T.AreEqual(1, #ns:GetWishlistItems(), "Should have 1 item remaining")
    end

    ---------------------------------------------------------------------------
    -- IsItemOnWishlist Tests
    ---------------------------------------------------------------------------

    function tests.IsItemOnWishlist_NotPresent()
        SetupDB()
        T.IsFalse(ns:IsItemOnWishlist(99999), "Should return false for item not on any wishlist")
    end

    function tests.IsItemOnWishlist_Present()
        SetupDB()
        ns:AddItemToWishlist(12345, nil, "Source")
        local found, name = ns:IsItemOnWishlist(12345)
        T.IsTrue(found, "Should find item on wishlist")
        T.AreEqual("Default", name, "Should return wishlist name")
    end

    function tests.IsItemOnWishlist_SpecificWishlist()
        SetupDB()
        ns:CreateWishlist("Custom")
        ns:AddItemToWishlist(12345, "Custom", "Source")
        T.IsTrue(ns:IsItemOnWishlist(12345, "Custom"), "Should find item on specific wishlist")
        T.IsFalse(ns:IsItemOnWishlist(12345, "Default"), "Should not find on Default")
    end

    ---------------------------------------------------------------------------
    -- GetWishlistProgress Tests
    ---------------------------------------------------------------------------

    function tests.GetWishlistProgress_Empty()
        SetupDB()
        local collected, total = ns:GetWishlistProgress()
        T.AreEqual(0, collected, "Collected should be 0")
        T.AreEqual(0, total, "Total should be 0")
    end

    function tests.GetWishlistProgress_WithItems()
        SetupDB()
        ns:AddItemToWishlist(100, nil, "S1")
        ns:AddItemToWishlist(200, nil, "S2")
        ns:AddItemToWishlist(300, nil, "S3")
        ns:MarkItemCollected(100)
        local collected, total = ns:GetWishlistProgress()
        T.AreEqual(1, collected, "Collected should be 1")
        T.AreEqual(3, total, "Total should be 3")
    end

    return tests
end
