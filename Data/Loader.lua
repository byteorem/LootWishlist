-- LootWishlist Data Loader
-- Lazy decompression of static data using C_EncodingUtil

local _, ns = ...

-- Initialize Data namespace
ns.Data = ns.Data or {}

-- Lazy loading via metatable
-- Data is decompressed from ns.CompressedData on first access
setmetatable(ns.Data, {
    __index = function(self, key)
        local compressed = ns.CompressedData and ns.CompressedData[key]
        if not compressed then
            return nil
        end

        -- Decompress: Base64 decode -> zlib decompress -> JSON parse
        local decoded = C_EncodingUtil.DecodeBase64(compressed)
        if not decoded then
            print("|cffff0000LootWishlist: Failed to decode " .. key .. "|r")
            return nil
        end

        local decompressed = C_EncodingUtil.DecompressString(decoded, Enum.CompressionMethod.Deflate)
        if not decompressed then
            print("|cffff0000LootWishlist: Failed to decompress " .. key .. "|r")
            return nil
        end

        local data = C_EncodingUtil.DeserializeJSON(decompressed)
        if not data then
            print("|cffff0000LootWishlist: Failed to parse JSON for " .. key .. "|r")
            return nil
        end

        -- Cache the decompressed data
        rawset(self, key, data)

        -- Free compressed data to save memory
        ns.CompressedData[key] = nil

        return data
    end
})

-------------------------------------------------------------------------------
-- Data Access Helpers
-------------------------------------------------------------------------------

-- Get all tiers sorted by order (newest first)
function ns:GetTiers()
    local tiers = ns.Data.Tiers
    if not tiers then return {} end

    local sorted = {}
    for id, data in pairs(tiers) do
        table.insert(sorted, {
            id = tonumber(id),
            name = data.name,
            order = data.order,
        })
    end

    -- Sort newest first (higher order = newer)
    table.sort(sorted, function(a, b) return a.order > b.order end)
    return sorted
end

-- Get instances for a specific tier
function ns:GetInstancesForTier(tierID, isRaid)
    local instances = ns.Data.Instances
    if not instances then return {} end

    local result = {}
    for id, data in pairs(instances) do
        if data.tierID == tierID and data.isRaid == isRaid then
            table.insert(result, {
                id = tonumber(id),
                name = data.name,
                order = data.order,
            })
        end
    end

    -- Sort by order (ascending)
    table.sort(result, function(a, b) return a.order < b.order end)
    return result
end

-- Get all instances (for searching across tiers)
function ns:GetAllInstances()
    local instances = ns.Data.Instances
    if not instances then return {} end

    local result = {}
    for id, data in pairs(instances) do
        result[tonumber(id)] = {
            name = data.name,
            tierID = data.tierID,
            isRaid = data.isRaid,
            order = data.order,
        }
    end
    return result
end

-- Get valid difficulties for an instance
function ns:GetDifficultiesForInstance(instanceID)
    local instanceDiffs = ns.Data.InstanceDifficulties
    local difficulties = ns.Data.Difficulties

    if not instanceDiffs or not difficulties then
        return {}
    end

    local diffIDs = instanceDiffs[tostring(instanceID)]
    if not diffIDs then
        -- Fallback: return empty (instance may use defaults)
        return {}
    end

    local result = {}
    for _, diffID in ipairs(diffIDs) do
        local diff = difficulties[tostring(diffID)]
        if diff then
            table.insert(result, {
                id = diffID,
                name = diff.name,
                type = diff.type,
                track = diff.track,
            })
        end
    end

    return result
end

-- Get all difficulties (for reference)
function ns:GetAllDifficulties()
    local difficulties = ns.Data.Difficulties
    if not difficulties then return {} end

    local result = {}
    for id, data in pairs(difficulties) do
        result[tonumber(id)] = {
            name = data.name,
            type = data.type,
            track = data.track,
        }
    end
    return result
end

-- Get encounters for an instance
function ns:GetEncountersForInstance(instanceID)
    local encounters = ns.Data.Encounters
    if not encounters then return {} end

    local result = {}
    for id, data in pairs(encounters) do
        if data.instanceID == instanceID then
            table.insert(result, {
                id = tonumber(id),
                name = data.name,
                order = data.order,
            })
        end
    end

    -- Sort by order (ascending)
    table.sort(result, function(a, b) return a.order < b.order end)
    return result
end

-- Get loot item IDs for an encounter
function ns:GetLootForEncounter(encounterID)
    local encounterLoot = ns.Data.EncounterLoot
    if not encounterLoot then return {} end

    return encounterLoot[tostring(encounterID)] or {}
end

-- Get instance info by ID
function ns:GetInstanceInfo(instanceID)
    local instances = ns.Data.Instances
    if not instances then return nil end

    local data = instances[tostring(instanceID)]
    if not data then return nil end

    return {
        id = instanceID,
        name = data.name,
        tierID = data.tierID,
        isRaid = data.isRaid,
        order = data.order,
    }
end

-- Get encounter info by ID
function ns:GetEncounterInfo(encounterID)
    local encounters = ns.Data.Encounters
    if not encounters then return nil end

    local data = encounters[tostring(encounterID)]
    if not data then return nil end

    return {
        id = encounterID,
        name = data.name,
        instanceID = data.instanceID,
        order = data.order,
    }
end
