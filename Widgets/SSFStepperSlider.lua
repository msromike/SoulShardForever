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
-- The bound (the option's `arg`, a number or a function returning one; the Low shard mark
-- slider gets the cap): the scale stays min to max, but any value past the bound, from a
-- drag, the "+" or the typed box, is set back to the bound before AceConfigDialog hears
-- of it; the "+" greys at the bound; the track beyond the bound is drawn dim with a gold
-- tick TICK pixels wide at its edge, running TICK_BELOW past the slider's bottom (under where the cap thumb sits on the slider above), so
-- the slider reads "this much is yours, that much is off limits".
-- The label is left-justified (the stock Slider centers it), so it lines up with the
-- dropdown labels and checkboxes in the window.
-- The let-go (the option's `arg` as a table with a `released` function; the pause sound
-- slider plays its preview from it): AceConfigDialog calls an option's set on every drag
-- tick and again when the handle is let go, and the set cannot tell the two apart. This
-- widget can: a let-go, a "-" or "+" press and a typed value all end in its one OnMouseUp
-- (Release below), which calls `released(value)` once, after AceConfigDialog has saved.
-- The notches (the option's `arg` as a table with `notches = true`; the pause sound slider
-- has five): one gold tick at every step from min to max, so the player sees where the
-- thumb can rest. As wide as the bound's tick, but centered under the thumb and kept
-- inside the rail's height.
--
-- Public:  the Slider's: SetLabel, SetSliderValues, SetIsPercent, SetValue, GetValue,
--          SetDisabled; SetCustomData(arg) (AceConfigDialog hands the option's `arg` to
--          it): a number or a function is the bound; a table is { bound = the same,
--          released = function(value), notches = true }, each optional;
--          MinWidth() -> the narrowest it stays usable, its label on one line or the
--          "-", box, "+" row, whichever is wider (SSFFrame:FitWidth sizes the window to it).
-- Lib internals: the stock Slider's label, editbox, slider (its thumb texture and its
--          3 px side insets, for the dim region), frame (also handed to Help:KeepHover as
--          the frame that gives up the mouse while greyed) and alignoffset fields, its min,
--          max, step and disabled fields, its OnMouseWheel script (the "-" and "+" buttons run it,
--          so they move by the stock Slider's own step field, exactly as the wheel does; a
--          Slider whose wheel stopped using step would make the buttons jump by something
--          else), and AceGUI's frame.width field.
--          The inner Slider's OnAcquire is called directly, outside AceGUI:Create, as a
--          full repeatable reset; the 44 in OnAcquire copies the stock Slider's height; the
--          clamp relies on the stock SetValue's setup flag to swallow the second
--          OnValueChanged (the value check there would also stop it). An AceGUI bump that
--          renames those breaks the steppers; one that moves the rail misplaces the dim.
-- Game internals: the frame template UIPanelButtonTemplate, which the "-" and "+" buttons
--          are made from.
-- Reads:   Colors.GOLD (the tick) and Colors.BLACK (the dim); Help:KeepHover/Greyed (the
--          tooltip on a greyed slider).
-- Touches nothing else.

local Type, Version = "SSFStepperSlider", 11
local AceGUI = LibStub("AceGUI-3.0")

-- SSF's modules (the addon is loaded by the time a widget is made)
local function Colors() return LibStub("AceAddon-3.0"):GetAddon("SSF"):GetModule("Colors") end
local function Help() return LibStub("AceAddon-3.0"):GetAddon("SSF"):GetModule("Help") end

local BUTTON = 20      -- +/- button size
local VALUE_GAP = 5    -- px between the bar and the value row
local GAP = 4          -- between a button and the value box
local VALUE_BOX = 44   -- the value box: room for three digits
local DIM = 0.5        -- alpha of the black over the rail beyond the bound (picked by eye)
local RAIL_INSET = 3   -- the stock Slider anchors its rail this far in from each side
local TICK = 2         -- width of the gold line at the bound's edge (1 read too faint)
local TICK_BELOW = 3  -- px the tick runs on below the slider: no room above

-- the bound as a number right now, or nil for none
local function Bound(self)
    local b = self.bound
    if type(b) == "function" then b = b() end
    return tonumber(b)
end

-- the one clamp to the bound, for both callbacks below
local function Clamp(self, value)
    local bound = Bound(self)
    if bound and value > bound then return bound end
    return value
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
local function RailX(self, value)
    local inner = self.inner
    local lo, hi = inner.min or 0, inner.max or 100
    local rail = (self.frame.width or self.frame:GetWidth() or 0) - 2 * RAIL_INSET
    local thumb = inner.slider:GetThumbTexture()
    local tw = thumb and thumb:GetWidth() or 0
    return tw / 2 + (rail - tw) * (value - lo) / (hi - lo)
end

-- a gold tick on the slider, one layer above the dim so it draws over it
local function NewTick(slider)
    local gold = Colors().GOLD
    local tick = slider:CreateTexture(nil, "ARTWORK", nil, 0)
    tick:SetColorTexture(gold[1], gold[2], gold[3], 1)
    tick:SetWidth(TICK)
    tick:Hide()
    return tick
end

-- a tick shown with its left edge x pixels along the rail: full rail height, and `below`
-- pixels under it
local function PlaceTick(self, tick, x, below)
    local slider = self.inner.slider
    tick:ClearAllPoints()
    tick:SetPoint("TOPLEFT", slider, "TOPLEFT", x, 0)
    tick:SetPoint("BOTTOMLEFT", slider, "BOTTOMLEFT", x, -below)
    tick:Show()
end

