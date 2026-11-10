-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Help: help mode. While on, every option in the window explains itself on hover, greyed
-- or not; while off, none does. Three pieces, one owner:
--   The switch: on or off for the session only (nil at load, so a /reload turns it off,
--     nothing saved). The window's "i" button toggles it (Window wires it), Welcome turns
--     it on for a character that still owes the welcome.
--   The help line: Apply(root) walks the options table Options built and sets every
--     option's descStyle, the only place that value is set: an option with a help line
--     (desc) shows it as a tooltip while help is on, and shows nothing while off; an option
--     without one shows nothing either way, so AceConfigDialog never puts up a name-only
--     tooltip. Chat commands (dialogHidden) are skipped: their desc is AceConfigCmd's help
--     text. descStyle has to be a plain string (AceConfigRegistry), so it is set on every
--     build, and Options rebuilds on every toggle.
--   The hover on a greyed control: the tooltip hangs on the widget's OnEnter, and a greyed
--     stock AceGUI control stops firing it (its Button is disabled: it still blocks the
--     mouse, it just fires no motion scripts). So a greyed control would go silent exactly
--     when a new player needs it most (not paused, counter off, no soul bag: most of the
--     window). KeepHover gives the widget's own wrapper frame the mouse and the OnEnter /
--     OnLeave that fire its callbacks; Greyed takes the mouse off the stock control while
--     it is greyed, so the hover falls through to the wrapper, and gives it back when it
--     is not. Every SSF widget calls both, so greyed means "can't click it", never "can't
--     read what it does".
--
-- Public:  IsOn() -> bool, Toggle(); Apply(root) (Options, at the end of every build);
--          KeepHover(widget, wrapper, innerFrames) (a widget's constructor: wrapper is the
--          widget's own frame, innerFrames the stock frames that take the mouse while
--          enabled), Greyed(widget, disabled) (the widget's SetDisabled, after the stock
--          call).
-- Sends:   SSF_HELP_CHANGED (on) after every Toggle.
-- Lib internals: descStyle = "hidden" is not a value the AceConfig spec names (it has
--          "inline" and "tooltip"); AceConfigDialog treats anything but "tooltip" as no
--          tooltip, and AceConfigRegistry only checks for a string. A registry that
--          validates the value as an enum rejects the whole table: no window, no /ssf.
-- Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Help = SSF:NewModule("Help", "AceEvent-3.0")

function Help:IsOn() return self.on == true end

function Help:Toggle()
    self.on = not self.on
    self:SendMessage("SSF_HELP_CHANGED", self.on)
end

local function ApplyStyle(group, style)
    for _, entry in pairs(group.args) do
        if entry.args then
            ApplyStyle(entry, style)
        elseif not entry.dialogHidden then
            entry.descStyle = entry.desc and style or "hidden"
        end
    end
end

function Help:Apply(root)
    ApplyStyle(root, self.on and "tooltip" or "hidden")
end

function Help:KeepHover(widget, wrapper, innerFrames)
    wrapper:EnableMouse(true)
    wrapper:SetScript("OnEnter", function() widget:Fire("OnEnter") end)
    wrapper:SetScript("OnLeave", function() widget:Fire("OnLeave") end)
    widget.hoverFrames = innerFrames
end

function Help:Greyed(widget, disabled)
    for _, frame in ipairs(widget.hoverFrames or {}) do
        frame:EnableMouse(not disabled)
    end
end
