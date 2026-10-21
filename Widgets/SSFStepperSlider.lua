-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- SSFStepperSlider: the stock AceGUI Slider with a "-" button and a "+" button framing the
-- value box under the bar, for fine tuning after a rough slide, and an optional bound the
-- thumb cannot pass. Used from the options table as `dialogControl = "SSFStepperSlider"`
-- on a range entry, so AceConfigDialog drives it exactly like a Slider: SetLabel,
-- SetSliderValues, SetIsPercent, SetValue, SetDisabled, and the OnValueChanged / OnMouseUp
-- / OnEnter / OnLeave callbacks.
-- Built by composition: the real Slider widget fills this one and every call is forwarded.
-- The Slider keeps the state (value, min, max, step, disabled); nothing is copied here.
-- A "-" or "+" press runs the stock wheel handler one notch, which clamps, rounds to the
-- step, updates the text and fires OnValueChanged; then OnMouseUp fires as the stock value
-- box does on Enter, so AceConfigDialog refreshes.
-- The bound (the option's `arg`, a number or a function returning one; the Low shard warn
-- slider gets the cap): the scale stays min to max, but any value past the bound, from a
-- drag, the "+" or the typed box, is set back to the bound before AceConfigDialog hears
-- of it; the "+" greys at the bound; the track beyond the bound is drawn dim with a one
-- pixel gold tick at its edge (under where the cap thumb sits on the slider above), so
-- the slider reads "this much is yours, that much is off limits" (Mike, 2026-10-20).
-- The label is left-justified (the stock Slider centers it), so it lines up with the
-- dropdown labels and checkboxes in the window.
--
-- Public:  the Slider's: SetLabel, SetSliderValues, SetIsPercent, SetValue, GetValue,
--          SetDisabled; SetCustomData(bound) (AceConfigDialog hands the option's `arg` to
--          it); MinWidth() -> the narrowest it stays usable, its label on one line or the
--          "-", box, "+" row, whichever is wider (SSFFrame:FitWidth sizes the window to it).
-- Lib internals: the stock Slider's label, editbox, slider (its thumb texture and its
--          3 px side insets, for the dim region), frame and alignoffset fields, its min,
--          max, step and disabled fields, and its OnMouseWheel script. An AceGUI bump that
--          renames those breaks the steppers; one that moves the rail misplaces the dim.
-- Reads:   nothing of SSF's.
-- Touches nothing else.

local Type, Version = "SSFStepperSlider", 7
local AceGUI = LibStub("AceGUI-3.0")

local BUTTON = 20      -- +/- button size
local VALUE_GAP = 5    -- px between the bar and the value row
local GAP = 4          -- between a button and the value box
local VALUE_BOX = 44   -- the value box: room for three digits
local DIM = 0.5        -- alpha of the black over the rail beyond the bound (picked by eye)
local RAIL_INSET = 3   -- the stock Slider anchors its rail this far in from each side
local TICK = 1         -- width of the gold line at the bound's edge
local GOLD_R, GOLD_G, GOLD_B = 1, 0.82, 0 -- the game's label gold (NORMAL_FONT_COLOR)

-- the bound as a number right now, or nil for none
local function Bound(self)
    local b = self.bound
    if type(b) == "function" then b = b() end
    return tonumber(b)
end

-- the "+" greys where the thumb cannot go further: the bound, or the max
local function UpdateButtons(self)
    local inner = self.inner
    if inner.disabled then return end -- SetDisabled greys both
    local top = inner.max or 100
    local bound = Bound(self)
    if bound and bound < top then top = bound end
    self.right:SetEnabled((inner:GetValue() or 0) < top)
end

-- The dim region: from the bound's place on the rail to its right end, with the gold tick
-- on its left edge, full rail height; neither without a bound, or with a bound at or past
-- the max. Where a value sits on the rail: the game keeps
-- the thumb inside the rail, so its center travels from half a thumb in to half a thumb
-- short of the end, not the full width. The rail's width is the widget's width less the
-- stock slider's side insets (RAIL_INSET each side), taken from the number AceGUI just set:
-- a width read back in the same frame as a resize can still be the old one.
local function UpdateDim(self)
    local inner, dim, tick = self.inner, self.dim, self.tick
    local bound, lo, hi = Bound(self), inner.min or 0, inner.max or 100
    if not bound or bound >= hi or hi <= lo then dim:Hide() tick:Hide() return end
    local rail = (self.frame.width or self.frame:GetWidth() or 0) - 2 * RAIL_INSET
    local thumb = inner.slider:GetThumbTexture()
    local tw = thumb and thumb:GetWidth() or 0
    local x = tw / 2 + (rail - tw) * (bound - lo) / (hi - lo)
    dim:ClearAllPoints()
    dim:SetPoint("TOPLEFT", inner.slider, "TOPLEFT", x, 0)
    dim:SetPoint("BOTTOMRIGHT", inner.slider, "BOTTOMRIGHT", 0, 0)
    dim:Show()
    tick:ClearAllPoints()
    tick:SetPoint("TOPLEFT", inner.slider, "TOPLEFT", x, 0)
    tick:SetPoint("BOTTOMLEFT", inner.slider, "BOTTOMLEFT", x, 0)
    tick:Show()
