-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Five AceGUI widgets that reposition their stock counterpart, for use from the options
-- table through `dialogControl`. AceConfigDialog drives them exactly like the originals.
--   SSFCountButton      : a Button with a line of large text before it, the pair centered
--                         in its row (the count and Delete Shard), and a small gold reason
--                         under the button (why it is greyed). For an `execute` option: its
--                         name is the button's label, its `arg` a function that returns the
--                         text and the reason (nil for none), its `disabled` greys it.
--   SSFCenteredLabel    : a Label with centered text. Unused since the count line became
--                         SSFCountButton; kept in case a centered line is needed again.
--   SSFCenteredCheckBox : a CheckBox sized to its text and centered in its row.
--   SSFUnlabeledDropdown: a Dropdown whose label never shows; its name is only the title
--                         of its tooltip.
--   SSFIndentCheckBox   : a CheckBox inset 10px from the left, so it sits inside its group.
--                         An option's `arg` sets the indent level (2 = 20px); no `arg` is
--                         level 1. AceConfigDialog hands `arg` to SetCustomData. Not full
--                         width (sharing a row), it is as wide as its label on one line.
-- SSFCountButton, SSFCenteredLabel and SSFIndentCheckBox report MinWidth(): the width
-- their text needs on one line, which SSFWindow:FitWidth sizes the window to.
-- All are built by composition: the real widget sits inside ours and every call is
-- forwarded, the same pattern as SSFStepperSlider.
--
-- Both check boxes grow instead of truncating: a label that does not fit the row wraps,
-- and the row's height follows the wrapped text (the Flow layout reads a full-width child's
-- height after setting its width). The inner AceGUI CheckBox keeps its 24px box and its own
-- label anchors, which center the label on the box; our wrapper centers the box vertically
-- in a frame tall enough for the text. A one-line label measures under 24px, so short labels
-- are pixel-identical to the stock widget.

local AceGUI = LibStub("AceGUI-3.0")

-------------------------------------------------------------------------------
-- SSFCountButton
-------------------------------------------------------------------------------
do
    local Type, Version = "SSFCountButton", 3
    local GAP = 12     -- px between the text and the button
    local REASON_GAP = 2 -- px between the button and the reason under it
    local BELOW = 6    -- air under the reason line, before the first group

    -- the text, then the button right after it, the pair centered in the row; the reason
    -- under the button, its line's height kept even when empty, so nothing moves. The
    -- button sizes itself to its label: the stock Button's autoWidth.
    local function Layout(self)
        local width = self.frame.width or self.frame:GetWidth() or 0
        local button = self.inner
        local textWidth = self.label:GetUnboundedStringWidth() or 0
        local total = textWidth + GAP + button.frame:GetWidth()
        local height = math.max(self.label:GetStringHeight() or 0, button.frame:GetHeight() or 24)
        self.label:ClearAllPoints()
        self.label:SetPoint("TOPLEFT", self.frame, "TOPLEFT", math.max(0, (width - total) / 2),
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
            self:SetWidth(200)
            self.label:SetText("")
            self.reason:SetText("")
            self.inner:SetText("")
            self.inner:SetDisabled(false)
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
        ["SetDisabled"] = function(self, v) self.inner:SetDisabled(v) end,
        -- the width the pair needs on one line (SSFWindow:FitWidth)
        ["MinWidth"] = function(self)
            return (self.label:GetUnboundedStringWidth() or 0) + GAP + (self.inner.frame:GetWidth() or 0)
        end,
    }

    local function Constructor()
        local frame = CreateFrame("Frame", nil, UIParent)
        local widget = { frame = frame, type = Type }
        widget.label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        widget.reason = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") -- gold
        local inner = AceGUI:Create("Button")
        inner:SetAutoWidth(true) -- held for the widget's life, never re-acquired, so this sticks
        inner.frame:SetParent(frame)
        inner.frame:Show()
        widget.inner = inner
        inner:SetCallback("OnClick", function(_, _, ...) widget:Fire("OnClick", ...) end)
        inner:SetCallback("OnEnter", function() widget:Fire("OnEnter") end)
        inner:SetCallback("OnLeave", function() widget:Fire("OnLeave") end)
        for method, func in pairs(methods) do widget[method] = func end
        return AceGUI:RegisterAsWidget(widget)
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end

