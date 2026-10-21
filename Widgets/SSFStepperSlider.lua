-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- SSFStepperSlider: the stock AceGUI Slider with a "-" button and a "+" button framing the
-- value box under the bar, for fine tuning after a rough slide. Used from the options
-- table as `dialogControl = "SSFStepperSlider"` on a range entry, so AceConfigDialog
-- drives it exactly like a Slider: SetLabel, SetSliderValues, SetIsPercent, SetValue,
-- SetDisabled, and the OnValueChanged / OnMouseUp / OnEnter / OnLeave callbacks.
-- Built by composition: the real Slider widget fills this one and every call is forwarded.
-- The Slider keeps the state (value, min, max, step, disabled); nothing is copied here.
-- A "-" or "+" press runs the stock wheel handler one notch, which clamps, rounds to the
-- step, updates the text and fires OnValueChanged; then OnMouseUp fires as the stock value
-- box does on Enter, so AceConfigDialog refreshes.
-- The label is left-justified (the stock Slider centers it), so it lines up with the
-- dropdown labels and checkboxes in the window.
--
-- Public:  the Slider's: SetLabel, SetSliderValues, SetIsPercent, SetValue, GetValue,
--          SetDisabled; MinWidth() -> the narrowest it stays usable, its label on one line
--          or the "-", box, "+" row, whichever is wider (SSFFrame:FitWidth sizes the window
--          to it).
-- Lib internals: the stock Slider's label, editbox, slider, frame and alignoffset fields,
--          its min, max, step and disabled fields, and its OnMouseWheel script. An AceGUI
--          bump that renames those breaks the steppers.
-- Reads:   nothing of SSF's.
-- Touches nothing else.

local Type, Version = "SSFStepperSlider", 5
local AceGUI = LibStub("AceGUI-3.0")

local BUTTON = 20      -- +/- button size
local VALUE_GAP = 5    -- px between the bar and the value row
local GAP = 4          -- between a button and the value box
local VALUE_BOX = 44   -- the value box: room for three digits

-- one notch of the stock wheel handler (+1 or -1), then the release the value box fires
local function Step(self, dir)
    local inner = self.inner
    if inner.disabled then return end
    local before = inner:GetValue()
    inner.slider:GetScript("OnMouseWheel")(inner.slider, dir)
    if inner:GetValue() ~= before then self:Fire("OnMouseUp", inner:GetValue()) end
end

local methods = {
    ["OnAcquire"] = function(self)
        self.inner:OnAcquire() -- the stock reset: size, enabled, 0-100 by 1, value 0, wheel off
        self:SetWidth(200)
        self:SetHeight(44 + VALUE_GAP)
        self.inner.label:SetJustifyH("LEFT")
    end,

    ["SetDisabled"] = function(self, disabled)
        self.inner:SetDisabled(disabled)
        if disabled then self.left:Disable() self.right:Disable()
        else self.left:Enable() self.right:Enable() end
    end,

    ["SetValue"] = function(self, value) self.inner:SetValue(value) end,

    ["GetValue"] = function(self) return self.inner:GetValue() end,

    ["SetLabel"] = function(self, text) self.inner:SetLabel(text) end,

    ["SetSliderValues"] = function(self, min_value, max_value, step)
        self.inner:SetSliderValues(min_value, max_value, step)
    end,

    ["SetIsPercent"] = function(self, value) self.inner:SetIsPercent(value) end,

    ["MinWidth"] = function(self)
        local label = self.inner.label:GetUnboundedStringWidth() or 0
        return math.max(label, 2 * (BUTTON + GAP) + VALUE_BOX)
    end,
}

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:EnableMouse(true)

    local widget = { frame = frame, type = Type }

    -- the real slider fills the widget
    local inner = AceGUI:Create("Slider")
    inner.frame:SetParent(frame)
    inner.frame:ClearAllPoints()
    inner.frame:SetAllPoints(frame)
    inner.frame:Show()
    widget.inner = inner
    widget.alignoffset = inner.alignoffset -- the Flow layout aligns this row as it does a Slider

    inner:SetCallback("OnValueChanged", function(_, _, value) widget:Fire("OnValueChanged", value) end)
    inner:SetCallback("OnMouseUp", function(_, _, value) widget:Fire("OnMouseUp", value) end)
    inner:SetCallback("OnEnter", function() widget:Fire("OnEnter") end)
    inner:SetCallback("OnLeave", function() widget:Fire("OnLeave") end)

    -- the value box only needs room for three digits, and sits VALUE_GAP below the bar so
    -- the row of "-", box, "+" has air between it and the bar's min/max labels
    inner.editbox:SetWidth(VALUE_BOX)
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
