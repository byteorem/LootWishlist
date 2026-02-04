-- LootWishlist Data Loader
-- Runtime EJ API integration with lazy caching

local _, ns = ...

-- Initialize Data namespace with lazy caches
ns.Data = {
    _tiers = nil,                -- Lazy: [{id, name, order}]
    _tierInstances = {},         -- Lazy: [tierID][isRaid] = [{id, name, order}]
    _instanceInfo = {},          -- Lazy: [instanceID] = {id, name, tierID, isRaid, order}
    _instanceEncounters = {},    -- Lazy: [instanceID] = [{id, name, order}]
    _currentSeasonInstances = nil, -- Lazy: {raids=[], dungeons=[]}
}

-------------------------------------------------------------------------------
-- Hardcoded Difficulty Mappings (IDs are stable across patches)
-------------------------------------------------------------------------------

local DUNGEON_DIFFICULTIES = {
    {id = 1, name = "Normal", type = "dungeon"},
    {id = 2, name = "Heroic", type = "dungeon"},
    {id = 23, name = "Mythic", type = "dungeon"},
    {id = 8, name = "Mythic Keystone", type = "dungeon"},
}

local RAID_DIFFICULTIES = {
    {id = 17, name = "Looking For Raid", type = "raid"},
    {id = 14, name = "Normal", type = "raid"},
    {id = 15, name = "Heroic", type = "raid"},
    {id = 16, name = "Mythic", type = "raid"},
}

local ALL_DIFFICULTIES = {}
for _, diff in ipairs(DUNGEON_DIFFICULTIES) do
    ALL_DIFFICULTIES[diff.id] = {name = diff.name, type = diff.type}
end
for _, diff in ipairs(RAID_DIFFICULTIES) do
    ALL_DIFFICULTIES[diff.id] = {name = diff.name, type = diff.type}
end

-------------------------------------------------------------------------------
-- EJ API Helpers
-------------------------------------------------------------------------------

-- Save and restore EJ state to avoid side effects
local function WithEJState(func)
    local savedTier = EJ_GetCurrentTier()
    local result = func()
    if savedTier then
        EJ_SelectTier(savedTier)
    end
    return result
end

-------------------------------------------------------------------------------
-- Data Access Functions
-------------------------------------------------------------------------------

-- Get all tiers sorted by order (newest first)
function ns:GetTiers()
    if ns.Data._tiers then
        return ns.Data._tiers
    end

    local tiers = {}
    local numTiers = EJ_GetNumTiers()

    for tierIndex = 1, numTiers do
        local tierName = EJ_GetTierInfo(tierIndex)
        if tierName then
            table.insert(tiers, {
                id = tierIndex,
                name = tierName,
                order = tierIndex, -- Higher index = newer expansion
            })
        end
    end

    -- Sort newest first (higher order = newer)
    table.sort(tiers, function(a, b) return a.order > b.order end)

    ns.Data._tiers = tiers
    return tiers
end

-- Get instances for a specific tier
function ns:GetInstancesForTier(tierID, isRaid)
    -- Check cache
    local cacheKey = isRaid and "raid" or "dungeon"
    if ns.Data._tierInstances[tierID] and ns.Data._tierInstances[tierID][cacheKey] then
        return ns.Data._tierInstances[tierID][cacheKey]
    end

    local instances = {}

    WithEJState(function()
        EJ_SelectTier(tierID)

        local index = 1
        while true do
            local instanceID, instanceName, _, _, _, _, _, _, order = EJ_GetInstanceByIndex(index, isRaid)
            if not instanceID then break end

            table.insert(instances, {
                id = instanceID,
                name = instanceName,
                order = order or index,
            })

            -- Cache instance info
            ns.Data._instanceInfo[instanceID] = {
                id = instanceID,
                name = instanceName,
                tierID = tierID,
                isRaid = isRaid,
                order = order or index,
            }

            index = index + 1
        end
    end)

    -- Sort by order (ascending)
    table.sort(instances, function(a, b) return a.order < b.order end)

    -- Cache results
    ns.Data._tierInstances[tierID] = ns.Data._tierInstances[tierID] or {}
    ns.Data._tierInstances[tierID][cacheKey] = instances

    return instances
end

-- Get all instances (for searching across tiers)
function ns:GetAllInstances()
    -- Ensure all tiers are loaded
    local tiers = ns:GetTiers()
    for _, tier in ipairs(tiers) do
        ns:GetInstancesForTier(tier.id, false) -- Dungeons
        ns:GetInstancesForTier(tier.id, true)  -- Raids
    end

    -- Return cached instance info
    local result = {}
    for instanceID, info in pairs(ns.Data._instanceInfo) do
        result[instanceID] = {
            name = info.name,
            tierID = info.tierID,
            isRaid = info.isRaid,
            order = info.order,
        }
    end
    return result