-------------------------------------------------------------------------------
-- SSFCenteredLabel (unused for now, kept for reuse)
-------------------------------------------------------------------------------
do
    local Type, Version = "SSFCenteredLabel", 1

    local function SyncHeight(self)
        self:SetHeight(self.inner.frame.height or self.inner.frame:GetHeight() or 1)
    end

    local methods = {
        ["OnAcquire"] = function(self)
            self.inner:SetText()
            self.inner:SetImage(nil)
            self.inner:SetColor()
            self.inner:SetFontObject()
            self.inner:SetJustifyH("CENTER")
            self:SetWidth(200)
        end,
        ["OnWidthSet"] = function(self, width)
            self.inner:SetWidth(width)
            SyncHeight(self)
        end,
        ["SetText"] = function(self, text) self.inner:SetText(text) SyncHeight(self) end,
        ["SetFontObject"] = function(self, font) self.inner:SetFontObject(font) SyncHeight(self) end,
        ["SetColor"] = function(self, ...) self.inner:SetColor(...) end,
        ["SetImage"] = function(self, ...) self.inner:SetImage(...) SyncHeight(self) end,
        ["SetImageSize"] = function(self, ...) self.inner:SetImageSize(...) SyncHeight(self) end,
        -- the width the text needs on one line (SSFWindow:FitWidth)
        ["MinWidth"] = function(self) return self.inner.label:GetUnboundedStringWidth() or 0 end,
    }

    local function Constructor()
        local frame = CreateFrame("Frame", nil, UIParent)
        local widget = { frame = frame, type = Type }
        local inner = AceGUI:Create("Label")
        inner.frame:SetParent(frame)
        inner.frame:ClearAllPoints()
        inner.frame:SetPoint("TOPLEFT")
        inner.frame:SetPoint("TOPRIGHT")
        inner.frame:Show()
        widget.inner = inner
        for method, func in pairs(methods) do widget[method] = func end
        return AceGUI:RegisterAsWidget(widget)
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end

-------------------------------------------------------------------------------
-- SSFCenteredCheckBox
-------------------------------------------------------------------------------
do
    local Type, Version = "SSFCenteredCheckBox", 1

    -- size the inner checkbox to its text and park it in the middle of our row; a label wider
    -- than the row takes the full row width, wraps, and the row grows to fit
    local function Fit(self)
        local width = self.frame.width or self.frame:GetWidth() or 0
        local inner, text = self.inner, self.inner.text
        text:SetWordWrap(false)
        local textwidth = (text:GetStringWidth() or 0) + 30
        local height = 24
        if textwidth <= width then
            inner:SetWidth(textwidth)
        else
            inner:SetWidth(width)
            text:SetWordWrap(true)
            text:SetWidth(width - 24)
            height = math.max(24, text:GetStringHeight() + 4)
        end
        self:SetHeight(height)
        inner.frame:ClearAllPoints()
        inner.frame:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
    end

    local methods = {
        ["OnAcquire"] = function(self)
            self:SetWidth(200)
            self:SetHeight(24)
            self.inner:SetType()
            self.inner:SetValue(false)
            self.inner:SetTriState(nil)
            self.inner:SetDisabled(false)
            self.inner:SetDescription(nil)
            self.inner:SetImage(nil)
            self:SetLabel("")
        end,
        ["OnWidthSet"] = function(self) Fit(self) end,
        ["SetLabel"] = function(self, text) self.inner:SetLabel(text) Fit(self) end,
        ["SetValue"] = function(self, value) self.inner:SetValue(value) end,
        ["GetValue"] = function(self) return self.inner:GetValue() end,
        ["SetTriState"] = function(self, v) self.inner:SetTriState(v) end,
        ["SetDisabled"] = function(self, v) self.inner:SetDisabled(v) end,
        ["SetDescription"] = function(self, v) self.inner:SetDescription(v) end,
        ["SetType"] = function(self, v) self.inner:SetType(v) end,
        ["SetImage"] = function(self, ...) self.inner:SetImage(...) Fit(self) end,
    }

    local function Constructor()
        local frame = CreateFrame("Frame", nil, UIParent)
        local widget = { frame = frame, type = Type }
        local inner = AceGUI:Create("CheckBox")
        inner.frame:SetParent(frame)
        inner.frame:Show()
        inner.text:SetHeight(0) -- auto height, so a wrapped label shows every line
        widget.inner = inner
        inner:SetCallback("OnValueChanged", function(_, _, value) widget:Fire("OnValueChanged", value) end)
        inner:SetCallback("OnEnter", function() widget:Fire("OnEnter") end)
        inner:SetCallback("OnLeave", function() widget:Fire("OnLeave") end)
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
    local Type, Version = "SSFIndentCheckBox", 3
    local INDENT = 10 -- one indent level, in px
    local BOX = 24    -- the stock CheckBox's box; its label starts right of it
    local GAP = 12    -- after the label, when the checkbox shares its row: air before the next control

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
        local height = math.max(BOX, text:GetStringHeight() + 4)
        self:SetHeight(height)
        inner.frame:ClearAllPoints()
        inner.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", indent, -(height - BOX) / 2)
    end

    local methods = {
        ["OnAcquire"] = function(self)
            -- AceGUI pools widgets: back to level 1, or a deeper indent leaks to another row
            self.indent = INDENT
            self:SetWidth(200)
            self:SetHeight(24)
            self.inner:SetType()
            self.inner:SetValue(false)
            self.inner:SetTriState(nil)
            self.inner:SetDisabled(false)
            self.inner:SetDescription(nil)
            self.inner:SetImage(nil)
            self.inner:SetLabel("")
        end,
        ["OnWidthSet"] = function(self, width) Fit(self, width) end,
        ["SetLabel"] = function(self, text)
            self.inner:SetLabel(text)
            if self.frame.width then Fit(self, self.frame.width) end
        end,
        -- the width this checkbox needs to show its label on one line (SSFWindow:FitWidth)
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
        inner:SetCallback("OnEnter", function() widget:Fire("OnEnter") end)
        inner:SetCallback("OnLeave", function() widget:Fire("OnLeave") end)
        for method, func in pairs(methods) do widget[method] = func end
        return AceGUI:RegisterAsWidget(widget)
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end
