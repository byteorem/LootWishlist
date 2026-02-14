-- LootWishlist Data Loader
-- Static data lookups from Data/StaticData.lua with one-time EJ tier index resolution

local _, ns = ...

-- Initialize Data namespace
ns.Data = {
    _instanceInfo = {},          -- [instanceID] = {id, name, tierID, isRaid, shouldDisplayDifficulty}
    _tierIndexResolved = false,  -- One-time flag for EJ tier index resolution
}

-------------------------------------------------------------------------------
-- EJ Addon Loading
-- The EJ system requires Blizzard_EncounterJournal to be loaded for item data.
-- Without it, EJ_GetNumLoot works but C_EncounterJournal.GetLootInfoByIndex returns nil.
-------------------------------------------------------------------------------

local _ejAddonLoaded = false

function ns.Data:EnsureEJLoaded()
    if _ejAddonLoaded then return true end

    if C_AddOns.IsAddOnLoaded("Blizzard_EncounterJournal") then
        _ejAddonLoaded = true
        return true
    end

    local loaded, reason = C_AddOns.LoadAddOn("Blizzard_EncounterJournal")
    if loaded then
        _ejAddonLoaded = true
        return true
    end

    return false, reason
end

-------------------------------------------------------------------------------
-- EJ Event Suppression
-- Prevents Adventure Journal from reacting to programmatic EJ state changes
-- (Best practice from AtlasLoot, RCLootCouncil2, InspectEquip)
-------------------------------------------------------------------------------

local _ejSuppressDepth = 0
local _ejSavedHandler = nil

function ns.Data:SuppressEJEvents()
    _ejSuppressDepth = _ejSuppressDepth + 1
    if _ejSuppressDepth > 1 then return end  -- Already suppressed

    if EncounterJournal then
        _ejSavedHandler = EncounterJournal:GetScript("OnEvent")
        EncounterJournal:SetScript("OnEvent", nil)
    end
end

function ns.Data:RestoreEJEvents()
    _ejSuppressDepth = _ejSuppressDepth - 1
    if _ejSuppressDepth > 0 then return end  -- Still nested
    _ejSuppressDepth = 0  -- Clamp to 0 (defensive)

    if EncounterJournal and _ejSavedHandler then
        EncounterJournal:SetScript("OnEvent", _ejSavedHandler)
    end
    _ejSavedHandler = nil
end

-------------------------------------------------------------------------------
-- Live Instance Scanner
-- Queries EJ_GetInstanceByIndex to determine which instances are actually
-- available in-game (filters out unreleased/future content from static data)
-------------------------------------------------------------------------------

local _liveInstances = {}  -- Cache: ["tierIndex_0"|"tierIndex_1"] = {[instanceID] = true}

local function ScanLiveInstances(ejTierIndex, isRaid)
    local cacheKey = ejTierIndex .. "_" .. (isRaid and 1 or 0)
    if _liveInstances[cacheKey] then
        return _liveInstances[cacheKey]
    end

    local ok, result = pcall(function()
        ns.Data:SuppressEJEvents()

        EJ_SelectTier(ejTierIndex)
        local set = {}
        local index = 1
        while true do
            local instanceID = EJ_GetInstanceByIndex(index, isRaid)
            if not instanceID then break end
            set[instanceID] = true
            index = index + 1
        end

        ns.Data:RestoreEJEvents()
        return set
    end)

    if not ok then
        ns.Data:RestoreEJEvents()  -- Ensure restore on error
        return nil  -- Signal fallback to unfiltered
    end

    _liveInstances[cacheKey] = result
    return result
end

-------------------------------------------------------------------------------
-- One-time Tier Index Resolution
-- Maps static tier names to runtime EJ tier indices (needed for EJ_SelectTier)
-------------------------------------------------------------------------------

local function ResolveTierIndices()
    if ns.Data._tierIndexResolved then return end
    ns.Data._tierIndexResolved = true

    local tierIndexMap = {}
    for i = 1, EJ_GetNumTiers() do
        local name = EJ_GetTierInfo(i)
        if name then
            tierIndexMap[name] = i
        end
    end

    for _, tier in ipairs(ns.StaticData.tiers) do
        tier.id = tierIndexMap[tier.name]
    end
