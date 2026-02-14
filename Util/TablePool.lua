-- LootWishlist Table Pool
-- Reusable table allocation to reduce garbage collection pressure

local _, ns = ...

local wipe = wipe

---@class TablePool
---@field pool table[] Available tables
---@field active integer Number of tables currently in use
local TablePool = {}
TablePool.__index = TablePool

---@param name string Pool name for debugging
---@return TablePool
function TablePool.Create(name)
    return setmetatable({
        name = name,
        pool = {},
        active = 0,
    }, TablePool)
end

---@return table t A clean table from the pool (or a new one)
function TablePool:Acquire()
    local t = table.remove(self.pool)
    if not t then
        t = {}
    end
    self.active = self.active + 1
    return t
end

---@param t table The table to return to the pool
function TablePool:Release(t)
    wipe(t)
    table.insert(self.pool, t)
    self.active = self.active - 1
end

---@return integer available Number of tables in the pool
---@return integer active Number of tables currently in use
function TablePool:GetStats()
    return #self.pool, self.active
end

ns.TablePool = TablePool
