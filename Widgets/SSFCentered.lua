-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- SSFCentered: three AceGUI widgets that reposition their stock counterpart, for use from
-- the options table through `dialogControl`. AceConfigDialog drives them exactly like the
-- originals.
--   SSFCountButton      : a Button with a line of large text before it, the pair centered
--                         in its row (the count and Delete Shard). The button is one fixed
--                         size, tall enough for two lines and wide enough for its longest:
--                         its label alone sits centered, a reason (why it is greyed) goes
--                         on the line under the label. For an `execute` option: its name
--                         is the button's label, its `arg` a function that returns the
--                         text, the reason (nil for none) and a list of every reason it
--                         can show, its `disabled` greys it. Greyed, it still shows its
--                         tooltip on hover.
--   SSFUnlabeledDropdown: a Dropdown whose label never shows; its name is only the title
--                         of its tooltip.
--   SSFIndentCheckBox   : a CheckBox inset 10px from the left, so it sits inside its group.
--                         An option's `arg` sets the indent level (2 = 20px); no `arg` is
--                         level 1. A table `arg`, { level = 2, radio = true }, also draws
--                         it as a radio button: the stock CheckBox's own "radio" type,
--                         centered in the check box's square so its rows line up with the
--                         check box rows; looks only (which radio of a pair has the dot, and what a click
--                         saves, is the options table's). The table's `after` adds half a
--                         line (HALF_LINE) of empty row under the control; `follows` marks the second
--                         choice on a shared row, one check box width (CHOICE_GAP) after the
--                         first choice's label. AceConfig's own radio form, a
--                         `select` with style "radio", takes no `dialogControl`, draws a
--                         titled box of its own and cannot grey one choice.
--                         AceConfigDialog hands `arg` to SetCustomData. Not full
--                         width (sharing a row), it is as wide as its label on one line.
--                         A label that does not fit the row wraps and the row's height
--                         follows the wrapped text (the Flow layout reads a full-width
--                         child's height after setting its width). The inner CheckBox
--                         keeps its 24px box and its own label anchors, which center the
--                         label on the box; the wrapper centers the box vertically in a
--                         frame tall enough for the text. A one-line label measures under
--                         24px, so short labels are pixel-identical to the stock widget.
-- Two are built by composition: the real widget sits inside ours, is reset through its
-- own OnAcquire, and every call is forwarded, the same pattern as SSFStepperSlider.
-- SSFUnlabeledDropdown is not: it is a stock Dropdown instance re-typed with one method
-- replaced (see its block).
--
-- Public:  SSFCountButton: SetText, SetCustomData(getText), SetDisabled, MinWidth();
--          SSFIndentCheckBox: the CheckBox's SetLabel, SetValue, GetValue, SetTriState,
--          SetDisabled, SetDescription, SetType, SetImage; SetCustomData(level, or
--          { level, radio, after, follows }); MinWidth().
--          MinWidth() is the width the text needs on one line, which SSFFrame:FitWidth
--          sizes the window to.
-- Lib internals: the stock Button's frame, the stock CheckBox's text and frame, AceGUI's
--          frame.width field (read, and written by the check box's Fit) and the widget's
--          own width field (read for "fill"), and AceGUI.WidgetRegistry (the Dropdown
--          constructor, for the re-typed one; the re-typed widget keeps the Dropdown
--          version it was made from, so a newer Dropdown loaded later in the session never
--          reaches it). The stock Dropdown's frame, button and button_cover and its
--          SetDisabled (wrapped, stock first). The Button's and CheckBox's frame and the
--          Dropdown's button and button_cover are handed to Help:KeepHover as the frames
--          that give up the mouse while greyed; a stock widget that moves its mouse to
--          another frame leaves a greyed control silent again. The inner widget's
--          OnAcquire is called directly, outside
--          AceGUI:Create, as a full repeatable reset. The CheckBox's text FontString is
--          also written (height 0, word wrap, width) so a label can wrap; BOX copies the
--          stock checkbg size and RADIO the stock radio art's. For a radio, the CheckBox's
--          checkbg (TOPLEFT) and text (LEFT) anchors are written, and put back on acquire;
--          a CheckBox that anchors them differently leaves the radios off the check boxes'
--          column. An AceGUI bump that renames those breaks the top row, the
--          check boxes' layout, or the volume dropdown's construction; one whose CheckBox
--          re-sets its text height clips wrapped labels.
-- Reads:   Help:KeepHover/Greyed (the tooltip on a greyed control).
-- Touches nothing else.

local AceGUI = LibStub("AceGUI-3.0")

-- SSF's Help module (the addon is loaded by the time a widget is made)
local function Help() return LibStub("AceAddon-3.0"):GetAddon("SSF"):GetModule("Help") end

-- the inner widget's OnEnter/OnLeave become ours (the window's tooltips hang on them)
local function ForwardHover(inner, widget)
    inner:SetCallback("OnEnter", function() widget:Fire("OnEnter") end)
    inner:SetCallback("OnLeave", function() widget:Fire("OnLeave") end)
end

-------------------------------------------------------------------------------
-- SSFCountButton
-------------------------------------------------------------------------------
do
    local Type, Version = "SSFCountButton", 6
    local GAP = 12     -- px between the text and the button
    local HEIGHT = 36  -- the button: two lines of text
    local ROOM = 400   -- the button's width while measuring, so no line wraps
    local BELOW = 6    -- air under the button, before the first group

    -- the text and the button side by side, on one line
    local function PairWidth(self)
        return (self.label:GetUnboundedStringWidth() or 0) + GAP + (self.inner.frame:GetWidth() or 0)
    end

    -- the text, then the button right after it, the pair centered in the row
    local function Layout(self)
        local width = self.frame.width or self.frame:GetWidth() or 0
        local button = self.inner
        local height = math.max(self.label:GetStringHeight() or 0, button.frame:GetHeight() or 24)
        self.label:ClearAllPoints()
        self.label:SetPoint("TOPLEFT", self.frame, "TOPLEFT", math.max(0, (width - PairWidth(self)) / 2),
            -(height - (self.label:GetStringHeight() or 0)) / 2)
        button.frame:ClearAllPoints()
        button.frame:SetPoint("LEFT", self.label, "RIGHT", GAP, 0)
        self:SetHeight(height + BELOW)
    end

    -- the button's width: its longest line in any state, so it never changes size. The stock
    -- Button's autoWidth sizes it to each line in turn and the widest is kept, then the face
    -- is written over it: the label, and the reason under it when there is one.
    local function Refresh(self)
        local inner, widest = self.inner, 0
        local function Measure(line)
            inner:SetWidth(ROOM)
            inner:SetText(line)
            widest = math.max(widest, inner.frame:GetWidth() or 0)
        end
        inner:SetAutoWidth(true)
        Measure(self.name or "")
        for _, reason in ipairs(self.reasons or {}) do Measure(reason) end
        inner:SetAutoWidth(false)
        inner:SetWidth(widest)
        inner:SetText(self.reason and ((self.name or "") .. "\n" .. self.reason) or self.name)
        Layout(self)
    end

    local methods = {
        ["OnAcquire"] = function(self)
            self.inner:OnAcquire() -- the stock reset, which turns autoWidth off
            self.inner:SetHeight(HEIGHT)
            self:SetWidth(200)
            self.label:SetText("")
            self.name, self.reason, self.reasons = nil, nil, nil
        end,
        ["OnWidthSet"] = function(self) Layout(self) end,
        -- the option's name: the button's label
        ["SetText"] = function(self, text) self.name = text Refresh(self) end,
        -- the option's `arg`: a function returning the text before the button, the reason
        -- on it (nil for none) and every reason it can show
        ["SetCustomData"] = function(self, getText)
            local text, reason, reasons
            if type(getText) == "function" then text, reason, reasons = getText() end
            self.label:SetText(text or "")
            self.reason, self.reasons = reason, reasons
            Refresh(self)
        end,
        -- greyed, the button still answers a hover with its tooltip (what it does, and the
        -- reason on its face): Help hands the hover to the widget's own frame
        ["SetDisabled"] = function(self, v)
            self.inner:SetDisabled(v)
            Help():Greyed(self, v)
        end,
        ["MinWidth"] = function(self) return PairWidth(self) end,
    }

    local function Constructor()
        local frame = CreateFrame("Frame", nil, UIParent)
        local widget = { frame = frame, type = Type }
        widget.label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        local inner = AceGUI:Create("Button")
        inner.frame:SetParent(frame)
        inner.frame:Show()
        widget.inner = inner
        inner:SetCallback("OnClick", function(_, _, ...) widget:Fire("OnClick", ...) end)
        ForwardHover(inner, widget)
        Help():KeepHover(widget, frame, { inner.frame })
        for method, func in pairs(methods) do widget[method] = func end
        return AceGUI:RegisterAsWidget(widget)
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end

-------------------------------------------------------------------------------
-- SSFUnlabeledDropdown
-------------------------------------------------------------------------------
-- The stock Dropdown, built by its own constructor and re-typed so it pools under this
-- type, that never shows its label: the option still has a name, which AceConfigDialog
-- puts at the top of the option's tooltip, but the row stays a bare dropdown beside the
-- control it belongs to (the pause volume beside Play pause sound).
do
    local Type, Version = "SSFUnlabeledDropdown", 2

    local function Constructor()
        local widget = AceGUI.WidgetRegistry["Dropdown"]()
        widget.type = Type
        local stockSetLabel = widget.SetLabel
        widget.SetLabel = function(self) stockSetLabel(self, nil) end -- nil: the stock no-label layout
        -- greyed, the stock Dropdown disables its button and its cover and goes silent; the
        -- stock frame under them takes the hover, so a greyed Volume still shows its tooltip
        local stockSetDisabled = widget.SetDisabled
        widget.SetDisabled = function(self, v)
            stockSetDisabled(self, v)
            Help():Greyed(self, v)
        end
        Help():KeepHover(widget, widget.frame, { widget.button, widget.button_cover })
        return widget
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end

-------------------------------------------------------------------------------
-- SSFIndentCheckBox
-------------------------------------------------------------------------------
do
    local Type, Version = "SSFIndentCheckBox", 7
    local INDENT = 10 -- one indent level, in px
    local BOX = 24    -- the stock CheckBox's box; its label starts right of it
    local GAP = 12    -- after the label, when the checkbox shares its row: air before the next control
    local WRAP_PAD = 4 -- px of row under a wrapped label
    local RADIO = 16  -- the stock radio art, smaller than the check box's
    local RADIO_INSET = (BOX - RADIO) / 2 -- the radio art's margin inside the check box's square
    local CHOICE_GAP = BOX -- px from one choice's label to the next choice's button on a shared
                           -- row: one check box width, the window's own unit (Mike, 2026-11-12)
    local HALF_LINE = 5 -- px of empty row under a control with `after`: SSF's own spacing for
                        -- the radio row, the look Mike approved (2026-11-12)

    -- Radio or check box art. The radio is drawn in the middle of the check box's square
    -- (the stock widget pins it to the square's top left), and its label starts where a
    -- check box's label starts, so a radio row lines up with the check box rows around it
    -- and BOX stays true for both. Off puts the stock anchors back (the art itself is
    -- reset by the stock OnAcquire).
    local function SetRadio(self, on)
        local inner = self.inner
        local inset = on and RADIO_INSET or 0
        if on then inner:SetType("radio") end
        inner.checkbg:SetPoint("TOPLEFT", inset, -inset)
        inner.text:SetPoint("LEFT", inner.checkbg, "RIGHT", inset, 0)
    end

    -- the label on one line, in px from the widget's left edge
    local function Natural(self)
        return self.indent + BOX + (self.inner.text:GetUnboundedStringWidth() or 0)
    end

    -- Full width ("fill"): the inner box fills the row past the indent; the label wraps at the
    -- row's edge and the row grows, with the box centered vertically so the (box-centered)
    -- label stays inside. Any other width (a checkbox sharing its row): the widget is as wide
    -- as its label on one line, whatever width it was given, so a longer language widens it
    -- instead of wrapping it.
    local function Fit(self, width)
        local inner, text, indent = self.inner, self.inner.text, self.indent
        if self.width ~= "fill" then
            width = Natural(self) + GAP
            self.frame:SetWidth(width)
            self.frame.width = width
        end
        inner:SetWidth(width - indent)
        text:SetWordWrap(true)
        text:SetWidth(width - indent - BOX)
        local height = math.max(BOX, text:GetStringHeight() + WRAP_PAD)
        self:SetHeight(height + self.after) -- `after`: HALF_LINE under the box, from the option's arg
        inner.frame:ClearAllPoints()
        inner.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", indent, -(height - BOX) / 2)
    end

    local methods = {
        ["OnAcquire"] = function(self)
            self.inner:OnAcquire() -- the stock reset: type, value, tri-state, image, enabled, description
            self.inner:SetLabel("")
            SetRadio(self, false) -- pooled: a radio's anchors must not leak to a check box
            -- AceGUI pools widgets: back to level 1, or a deeper indent leaks to another row
            self.indent = INDENT
            self.after = 0 -- and no space under it
            self:SetWidth(200)
            self:SetHeight(BOX)
        end,
        ["OnWidthSet"] = function(self, width) Fit(self, width) end,
        ["SetLabel"] = function(self, text)
            self.inner:SetLabel(text)
            if self.frame.width then Fit(self, self.frame.width) end
        end,
        ["MinWidth"] = function(self) return Natural(self) end,
        ["SetValue"] = function(self, value) self.inner:SetValue(value) end,
        ["GetValue"] = function(self) return self.inner:GetValue() end,
        ["SetTriState"] = function(self, v) self.inner:SetTriState(v) end,
        ["SetDisabled"] = function(self, v)
            self.inner:SetDisabled(v)
            Help():Greyed(self, v) -- a greyed box still shows its tooltip
        end,
        ["SetDescription"] = function(self, v) self.inner:SetDescription(v) end,
        ["SetType"] = function(self, v) self.inner:SetType(v) end,
        ["SetImage"] = function(self, ...) self.inner:SetImage(...) end,
        -- the option's `arg` (AceConfigDialog InjectInfo calls this): the indent level, or
        -- a table { level = n, radio = true, after = true, follows = true } for a radio
        -- button, a half line of empty row under it, and the second choice on a row.
        -- OnAcquire's stock reset puts the check box art back for the next use
        ["SetCustomData"] = function(self, data)
            self.indent = INDENT * (tonumber(data) or 1)
            if type(data) == "table" then
                self.indent = INDENT * (tonumber(data.level) or 1)
                if data.radio then SetRadio(self, true) end
                self.after = data.after and HALF_LINE or 0
                -- `follows`: the second choice on a row. Its indent is what is left of
                -- CHOICE_GAP after the previous control's GAP and this radio's inset
                if data.follows then
                    self.indent = CHOICE_GAP - GAP - (data.radio and RADIO_INSET or 0)
                end
            end
            if self.frame.width then Fit(self, self.frame.width) end
        end,
    }

    local function Constructor()
        local frame = CreateFrame("Frame", nil, UIParent)
        local widget = { frame = frame, type = Type, indent = INDENT, after = 0 }
        local inner = AceGUI:Create("CheckBox")
        inner.frame:SetParent(frame)
        inner.frame:ClearAllPoints()
        inner.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", INDENT, 0)
        inner.frame:Show()
        inner.text:SetHeight(0) -- auto height, so a wrapped label shows every line
        widget.inner = inner
        inner:SetCallback("OnValueChanged", function(_, _, value) widget:Fire("OnValueChanged", value) end)
        ForwardHover(inner, widget)
        Help():KeepHover(widget, frame, { inner.frame })
        for method, func in pairs(methods) do widget[method] = func end
        return AceGUI:RegisterAsWidget(widget)
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end
