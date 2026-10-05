-- Soul Shard Forever (SSF). MIT, see LICENSE.
--
-- Three AceGUI widgets that reposition their stock counterpart, for use from the options
-- table through `dialogControl`. AceConfigDialog drives them exactly like the originals.
--   SSFCenteredLabel    : a Label with centered text (the status line).
--   SSFCenteredCheckBox : a CheckBox sized to its text and centered in its row.
--   SSFIndentCheckBox   : a CheckBox inset 10px from the left, so it sits inside its group.
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
-- SSFCenteredLabel
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
-- SSFIndentCheckBox
-------------------------------------------------------------------------------
do
    local Type, Version = "SSFIndentCheckBox", 1
    local INDENT = 10

    -- the inner box fills the row past the indent; the label wraps at the row's edge and the
    -- row grows, with the box centered vertically so the (box-centered) label stays inside
    local function Fit(self, width)
        local inner, text = self.inner, self.inner.text
        inner:SetWidth(width - INDENT)
        text:SetWordWrap(true)
        text:SetWidth(width - INDENT - 24)
        local height = math.max(24, text:GetStringHeight() + 4)
        self:SetHeight(height)
        inner.frame:ClearAllPoints()
        inner.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", INDENT, -(height - 24) / 2)
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
            self.inner:SetLabel("")
        end,
        ["OnWidthSet"] = function(self, width) Fit(self, width) end,
        ["SetLabel"] = function(self, text)
            self.inner:SetLabel(text)
            if self.frame.width then Fit(self, self.frame.width) end
        end,
        ["SetValue"] = function(self, value) self.inner:SetValue(value) end,
        ["GetValue"] = function(self) return self.inner:GetValue() end,
        ["SetTriState"] = function(self, v) self.inner:SetTriState(v) end,
        ["SetDisabled"] = function(self, v) self.inner:SetDisabled(v) end,
        ["SetDescription"] = function(self, v) self.inner:SetDescription(v) end,
        ["SetType"] = function(self, v) self.inner:SetType(v) end,
        ["SetImage"] = function(self, ...) self.inner:SetImage(...) end,
    }

    local function Constructor()
        local frame = CreateFrame("Frame", nil, UIParent)
        local widget = { frame = frame, type = Type }
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