end

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
        self.bound = nil -- pooled widgets: a bound must not leak to another row
        self:SetWidth(200)
        self:SetHeight(44 + VALUE_GAP)
        self.inner.label:SetJustifyH("LEFT")
        UpdateDim(self)
        UpdateButtons(self)
    end,

    ["OnWidthSet"] = function(self) UpdateDim(self) end,

    ["SetDisabled"] = function(self, disabled)
        self.inner:SetDisabled(disabled)
        if disabled then self.left:Disable() self.right:Disable()
        else self.left:Enable() self.right:Enable() UpdateButtons(self) end
    end,

    ["SetValue"] = function(self, value)
        self.inner:SetValue(value)
        UpdateButtons(self)
    end,

    ["GetValue"] = function(self) return self.inner:GetValue() end,

    ["SetLabel"] = function(self, text) self.inner:SetLabel(text) end,

    ["SetSliderValues"] = function(self, min_value, max_value, step)
        self.inner:SetSliderValues(min_value, max_value, step)
        UpdateDim(self)
        UpdateButtons(self)
    end,

    ["SetIsPercent"] = function(self, value) self.inner:SetIsPercent(value) end,

    -- the option's `arg`: the bound. A value already past it is shown at the bound (the
    -- owner keeps the saved value within it; nothing is written from here).
    ["SetCustomData"] = function(self, bound)
        self.bound = bound
        local b, inner = Bound(self), self.inner
        if b and (inner:GetValue() or 0) > b then inner:SetValue(b) end
        UpdateDim(self)
        UpdateButtons(self)
    end,

    ["MinWidth"] = function(self)
        local label = self.inner.label:GetUnboundedStringWidth() or 0
        return math.max(label, 2 * (BUTTON + GAP) + VALUE_BOX)
    end,
}

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    local widget = { frame = frame, type = Type }

    -- the wrapper takes the hover while the slider is disabled (a disabled slider swallows
    -- no mouse), so a greyed slider still shows its tooltip
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function() widget:Fire("OnEnter") end)
    frame:SetScript("OnLeave", function() widget:Fire("OnLeave") end)

    -- the real slider fills the widget
    local inner = AceGUI:Create("Slider")
    inner.frame:SetParent(frame)
    inner.frame:ClearAllPoints()
    inner.frame:SetAllPoints(frame)
    inner.frame:Show()
    widget.inner = inner
    widget.alignoffset = inner.alignoffset -- the Flow layout aligns this row as it does a Slider

    -- the bound, applied in the one place every value passes: a drag tick, the typed box
    -- and the "+" all end in the stock OnValueChanged. Set back before it is forwarded, so
    -- AceConfigDialog never hears a value past the bound.
    inner:SetCallback("OnValueChanged", function(_, _, value)
        local bound = Bound(widget)
        if bound and value > bound then
            value = bound
            inner:SetValue(value) -- the stock SetValue sets its setup flag: no second fire
        end
        UpdateButtons(widget)
        widget:Fire("OnValueChanged", value)
    end)
    inner:SetCallback("OnMouseUp", function(_, _, value) widget:Fire("OnMouseUp", value) end)
    inner:SetCallback("OnEnter", function() widget:Fire("OnEnter") end)
    inner:SetCallback("OnLeave", function() widget:Fire("OnLeave") end)

    -- the dim region over the track beyond the bound: on the slider itself, under its thumb
    local dim = inner.slider:CreateTexture(nil, "ARTWORK", nil, -1)
    dim:SetColorTexture(0, 0, 0, DIM)
    dim:Hide()
    widget.dim = dim

    -- the gold tick on the dim region's left edge: one layer up, so it draws over the dim
    local tick = inner.slider:CreateTexture(nil, "ARTWORK", nil, 0)
    tick:SetColorTexture(GOLD_R, GOLD_G, GOLD_B, 1)
    tick:SetWidth(TICK)
    tick:Hide()
    widget.tick = tick

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
