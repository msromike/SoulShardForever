-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- SSFCentered: three AceGUI widgets that reposition their stock counterpart, for use from
-- the options table through `dialogControl`. AceConfigDialog drives them exactly like the
-- originals.
--   SSFCountButton      : a Button with a line of large text before it, the pair centered
--                         in its row (the count and Delete Shard), and a small gold reason
--                         under the button (why it is greyed). For an `execute` option: its
--                         name is the button's label, its `arg` a function that returns the
--                         text and the reason (nil for none), its `disabled` greys it.
--                         Greyed, it still shows its tooltip on hover.
--   SSFUnlabeledDropdown: a Dropdown whose label never shows; its name is only the title
--                         of its tooltip.
--   SSFIndentCheckBox   : a CheckBox inset 10px from the left, so it sits inside its group.
--                         An option's `arg` sets the indent level (2 = 20px); no `arg` is
--                         level 1. AceConfigDialog hands `arg` to SetCustomData. Not full
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
--          SetDisabled, SetDescription, SetType, SetImage; SetCustomData(level); MinWidth().
--          MinWidth() is the width the text needs on one line, which SSFFrame:FitWidth
--          sizes the window to.
-- Lib internals: the stock Button's text and frame, the stock CheckBox's text and frame,
--          and AceGUI.WidgetRegistry (the Dropdown constructor, for the re-typed one). An
--          AceGUI bump that renames those breaks the top row and the check boxes' layout.
-- Reads:   nothing of SSF's.
-- Touches nothing else.

local AceGUI = LibStub("AceGUI-3.0")

-- the inner widget's OnEnter/OnLeave become ours (the window's tooltips hang on them)
local function ForwardHover(inner, widget)
    inner:SetCallback("OnEnter", function() widget:Fire("OnEnter") end)
    inner:SetCallback("OnLeave", function() widget:Fire("OnLeave") end)
end

-------------------------------------------------------------------------------
-- SSFCountButton
-------------------------------------------------------------------------------
do
    local Type, Version = "SSFCountButton", 4
    local GAP = 12     -- px between the text and the button
    local REASON_GAP = 2 -- px between the button and the reason under it
    local BELOW = 6    -- air under the reason line, before the first group

    -- the text and the button side by side, on one line
    local function PairWidth(self)
        return (self.label:GetUnboundedStringWidth() or 0) + GAP + (self.inner.frame:GetWidth() or 0)
    end

    -- the text, then the button right after it, the pair centered in the row; the reason
    -- under the button, its line's height kept even when empty, so nothing moves. The
    -- button sizes itself to its label: the stock Button's autoWidth.
    local function Layout(self)
        local width = self.frame.width or self.frame:GetWidth() or 0
        local button = self.inner
        local height = math.max(self.label:GetStringHeight() or 0, button.frame:GetHeight() or 24)
        self.label:ClearAllPoints()
        self.label:SetPoint("TOPLEFT", self.frame, "TOPLEFT", math.max(0, (width - PairWidth(self)) / 2),
            -(height - (self.label:GetStringHeight() or 0)) / 2)
        button.frame:ClearAllPoints()
        button.frame:SetPoint("LEFT", self.label, "RIGHT", GAP, 0)
        self.reason:ClearAllPoints()
        self.reason:SetPoint("TOP", button.frame, "BOTTOM", 0, -REASON_GAP)
        local _, size = self.reason:GetFont()
        self:SetHeight(height + REASON_GAP + (size or 10) + BELOW)
    end

    local methods = {
        ["OnAcquire"] = function(self)
            self.inner:OnAcquire() -- the stock reset, which turns autoWidth off
            self.inner:SetAutoWidth(true)
            self:SetWidth(200)
            self.label:SetText("")
            self.reason:SetText("")
        end,
        ["OnWidthSet"] = function(self) Layout(self) end,
        -- the option's name: the button's label
        ["SetText"] = function(self, text) self.inner:SetText(text) Layout(self) end,
        -- the option's `arg`: a function returning the text before the button and the
        -- reason under it (nil for none)
        ["SetCustomData"] = function(self, getText)
            local text, reason
            if type(getText) == "function" then text, reason = getText() end
            self.label:SetText(text or "")
            self.reason:SetText(reason or "")
            Layout(self)
        end,
        -- Greyed, the button still answers a hover with its tooltip (what it does, and the
        -- reason sits under it in gold): a disabled button blocks the mouse without using
        -- it, so the mouse is let through to the widget's own frame, which fires OnEnter.
        ["SetDisabled"] = function(self, v)
            self.inner:SetDisabled(v)
            self.inner.frame:EnableMouse(not v)
            self.frame:EnableMouse(v and true or false)
        end,
        ["MinWidth"] = function(self) return PairWidth(self) end,
    }

    local function Constructor()
        local frame = CreateFrame("Frame", nil, UIParent)
        local widget = { frame = frame, type = Type }
        widget.label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        widget.reason = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") -- gold
        local inner = AceGUI:Create("Button")
        inner.frame:SetParent(frame)
        inner.frame:Show()
        widget.inner = inner
        inner:SetCallback("OnClick", function(_, _, ...) widget:Fire("OnClick", ...) end)
        ForwardHover(inner, widget)
        frame:SetScript("OnEnter", function() widget:Fire("OnEnter") end)
        frame:SetScript("OnLeave", function() widget:Fire("OnLeave") end)
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
    local Type, Version = "SSFUnlabeledDropdown", 1

    local function Constructor()
        local widget = AceGUI.WidgetRegistry["Dropdown"]()
        widget.type = Type
        local stockSetLabel = widget.SetLabel
        widget.SetLabel = function(self) stockSetLabel(self, nil) end -- nil: the stock no-label layout
        return widget
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end