local function UpdateDim(self)
    local inner, dim, tick = self.inner, self.dim, self.tick
    local bound, lo, hi = Bound(self), inner.min or 0, inner.max or 100
    if not bound or bound >= hi or hi <= lo then dim:Hide() tick:Hide() return end
    local x = RailX(self, bound)
    dim:ClearAllPoints()
    dim:SetPoint("TOPLEFT", inner.slider, "TOPLEFT", x, 0)
    dim:SetPoint("BOTTOMRIGHT", inner.slider, "BOTTOMRIGHT", 0, 0)
    dim:Show()
    PlaceTick(self, tick, x, TICK_BELOW)
end

-- The notch ticks: with `notches` on, one gold tick at every step from min to max, so the
-- player sees where the thumb can rest; none otherwise. Quieter than the bound's tick:
-- centered on the thumb's resting place and no taller than the rail. Ticks are made as
-- needed and kept.
local function UpdateNotches(self)
    local inner, ticks = self.inner, self.notchTicks
    local lo, hi, step = inner.min or 0, inner.max or 100, inner.step
    local count = 0
    if self.notches and step and step > 0 and hi > lo then
        count = math.floor((hi - lo) / step + 0.5) + 1
    end
    for i = 1, count do
        if not ticks[i] then ticks[i] = NewTick(inner.slider) end
        PlaceTick(self, ticks[i], RailX(self, lo + (i - 1) * step) - TICK / 2, 0)
    end
    for i = count + 1, #ticks do ticks[i]:Hide() end
end

-- everything drawn on the rail, redrawn whenever the width, the scale or the `arg` changes
local function UpdateRail(self)
    UpdateDim(self)
    UpdateNotches(self)
end

-- The let-go, the one place OnMouseUp is fired: AceConfigDialog saves the value and
-- redraws, then the option's `released` hears of it. `released` is read first: the redraw
-- can hand this widget to another row, which clears it.
local function Release(self, value)
    local released = self.released
    self:Fire("OnMouseUp", value)
    if released then released(value) end
end

-- one notch of the stock wheel handler (+1 or -1), then the release the value box fires
local function Step(self, dir)
    local inner = self.inner
    if inner.disabled then return end
    local before = inner:GetValue()
    inner.slider:GetScript("OnMouseWheel")(inner.slider, dir)
    if inner:GetValue() ~= before then Release(self, inner:GetValue()) end
end

local methods = {
    ["OnAcquire"] = function(self)
        self.inner:OnAcquire() -- the stock reset: size, enabled, 0-100 by 1, value 0, wheel off
        self.bound, self.released = nil, nil -- pooled widgets: nothing must leak to another row
        self.notches = nil
        self:SetWidth(200)
        self:SetHeight(44 + VALUE_GAP)
        self.inner.label:SetJustifyH("LEFT")
        UpdateRail(self)
        UpdateButtons(self)
    end,

    ["OnWidthSet"] = function(self) UpdateRail(self) end,

    ["SetDisabled"] = function(self, disabled)
        self.inner:SetDisabled(disabled)
        Help():Greyed(self, disabled) -- greyed, the wrapper takes the hover: the tooltip still shows
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
        UpdateRail(self)
        UpdateButtons(self)
    end,

    ["SetIsPercent"] = function(self, value) self.inner:SetIsPercent(value) end,

    -- the option's `arg`: the bound, or a table with the bound, the let-go's `released`
    -- and `notches`. A value already past the bound is shown at it (the owner keeps the
    -- saved value within it; nothing is written from here).
    ["SetCustomData"] = function(self, arg)
        if type(arg) == "table" then
            self.bound, self.released = arg.bound, arg.released
            self.notches = arg.notches
        else
            self.bound, self.released = arg, nil
            self.notches = nil
        end
        local b, inner = Bound(self), self.inner
        if b and (inner:GetValue() or 0) > b then inner:SetValue(b) end
        UpdateRail(self)
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

    -- the real slider fills the widget
    local inner = AceGUI:Create("Slider")
    inner.frame:SetParent(frame)
    inner.frame:ClearAllPoints()
    inner.frame:SetAllPoints(frame)
    inner.frame:Show()
    widget.inner = inner
    Help():KeepHover(widget, frame, { inner.frame }) -- a greyed slider still shows its tooltip
    widget.alignoffset = inner.alignoffset -- the Flow layout aligns this row as it does a Slider

    -- the bound: a drag tick, the typed box and the "+" all end in the stock OnValueChanged,
    -- set back before it is forwarded. The typed box also fires OnMouseUp with its raw
    -- number (below), so the bound is applied there as well; AceConfigDialog never hears a
    -- value past it.
    inner:SetCallback("OnValueChanged", function(_, _, value)
        local clamped = Clamp(widget, value)
        if clamped ~= value then
            value = clamped
            inner:SetValue(value) -- the stock SetValue sets its setup flag: no second fire
        end
        UpdateButtons(widget)
        widget:Fire("OnValueChanged", value)
    end)
    -- the typed box fires OnMouseUp with the raw number (the stock EditBox_OnEnterPressed),
    -- so the bound is applied here too before AceConfigDialog saves it
    inner:SetCallback("OnMouseUp", function(_, _, value)
        Release(widget, Clamp(widget, value))
    end)
    inner:SetCallback("OnEnter", function() widget:Fire("OnEnter") end)
    inner:SetCallback("OnLeave", function() widget:Fire("OnLeave") end)

    -- the dim region over the track beyond the bound: on the slider itself, under its thumb
    local black = Colors().BLACK
    local dim = inner.slider:CreateTexture(nil, "ARTWORK", nil, -1)
    dim:SetColorTexture(black[1], black[2], black[3], DIM)
    dim:Hide()
    widget.dim = dim

    -- the gold tick on the dim region's left edge, and the notch ticks, made as needed
    widget.tick = NewTick(inner.slider)
    widget.notchTicks = {}

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
