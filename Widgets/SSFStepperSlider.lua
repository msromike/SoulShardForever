-- Soul Shard Forever (SSF). MIT, see LICENSE.
--
-- SSFStepperSlider: an AceGUI widget. The stock AceGUI Slider with a step-down arrow on its
-- left edge and a step-up arrow on its right, for fine tuning after a rough slide.
-- Used from the options table as `dialogControl = "SSFStepperSlider"` on a range entry, so
-- AceConfigDialog drives it exactly like a Slider: SetLabel, SetSliderValues, SetIsPercent,
-- SetValue, SetDisabled, and the OnValueChanged / OnMouseUp / OnEnter / OnLeave callbacks.
-- Built by composition: the real Slider widget sits between the two arrows and every call
-- is forwarded to it.

local Type, Version = "SSFStepperSlider", 1
local AceGUI = LibStub("AceGUI-3.0")

local ARROW = 18       -- arrow button size
local GAP = 2          -- between arrow and slider

-- Atlas pair for the arrows on this engine, or nil to fall back to text.
local function ArrowAtlases()
    if C_Texture and C_Texture.GetAtlasInfo
        and C_Texture.GetAtlasInfo("Minimal_SliderBar_Button_Left")
        and C_Texture.GetAtlasInfo("Minimal_SliderBar_Button_Right") then
        return "Minimal_SliderBar_Button_Left", "Minimal_SliderBar_Button_Right"
    end
end

local function Step(self, dir)
    if self.disabled then return end
    local step = self.step or 1
    local value = (self.value or 0) + dir * step
    if self.min and value < self.min then value = self.min end
    if self.max and value > self.max then value = self.max end
    if value == self.value then return end
    self:SetValue(value)
    self:Fire("OnValueChanged", value) -- AceConfigDialog calls set
    self:Fire("OnMouseUp", value)      -- and refreshes the window
end

local methods = {
    ["OnAcquire"] = function(self)
        self:SetWidth(200)
        self:SetHeight(44)
        self:SetDisabled(false)
        self:SetIsPercent(nil)
        self:SetSliderValues(0, 100, 1)
        self:SetValue(0)
    end,

    ["SetDisabled"] = function(self, disabled)
        self.disabled = disabled
        self.inner:SetDisabled(disabled)
        if disabled then self.left:Disable() self.right:Disable()
        else self.left:Enable() self.right:Enable() end
    end,

    ["SetValue"] = function(self, value)
        self.value = value
        self.inner:SetValue(value)
    end,

    ["GetValue"] = function(self) return self.value end,

    ["SetLabel"] = function(self, text) self.inner:SetLabel(text) end,

    ["SetSliderValues"] = function(self, min_value, max_value, step)
        self.min, self.max, self.step = min_value, max_value, step
        self.inner:SetSliderValues(min_value, max_value, step)
    end,

    ["SetIsPercent"] = function(self, value) self.inner:SetIsPercent(value) end,
}

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:EnableMouse(true)

    local widget = { frame = frame, type = Type, alignoffset = 25 }

    -- the real slider, between the arrows
    local inner = AceGUI:Create("Slider")
    inner.frame:SetParent(frame)
    inner.frame:ClearAllPoints()
    inner.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", ARROW + GAP, 0)
    inner.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(ARROW + GAP), 0)
    inner.frame:Show()
    widget.inner = inner

    inner:SetCallback("OnValueChanged", function(_, _, value)
        widget.value = value
        widget:Fire("OnValueChanged", value)
    end)
    inner:SetCallback("OnMouseUp", function(_, _, value)
        widget.value = value
        widget:Fire("OnMouseUp", value)
    end)
    inner:SetCallback("OnEnter", function() widget:Fire("OnEnter") end)
    inner:SetCallback("OnLeave", function() widget:Fire("OnLeave") end)

    local leftAtlas, rightAtlas = ArrowAtlases()
    local function Arrow(point, atlas, text, dir)
        local b = CreateFrame("Button", nil, frame)
        b:SetSize(ARROW, ARROW)
        -- level with the slider bar: the Slider widget puts its bar 15px below its label
        b:SetPoint(point, frame, point, 0, -15 - 7 + ARROW / 2)
        if atlas then
            b:SetNormalAtlas(atlas)
            b:SetHighlightAtlas(atlas, "ADD")
            b:SetDisabledAtlas(atlas)
            b:GetDisabledTexture():SetDesaturated(true)
        else
            b:SetNormalFontObject(GameFontNormal)
            b:SetHighlightFontObject(GameFontHighlight)
            b:SetDisabledFontObject(GameFontDisable)
            b:SetText(text)
        end
        b:SetScript("OnClick", function() Step(widget, dir) end)
        b:SetScript("OnEnter", function() widget:Fire("OnEnter") end)
        b:SetScript("OnLeave", function() widget:Fire("OnLeave") end)
        return b
    end
    widget.left = Arrow("LEFT", leftAtlas, "<", -1)
    widget.right = Arrow("RIGHT", rightAtlas, ">", 1)

    for method, func in pairs(methods) do
        widget[method] = func
    end
    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