end

-- Get instance info by ID
function ns:GetInstanceInfo(instanceID)
    -- Check cache first
    if ns.Data._instanceInfo[instanceID] then
        return ns.Data._instanceInfo[instanceID]
    end

    -- Try to get from EJ API directly
    local savedInstance = EJ_GetCurrentInstance and EJ_GetCurrentInstance()

    EJ_SelectInstance(instanceID)
    local name, _, _, _, _, _, dungeonAreaMapID = EJ_GetInstanceInfo()

    -- Restore previous state
    if savedInstance and savedInstance > 0 then
        EJ_SelectInstance(savedInstance)
    end

    if not name then return nil end

    -- We don't know tier/isRaid without searching, but this is rarely called standalone
    local info = {
        id = instanceID,
        name = name,
        tierID = nil,
        isRaid = nil,
        order = nil,
    }

    -- Try to find in cache from tier loading
    ns.Data._instanceInfo[instanceID] = info
    return info
end

-- Get valid difficulties for an instance
function ns:GetDifficultiesForInstance(instanceID)
    local info = ns:GetInstanceInfo(instanceID)
    if not info then return {} end

    -- Determine if raid or dungeon based on cached info or EJ query
    local isRaid = info.isRaid

    -- If we don't have isRaid cached, check if it's in raid tier instances
    if isRaid == nil then
        -- Fallback: check all tiers for this instance
        local tiers = ns:GetTiers()
        for _, tier in ipairs(tiers) do
            local raids = ns:GetInstancesForTier(tier.id, true)
            for _, inst in ipairs(raids) do
                if inst.id == instanceID then
                    isRaid = true
                    break
                end
            end
            if isRaid then break end
        end
        if isRaid == nil then isRaid = false end
    end

    return isRaid and RAID_DIFFICULTIES or DUNGEON_DIFFICULTIES
end

-- Get all difficulties (for reference)
function ns:GetAllDifficulties()
    return ALL_DIFFICULTIES
end

-- Get encounters for an instance
function ns:GetEncountersForInstance(instanceID)
    -- Check cache
    if ns.Data._instanceEncounters[instanceID] then
        return ns.Data._instanceEncounters[instanceID]
    end

    local encounters = {}
    local savedInstance = EJ_GetCurrentInstance and EJ_GetCurrentInstance()

    EJ_SelectInstance(instanceID)

    local index = 1
    while true do
        local encounterName, _, encounterID = EJ_GetEncounterInfoByIndex(index)
        if not encounterID then break end

        table.insert(encounters, {
            id = encounterID,
            name = encounterName,
            order = index,
        })

        index = index + 1
    end

    -- Restore previous state
    if savedInstance and savedInstance > 0 then
        EJ_SelectInstance(savedInstance)
    end

    -- Sort by order (ascending) - should already be in order
    table.sort(encounters, function(a, b) return a.order < b.order end)

    -- Cache results
    ns.Data._instanceEncounters[instanceID] = encounters
    return encounters
end

-- Get current season instance IDs
function ns:GetCurrentSeasonInstances()
    if ns.Data._currentSeasonInstances then
        return ns.Data._currentSeasonInstances
    end

    local result = {
        raids = {},
        dungeons = {},
    }

    -- Get M+ dungeons from C_ChallengeMode
    if C_ChallengeMode and C_ChallengeMode.GetMapTable then
        local mapIDs = C_ChallengeMode.GetMapTable()
        if mapIDs then
            for _, mapID in ipairs(mapIDs) do
                -- Convert challenge map ID to instance ID
                if C_EncounterJournal and C_EncounterJournal.GetInstanceForGameMap then
                    local instanceID = C_EncounterJournal.GetInstanceForGameMap(mapID)
                    if instanceID and instanceID > 0 then
                        table.insert(result.dungeons, instanceID)
                    end
                end
            end
        end
    end

    -- Get current raid tier (most recent tier with raids)
    local tiers = ns:GetTiers()
    for _, tier in ipairs(tiers) do
        local raids = ns:GetInstancesForTier(tier.id, true)
        if #raids > 0 then
            for _, raid in ipairs(raids) do
                table.insert(result.raids, raid.id)
            end
            break -- Only get the newest tier with raids
        end
    end

    ns.Data._currentSeasonInstances = result
    return result
end

-------------------------------------------------------------------------------
-- Cache Invalidation (for testing/debug)
-------------------------------------------------------------------------------

function ns:InvalidateDataCache()
    ns.Data._tiers = nil
    ns.Data._tierInstances = {}
    ns.Data._instanceInfo = {}
    ns.Data._instanceEncounters = {}
    ns.Data._currentSeasonInstances = nil
end