end

-------------------------------------------------------------------------------
-- Pre-populate _instanceInfo from static data
-------------------------------------------------------------------------------

local function EnsureInstanceInfo()
    if next(ns.Data._instanceInfo) then return end

    -- Build reverse lookup: instanceID -> tierID (using EJ tier index)
    ResolveTierIndices()

    for _, tier in ipairs(ns.StaticData.tiers) do
        if tier.id then
            local tierData = ns.StaticData.tierInstances[tier.journalTierID]
            if tierData then
                for _, inst in ipairs(tierData.raid) do
                    local static = ns.StaticData.instances[inst.id]
                    if static then
                        ns.Data._instanceInfo[inst.id] = {
                            id = inst.id,
                            name = static.name,
                            tierID = tier.id,
                            isRaid = true,
                            shouldDisplayDifficulty = static.shouldDisplayDifficulty,
                        }
                    end
                end
                for _, inst in ipairs(tierData.dungeon) do
                    local static = ns.StaticData.instances[inst.id]
                    if static then
                        ns.Data._instanceInfo[inst.id] = {
                            id = inst.id,
                            name = static.name,
                            tierID = tier.id,
                            isRaid = false,
                            shouldDisplayDifficulty = static.shouldDisplayDifficulty,
                        }
                    end
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Data Access Functions
-------------------------------------------------------------------------------

-- Get all tiers sorted newest first (with resolved EJ indices)
function ns:GetTiers()
    ResolveTierIndices()
    return ns.StaticData.tiers
end

-- Get instances for a specific tier (tierID = EJ tier index)
function ns:GetInstancesForTier(tierID, isRaid)
    ResolveTierIndices()

    -- Find the journalTierID for this EJ tier index
    local journalTierID
    for _, tier in ipairs(ns.StaticData.tiers) do
        if tier.id == tierID then
            journalTierID = tier.journalTierID
            break
        end
    end

    if not journalTierID then return {} end

    local tierData = ns.StaticData.tierInstances[journalTierID]
    if not tierData then return {} end

    local staticList = isRaid and tierData.raid or tierData.dungeon

    -- Filter against live EJ instances (removes unreleased/future content)
    local liveSet = ScanLiveInstances(tierID, isRaid)
    if not liveSet then
        return staticList  -- Fallback: scan failed, return unfiltered
    end

    local filtered = {}
    for _, inst in ipairs(staticList) do
        if liveSet[inst.id] then
            table.insert(filtered, inst)
        end
    end
    return filtered
end

-- Get all instances (for searching across tiers)
function ns:GetAllInstances()
    EnsureInstanceInfo()

    local result = {}
    for instanceID, info in pairs(ns.Data._instanceInfo) do
        result[instanceID] = {
            name = info.name,
            tierID = info.tierID,
            isRaid = info.isRaid,
        }
    end
    return result
end

-- Get instance info by ID
function ns:GetInstanceInfo(instanceID)
    EnsureInstanceInfo()

    if ns.Data._instanceInfo[instanceID] then
        return ns.Data._instanceInfo[instanceID]
    end

    -- Fallback: check static data directly (instance may not be in any tier)
    local static = ns.StaticData.instances[instanceID]
    if not static then return nil end

    local info = {
        id = instanceID,
        name = static.name,
        tierID = nil,
        isRaid = static.isRaid,
        shouldDisplayDifficulty = static.shouldDisplayDifficulty,
    }
    ns.Data._instanceInfo[instanceID] = info
    return info
end

-- Get valid difficulties for an instance (from static data)
-- Note: Returns difficulties regardless of shouldDisplayDifficulty.
-- UI should use shouldDisplayDifficulty to hide the dropdown, not gate data.
function ns:GetDifficultiesForInstance(instanceID)
    local info = ns:GetInstanceInfo(instanceID)
    if not info then return {} end

    return ns.StaticData.instanceDifficulties[instanceID] or {}
end

