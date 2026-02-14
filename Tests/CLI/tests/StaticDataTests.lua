-- Structure validation tests for Data/StaticData.lua
-- Run via: lua Tests/CLI/run_staticdata.lua

local function RegisterTests(T, ns, projectRoot)
    local tests = {}
    local sd = ns.StaticData

    -- Helper: count entries in a table (works for both array and hash tables)
    local function countEntries(t)
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        return n
    end

    -----------------------------------------------------------------------
    -- Hash line
    -----------------------------------------------------------------------
    tests["Hash line matches expected pattern"] = function()
        local f = io.open(projectRoot .. "Data/StaticData.lua", "r")
        T.IsTrue(f ~= nil, "StaticData.lua must exist")
        local firstLine = f:read("*l")
        f:close()
        T.IsTrue(
            firstLine:match("^%-%- Hash: [a-f0-9]+$") ~= nil,
            "First line must match '-- Hash: <hex>' pattern, got: " .. tostring(firstLine)
        )
    end

    -----------------------------------------------------------------------
    -- Top-level keys exist and are non-nil tables
    -----------------------------------------------------------------------
    local topLevelKeys = {"tiers", "instances", "tierInstances", "instanceDifficulties", "encounters", "difficulties"}

    for _, key in ipairs(topLevelKeys) do
        tests["Top-level key exists: " .. key] = function()
            T.IsTrue(sd[key] ~= nil, key .. " must not be nil")
            T.AreEqual("table", type(sd[key]), key .. " must be a table")
        end

        tests["Non-empty: " .. key] = function()
            T.IsTrue(countEntries(sd[key]) >= 1, key .. " must have at least 1 entry")
        end
    end

    -----------------------------------------------------------------------
    -- Shape: tiers
    -----------------------------------------------------------------------
    tests["Shape: tiers entries have name (string) and journalTierID (number)"] = function()
        for i, tier in ipairs(sd.tiers) do
            T.AreEqual("string", type(tier.name),
                "tiers[" .. i .. "].name must be string, got " .. type(tier.name))
            T.AreEqual("number", type(tier.journalTierID),
                "tiers[" .. i .. "].journalTierID must be number, got " .. type(tier.journalTierID))
        end
    end

    -----------------------------------------------------------------------
    -- Shape: instances
    -----------------------------------------------------------------------
    tests["Shape: instances entries have name, isRaid, shouldDisplayDifficulty, mapID"] = function()
        local checked = 0
        for id, inst in pairs(sd.instances) do
            T.AreEqual("string", type(inst.name),
                "instances[" .. id .. "].name must be string")
            T.AreEqual("boolean", type(inst.isRaid),
                "instances[" .. id .. "].isRaid must be boolean")
            T.AreEqual("boolean", type(inst.shouldDisplayDifficulty),
                "instances[" .. id .. "].shouldDisplayDifficulty must be boolean")
            T.AreEqual("number", type(inst.mapID),
                "instances[" .. id .. "].mapID must be number")
            checked = checked + 1
        end
        T.IsTrue(checked > 0, "Must have checked at least 1 instance")
    end

    -----------------------------------------------------------------------
    -- Shape: tierInstances
    -----------------------------------------------------------------------
    tests["Shape: tierInstances entries have raid and dungeon sub-tables"] = function()
        local checked = 0
        for tierID, ti in pairs(sd.tierInstances) do
            T.AreEqual("table", type(ti.raid),
                "tierInstances[" .. tierID .. "].raid must be table")
            T.AreEqual("table", type(ti.dungeon),
                "tierInstances[" .. tierID .. "].dungeon must be table")

            for i, entry in ipairs(ti.raid) do
                T.AreEqual("number", type(entry.id),
                    "tierInstances[" .. tierID .. "].raid[" .. i .. "].id must be number")
                T.AreEqual("string", type(entry.name),
                    "tierInstances[" .. tierID .. "].raid[" .. i .. "].name must be string")
                T.AreEqual("number", type(entry.order),
                    "tierInstances[" .. tierID .. "].raid[" .. i .. "].order must be number")
            end

            for i, entry in ipairs(ti.dungeon) do
                T.AreEqual("number", type(entry.id),
                    "tierInstances[" .. tierID .. "].dungeon[" .. i .. "].id must be number")
                T.AreEqual("string", type(entry.name),
                    "tierInstances[" .. tierID .. "].dungeon[" .. i .. "].name must be string")
                T.AreEqual("number", type(entry.order),
                    "tierInstances[" .. tierID .. "].dungeon[" .. i .. "].order must be number")
            end

            checked = checked + 1
        end
        T.IsTrue(checked > 0, "Must have checked at least 1 tierInstances entry")
    end

    -----------------------------------------------------------------------
    -- Shape: instanceDifficulties
    -----------------------------------------------------------------------
    tests["Shape: instanceDifficulties entries are lists of {id, name, order}"] = function()
        local checked = 0
        for instID, diffs in pairs(sd.instanceDifficulties) do
            T.AreEqual("table", type(diffs),
                "instanceDifficulties[" .. instID .. "] must be table")
            for i, d in ipairs(diffs) do
                T.AreEqual("number", type(d.id),
                    "instanceDifficulties[" .. instID .. "][" .. i .. "].id must be number")
                T.AreEqual("string", type(d.name),
                    "instanceDifficulties[" .. instID .. "][" .. i .. "].name must be string")
                T.AreEqual("number", type(d.order),
                    "instanceDifficulties[" .. instID .. "][" .. i .. "].order must be number")
            end
            checked = checked + 1
        end
        T.IsTrue(checked > 0, "Must have checked at least 1 instanceDifficulties entry")
    end

    -----------------------------------------------------------------------
    -- Shape: encounters
    -----------------------------------------------------------------------
    tests["Shape: encounters entries are lists of {id, name, order}"] = function()
        local checked = 0
        for instID, encs in pairs(sd.encounters) do
            T.AreEqual("table", type(encs),
                "encounters[" .. instID .. "] must be table")
            for i, e in ipairs(encs) do
                T.AreEqual("number", type(e.id),
                    "encounters[" .. instID .. "][" .. i .. "].id must be number")
                T.AreEqual("string", type(e.name),
                    "encounters[" .. instID .. "][" .. i .. "].name must be string")
                T.AreEqual("number", type(e.order),
                    "encounters[" .. instID .. "][" .. i .. "].order must be number")
            end
            checked = checked + 1
        end
        T.IsTrue(checked > 0, "Must have checked at least 1 encounters entry")
    end

    -----------------------------------------------------------------------
    -- Shape: difficulties
    -----------------------------------------------------------------------
    tests["Shape: difficulties entries have name (string) and order (number)"] = function()
        local checked = 0
        for diffID, d in pairs(sd.difficulties) do
            T.AreEqual("string", type(d.name),
                "difficulties[" .. diffID .. "].name must be string")
            T.AreEqual("number", type(d.order),
                "difficulties[" .. diffID .. "].order must be number")
            checked = checked + 1
        end
        T.IsTrue(checked > 0, "Must have checked at least 1 difficulty")
    end

    -----------------------------------------------------------------------
    -- Cross-references: tierInstances instance IDs exist in instances
    -----------------------------------------------------------------------
    tests["Cross-ref: tierInstances instance IDs exist in instances"] = function()
        for tierID, ti in pairs(sd.tierInstances) do
            for _, entry in ipairs(ti.raid) do
                T.IsTrue(sd.instances[entry.id] ~= nil,
                    "tierInstances[" .. tierID .. "] raid instance " .. entry.id .. " not found in instances")
            end
            for _, entry in ipairs(ti.dungeon) do
                T.IsTrue(sd.instances[entry.id] ~= nil,
                    "tierInstances[" .. tierID .. "] dungeon instance " .. entry.id .. " not found in instances")
            end
        end
    end

    -----------------------------------------------------------------------
    -- Cross-references: tierInstances keys match tiers[].journalTierID
    -----------------------------------------------------------------------
    tests["Cross-ref: tierInstances keys match tiers journalTierIDs"] = function()
        local tierIDs = {}
        for _, tier in ipairs(sd.tiers) do
            tierIDs[tier.journalTierID] = true
        end
        for tierID in pairs(sd.tierInstances) do
            T.IsTrue(tierIDs[tierID] ~= nil,
                "tierInstances key " .. tierID .. " has no matching tier in tiers[]")
        end
    end

    -----------------------------------------------------------------------
    -- Minimum counts (sanity check for truncated data)
    -----------------------------------------------------------------------
    tests["Minimum count: tiers >= 10"] = function()
        T.IsTrue(#sd.tiers >= 10,
            "Expected >= 10 tiers, got " .. #sd.tiers)
    end

    tests["Minimum count: instances >= 100"] = function()
        T.IsTrue(countEntries(sd.instances) >= 100,
            "Expected >= 100 instances, got " .. countEntries(sd.instances))
    end

    tests["Minimum count: difficulties >= 10"] = function()
        T.IsTrue(countEntries(sd.difficulties) >= 10,
            "Expected >= 10 difficulties, got " .. countEntries(sd.difficulties))
    end

    return tests
end

return RegisterTests
