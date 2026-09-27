-- Soul Shard Forever (SSF). MIT, see LICENSE.
--
-- SSFStepperSlider: an AceGUI widget. The stock AceGUI Slider with a "-" button and a "+"
-- button framing the value box under the bar, for fine tuning after a rough slide.
-- Used from the options table as `dialogControl = "SSFStepperSlider"` on a range entry, so
-- AceConfigDialog drives it exactly like a Slider: SetLabel, SetSliderValues, SetIsPercent,
-- SetValue, SetDisabled, and the OnValueChanged / OnMouseUp / OnEnter / OnLeave callbacks.
-- Built by composition: the real Slider widget fills this one and every call is forwarded.

local Type, Version = "SSFStepperSlider", 1
local AceGUI = LibStub("AceGUI-3.0")

local BUTTON = 20      -- +/- button size
local VALUE_GAP = 5    -- px between the bar and the value row
local GAP = 4          -- between a button and the value box

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
        self:SetHeight(44 + VALUE_GAP)
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

    -- the real slider fills the widget
    local inner = AceGUI:Create("Slider")
    inner.frame:SetParent(frame)
    inner.frame:ClearAllPoints()
    inner.frame:SetAllPoints(frame)
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

    -- the value box only needs room for three digits, and sits VALUE_GAP below the bar so
    -- the row of "-", box, "+" has air between it and the bar's min/max labels
    inner.editbox:SetWidth(44)
    inner.editbox:ClearAllPoints()
    inner.editbox:SetPoint("TOP", inner.slider, "BOTTOM", 0, -VALUE_GAP)

    -- "-" and "+" frame the value box: real bordered buttons, parented to the slider's frame
    -- and raised above it so the slider's own mouse handling cannot swallow the clicks
    local function Stepper(text, dir, point, relPoint, x)
        local b = CreateFrame("Button", nil, inner.frame, "UIPanelButtonTemplate")
        b:SetSize(BUTTON, BUTTON)
        b:SetPoint(point, inner.editbox, relPoint, x, 0)
        b:SetFrameLevel(inner.frame:GetFrameLevel() + 5)
        b:SetText(text)
        b:SetScript("OnClick", function() Step(widget, dir) end)
        b:SetScript("OnEnter", function() widget:Fire("OnEnter") end)
        b:SetScript("OnLeave", function() widget:Fire("OnLeave") end)
        return b
    end
    widget.left = Stepper("-", -1, "RIGHT", "LEFT", -GAP)
    widget.right = Stepper("+", 1, "LEFT", "RIGHT", GAP)

    for method, func in pairs(methods) do
        widget[method] = func
    end
    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
