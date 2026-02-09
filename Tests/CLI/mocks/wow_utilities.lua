-- Essential WoW utilities from wow-ui-source
-- Mixin pattern and ColorMixin for CLI testing

-------------------------------------------------------------------------------
-- Mixin (from Blizzard_SharedXMLBase/Mixin.lua)
-------------------------------------------------------------------------------

function Mixin(object, ...)
    for i = 1, select("#", ...) do
        local mixin = select(i, ...)
        for k, v in pairs(mixin) do
            object[k] = v
        end
    end
    return object
end

function CreateFromMixins(...)
    return Mixin({}, ...)
end

function CreateAndInitFromMixin(mixin, ...)
    local object = CreateFromMixins(mixin)
    object:Init(...)
    return object
end

-------------------------------------------------------------------------------
-- ColorMixin (from Blizzard_SharedXMLBase/Color.lua)
-------------------------------------------------------------------------------

ColorMixin = {}

function ColorMixin:OnLoad(r, g, b, a)
    self.r = r
    self.g = g
    self.b = b
    self.a = a or 1
end

function ColorMixin:GetRGBA()
    return self.r, self.g, self.b, self.a
end

function ColorMixin:GetRGBAAsBytes()
    return self.r * 255, self.g * 255, self.b * 255, self.a * 255
end

function ColorMixin:GetRGB()
    return self.r, self.g, self.b
end

function ColorMixin:SetRGBA(r, g, b, a)
    self.r = r
    self.g = g
    self.b = b
    self.a = a or 1
end

function ColorMixin:SetRGB(r, g, b)
    self:SetRGBA(r, g, b, nil)
end

function ColorMixin:IsEqualTo(otherColor)
    return self.r == otherColor.r
       and self.g == otherColor.g
       and self.b == otherColor.b
       and self.a == otherColor.a
end

function ColorMixin:GenerateHexColor()
    return ("ff%02x%02x%02x"):format(self.r * 255, self.g * 255, self.b * 255)
end

function ColorMixin:GenerateHexColorMarkup()
    return "|c" .. self:GenerateHexColor()
end

function ColorMixin:WrapTextInColorCode(text)
    return self:GenerateHexColorMarkup() .. text .. "|r"
end

function CreateColor(r, g, b, a)
    local color = CreateFromMixins(ColorMixin)
    color:OnLoad(r, g, b, a)
    return color
end

-- Pre-defined colors
HIGHLIGHT_FONT_COLOR = CreateColor(1.0, 1.0, 1.0)
NORMAL_FONT_COLOR = CreateColor(1.0, 0.82, 0)
WHITE_FONT_COLOR = CreateColor(1.0, 1.0, 1.0)
RED_FONT_COLOR = CreateColor(1.0, 0.1, 0.1)
GREEN_FONT_COLOR = CreateColor(0.1, 1.0, 0.1)
GRAY_FONT_COLOR = CreateColor(0.5, 0.5, 0.5)
