-- Events Tests
-- Verifies CHAT_MSG_LOOT handler removal and loot detection path

local _, ns = ...

ns._sharedTests = ns._sharedTests or {}

ns._sharedTests["Events"] = function(T)
    return {
        ChatMsgLootHandlerRemoved = function()
            T.IsTrue(ns.OnChatMsgLoot == nil, "OnChatMsgLoot should not exist (SecretValue crash fix)")
        end,

        LootReadyHandlerExists = function()
            T.IsTrue(ns.OnLootReady ~= nil, "OnLootReady handler should exist")
        end,

        LootOpenedHandlerExists = function()
            T.IsTrue(ns.OnLootOpened ~= nil, "OnLootOpened handler should exist")
        end,
    }
end
