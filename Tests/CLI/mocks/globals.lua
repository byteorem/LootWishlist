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
bit.band = bit.band or function(a, b) return a & b end
bit.bor = bit.bor or function(a, b) return a | b end
bit.bnot = bit.bnot or function(a) return ~a end
bit.lshift = bit.lshift or function(a, n) return a << n end
bit.rshift = bit.rshift or function(a, n) return a >> n end

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
