-- Minimal WoW frame stubs for CLI testing
-- Just enough to load ItemBrowser.lua

local function createMockFrame()
    local frame = {
        scripts = {},
        points = {},
        shown = false,
        size = {width = 0, height = 0},
        children = {},
    }

    function frame:SetScript(event, handler) self.scripts[event] = handler end
    function frame:GetScript(event) return self.scripts[event] end
    function frame:HookScript(event, handler)
        local old = self.scripts[event]
        self.scripts[event] = function(...)
            if old then old(...) end
            handler(...)
        end
    end
    function frame:RegisterEvent(event) end
    function frame:UnregisterEvent(event) end
    function frame:UnregisterAllEvents() end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:SetShown(shown) self.shown = shown end
    function frame:SetSize(w, h) self.size.width, self.size.height = w, h end
    function frame:GetWidth() return self.size.width end
    function frame:GetHeight() return self.size.height end
    function frame:SetWidth(w) self.size.width = w end
    function frame:SetHeight(h) self.size.height = h end
    function frame:SetPoint(...) table.insert(self.points, {...}) end
    function frame:ClearAllPoints() self.points = {} end
    function frame:GetPoint(index) return unpack(self.points[index or 1] or {}) end
    function frame:SetParent(parent) self.parent = parent end
    function frame:GetParent() return self.parent end
    function frame:SetFrameStrata(strata) self.strata = strata end
    function frame:SetFrameLevel(level) self.level = level end
    function frame:SetMovable(movable) self.movable = movable end
    function frame:EnableMouse(enable) self.mouseEnabled = enable end
    function frame:SetClampedToScreen(clamped) self.clamped = clamped end
    function frame:RegisterForDrag(...) end
    function frame:StartMoving() end
    function frame:StopMovingOrSizing() end
    function frame:SetBackdrop(backdrop) self.backdrop = backdrop end
    function frame:SetBackdropColor(...) end
    function frame:SetBackdropBorderColor(...) end
    function frame:SetText(text) self.text = text end
    function frame:GetText() return self.text or "" end
    function frame:SetTextColor(...) end
    function frame:SetEnabled(enabled) self.enabled = enabled end
    function frame:SetChecked(checked) self.checked = checked end
    function frame:GetChecked() return self.checked end
    function frame:CreateTexture(name, layer)
        local texture = createMockFrame()
        texture:SetSize(0, 0)
        function texture:SetTexture(tex) self.texture = tex end
        function texture:SetTexCoord(...) end
        function texture:SetVertexColor(...) end
        function texture:CreateAnimationGroup()
            local ag = {animations = {}}
            function ag:CreateAnimation(animType)
                local anim = {}
                function anim:SetDegrees(d) self.degrees = d end
                function anim:SetDuration(d) self.duration = d end
                function anim:SetSmoothing(s) self.smoothing = s end
                table.insert(ag.animations, anim)
                return anim
            end
            function ag:SetLooping(loop) self.looping = loop end
            function ag:Play() self.playing = true end
            function ag:Stop() self.playing = false end
            return ag
        end
        return texture
    end
    function frame:CreateFontString(name, layer, template)
        local fs = createMockFrame()
        function fs:SetText(text) self.text = text end
        function fs:GetText() return self.text or "" end
        function fs:SetTextColor(...) end
        function fs:SetJustifyH(justify) end
        function fs:SetJustifyV(justify) end
        function fs:SetFont(...) end
        function fs:GetStringWidth() return 100 end
        return fs
    end

    return frame
end

-- Global frame functions
CreateFrame = function(frameType, name, parent, template)
    local frame = createMockFrame()
    if parent then
        frame:SetParent(parent)
        table.insert(parent.children, frame)
    end
    return frame
end

-- Global frame references
UIParent = createMockFrame()
UIParent:SetSize(1920, 1080)

GameTooltip = createMockFrame()
function GameTooltip:SetOwner(...) end
function GameTooltip:SetHyperlink(link) end
function GameTooltip:SetItemByID(id) end
function GameTooltip:AddLine(...) end

-- ScrollBox stubs
CreateDataProvider = function(data)
    local provider = {data = data or {}}
    function provider:GetSize() return #self.data end
    function provider:GetItemAt(index) return self.data[index] end
    function provider:Enumerate() return ipairs(self.data) end
    return provider
end

function CreateScrollBoxListLinearView()
    local view = {}
    function view:SetElementExtent(extent) self.extent = extent end
    function view:SetElementExtentCalculator(calc) self.extentCalc = calc end
    function view:SetElementInitializer(template, init) self.initializer = init end
    return view
end

ScrollUtil = {
    InitScrollBoxListWithScrollBar = function(scrollBox, scrollBar, view) end,
}

-- Class data
MAX_CLASSES = 13

function GetClassInfo(classID)
    local classes = {
        "Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Death Knight",
        "Shaman", "Mage", "Warlock", "Monk", "Druid", "Demon Hunter", "Evoker"
    }
    return classes[classID]
end

function UnitClass(unit)
    return "Warrior", "WARRIOR", 1
end

-- Timer stubs (execute immediately for synchronous tests)
C_Timer = {
    After = function(delay, fn) fn() end,
    NewTimer = function(delay, fn)
        fn()
        return {Cancel = function() end}
    end,
}

-- Item API stubs
C_Item = {
    GetItemInfoInstant = function(itemID)
        return itemID, "INVTYPE_HEAD", nil, "INVTYPE_HEAD"
    end,
}

-- EncounterJournal stubs
C_EncounterJournal = {
    GetLootInfoByIndex = function(index)
        return nil
    end,
}

EJ_GetNumLoot = function() return 0 end
EJ_SelectTier = function(tierID) end
EJ_SelectInstance = function(instanceID) end
EJ_SetDifficulty = function(difficultyID) end
EJ_SetLootFilter = function(classID, specID) end
EJ_ResetLootFilter = function() end
EJ_SelectEncounter = function(encounterID) end
EJ_GetInstanceInfo = function() return "" end
EJ_GetEncounterInfoByIndex = function(index) return nil end
EJ_GetLootFilter = function() return 0, 0 end

-- Continuable container stub
ContinuableContainer = {
    Create = function()
        local container = {continuables = {}}
        function container:AddContinuable(item) table.insert(self.continuables, item) end
        function container:ContinueOnLoad(callback) callback() end
        return container
    end,
}

Item = {
    CreateFromItemID = function(itemID)
        local item = {itemID = itemID}
        function item:GetItemName() return "Test Item " .. itemID end
        function item:GetItemIcon() return 134400 end
        function item:GetItemLink() return "|cff0070dd|Hitem:" .. itemID .. "::::::::80:::::|h[Test Item]|h|r" end
        return item
    end,
}

-- WoWUnit check (not present in CLI)
WoWUnit = nil
