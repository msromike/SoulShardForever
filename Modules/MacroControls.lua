-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- MacroControls: the macro controls a note carries: the tick box for the macros' one
-- option ("Have the macro stop your wand") and the button that makes the recommended
-- macros or brings them in line with it, with the green line above the button. Hands them
-- over as fields for a note's options (Welcome's note, opened at first load and at any time
-- from the main window's "Macros"); it draws nothing itself and owns no note.
--   The button says what its click will do (Macros:Pending): "Create recommended macros",
-- "Update macros", or a greyed "Macros are up to date". The green "Reloads your UI" stands
-- above it only when the click will reload (Macros:Reloads); otherwise that line is kept,
-- blank, deliberate: the button stays where it is when the words come and go. The tick
-- changes the option, which changes the macros shown and what the button will do; only the
-- click writes a macro. After a tick, after a click that reloaded nothing, and whenever the
-- player's macros change, the note's owner is asked to fill the note again, so the
-- controls show what is true now.
--
-- Public:  Fields(refill) -> the fields for a note's options (SSFSideNote:Show): tick,
--          ticked, onTick, button, buttonLabels, buttonDisabled, onClick, buttonNote.
--          refill: the owner's function that fills its note again; kept, and called as
--          said above (the owner decides whether its note is open).
-- Listens: SSF_MACROS_CHANGED (the owner fills its note again).
-- Reads:   Macros:Pending/Reloads/Create/StopWand/SetStopWand (Create's return is the
--          click's command); Colors:Paint and Colors.GREEN (the line above the button).
-- Touches nothing else.

local ADDON = ...
local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local MacroControls = SSF:NewModule("MacroControls", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)

function MacroControls:Fields(refill)
    local Macros, Colors = SSF:GetModule("Macros"), SSF:GetModule("Colors")
    local pending = Macros:Pending()
    self.refill = refill
    return {
        tick = L["Have the macro stop your wand"],
        ticked = Macros:StopWand(),
        onTick = function(ticked)
            Macros:SetStopWand(ticked)
            refill()
        end,
        -- as wide as the widest of its three labels, so it keeps its size
        button = pending == "create" and L["Create recommended macros"]
            or pending == "update" and L["Update macros"] or L["Macros are up to date"],
        buttonLabels = { L["Create recommended macros"], L["Update macros"], L["Macros are up to date"] },
        buttonDisabled = pending == nil,
        -- a click that made no macro reloads nothing: the note is filled again, so the
        -- button shows what is left to do
        onClick = function()
            local command = Macros:Create()
            if not command then refill() end
            return command
        end,
        buttonNote = Macros:Reloads() and Colors:Paint(Colors.GREEN, L["Reloads your UI"]) or " ",
    }
end

-- The player's macros changed (one made, deleted or edited, by anyone): the button may say
-- something else now.
function MacroControls:OnMacrosChanged()
    if self.refill then self.refill() end
end

-- Setup lives in OnEnable, not OnInitialize: Core's warlock gate switches modules off
-- before OnEnable.
function MacroControls:OnEnable()
    self:RegisterMessage("SSF_MACROS_CHANGED", "OnMacrosChanged")
end
