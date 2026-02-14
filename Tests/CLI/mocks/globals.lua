-- WoW global Lua extensions
-- Mock implementations for CLI testing

function wipe(t)
    for k in pairs(t) do
        t[k] = nil
    end
    return t
end

function tinsert(t, pos, value)
    if value == nil then
        table.insert(t, pos)
    else
        table.insert(t, pos, value)
    end
end

function tremove(t, pos)
    return table.remove(t, pos)
end

function strsplit(delimiter, str, pieces)
    local result = {}
    local pattern = "([^" .. delimiter .. "]+)"
    for match in string.gmatch(str, pattern) do
        table.insert(result, match)
        if pieces and #result >= pieces then
            break
        end
    end
    return unpack(result)
end

function strmatch(str, pattern)
    return string.match(str, pattern)
end

function strtrim(s)
    return s:match("^%s*(.-)%s*$")
end

function strfind(str, pattern, init, plain)
    return string.find(str, pattern, init, plain)
end

function strlen(s)
    return string.len(s)
end

function strlower(s)
    return string.lower(s)
end

function strupper(s)
    return string.upper(s)
end

function strsub(s, i, j)
    return string.sub(s, i, j)
end

format = string.format

-- Bit operations (Lua 5.1 compatibility)
bit = bit or {}
if not bit.band then
    local bit32 = rawget(_G, "bit32")
    if bit32 then
        bit.band = bit32.band
        bit.bor = bit32.bor
        bit.bnot = bit32.bnot
        bit.lshift = bit32.lshift
        bit.rshift = bit32.rshift
    else
        bit.band = function(a, b)
            local result, p = 0, 1
            for _ = 1, 32 do
                if a % 2 == 1 and b % 2 == 1 then result = result + p end
                a = math.floor(a / 2); b = math.floor(b / 2); p = p * 2
            end
            return result
        end
        bit.bor = function(a, b)
            local result, p = 0, 1
            for _ = 1, 32 do
                if a % 2 == 1 or b % 2 == 1 then result = result + p end
                a = math.floor(a / 2); b = math.floor(b / 2); p = p * 2
            end
            return result
        end
        bit.bnot = function(a) return 4294967295 - a end
        bit.lshift = function(a, n) return a * (2 ^ n) end
        bit.rshift = function(a, n) return math.floor(a / (2 ^ n)) end
    end
end

-- Math extensions
math.huge = math.huge or 1/0

-- Table utilities
function tContains(t, value)
    for _, v in pairs(t) do
        if v == value then
            return true
        end
    end
    return false
end

function CopyTable(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = CopyTable(v)
    end
    return copy
end

-- Note: Keep native print() for test output
-- WoW overloads like DevTools_Dump can be stubbed if needed
