-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- SSFIndentRadio: SSFIndentCheckBox drawn as a radio button, for use from the options table
-- through `dialogControl` on a `toggle` option. The widget is looks only: the stock
-- CheckBox's own "radio" type (round art, a dot), with SSFIndentCheckBox's indent, wrapping
-- label and tooltip on a greyed control. Which radio of a pair has the dot, and what a
-- click saves, is the options table's (Options, the counter's place). AceConfig's own radio
-- form (a `select` with style "radio") is not used: AceConfigDialog draws it as stock check
-- boxes inside a titled box of their own, with no `dialogControl`, and can grey the whole
-- option but never one choice.
-- It is an SSFIndentCheckBox instance, built by that widget's own constructor and re-typed
-- so it pools under this type, with one method wrapped: OnAcquire, which ends in
-- SetType("radio") (the stock reset puts the check box art back on every acquire).
--
-- Public:  everything SSFIndentCheckBox has (Widgets\SSFCentered.lua); `arg` is the indent
--          level.
-- Lib internals: AceGUI.WidgetRegistry (the SSFIndentCheckBox constructor; the re-typed
--          widget keeps the version it was made from). An AceGUI that renames the registry
--          breaks this widget's construction: the two radios in the counter group are
--          missing and AceConfigDialog errors on the window. Loaded after SSFCentered.lua
--          (the toc order), which registers the type it wraps.
-- Touches nothing else.

local AceGUI = LibStub("AceGUI-3.0")

local Type, Version = "SSFIndentRadio", 1

local function Constructor()
    local widget = AceGUI.WidgetRegistry["SSFIndentCheckBox"]()
    widget.type = Type
    local checkBoxOnAcquire = widget.OnAcquire
    widget.OnAcquire = function(self)
        checkBoxOnAcquire(self)
        self:SetType("radio")
    end
    return widget
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