-------------------------------------------------------------------------------
-- SSFIndentCheckBox
-------------------------------------------------------------------------------
do
    local Type, Version = "SSFIndentCheckBox", 4
    local INDENT = 10 -- one indent level, in px
    local BOX = 24    -- the stock CheckBox's box; its label starts right of it
    local GAP = 12    -- after the label, when the checkbox shares its row: air before the next control
    local WRAP_PAD = 4 -- px of row under a wrapped label

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
        self:SetHeight(height)
        inner.frame:ClearAllPoints()
        inner.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", indent, -(height - BOX) / 2)
    end

    local methods = {
        ["OnAcquire"] = function(self)
            self.inner:OnAcquire() -- the stock reset: type, value, tri-state, image, enabled, description
            self.inner:SetLabel("")
            -- AceGUI pools widgets: back to level 1, or a deeper indent leaks to another row
            self.indent = INDENT
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
        ["SetDisabled"] = function(self, v) self.inner:SetDisabled(v) end,
        ["SetDescription"] = function(self, v) self.inner:SetDescription(v) end,
        ["SetType"] = function(self, v) self.inner:SetType(v) end,
        ["SetImage"] = function(self, ...) self.inner:SetImage(...) end,
        -- the option's `arg`: the indent level (AceConfigDialog InjectInfo calls this)
        ["SetCustomData"] = function(self, level)
            self.indent = INDENT * (tonumber(level) or 1)
            if self.frame.width then Fit(self, self.frame.width) end
        end,
    }

    local function Constructor()
        local frame = CreateFrame("Frame", nil, UIParent)
        local widget = { frame = frame, type = Type, indent = INDENT }
        local inner = AceGUI:Create("CheckBox")
        inner.frame:SetParent(frame)
        inner.frame:ClearAllPoints()
        inner.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", INDENT, 0)
        inner.frame:Show()
        inner.text:SetHeight(0) -- auto height, so a wrapped label shows every line
        widget.inner = inner
        inner:SetCallback("OnValueChanged", function(_, _, value) widget:Fire("OnValueChanged", value) end)
        ForwardHover(inner, widget)
        for method, func in pairs(methods) do widget[method] = func end
        return AceGUI:RegisterAsWidget(widget)
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end
