-- Soul Shard Forever (SSF). MIT, see LICENSE.
--
-- Welcome: the first-load welcome. The first time a character loads SSF, the window opens
-- by itself with a note beside it: the help button, every way to delete, and the button
-- that makes the macros. Once per WELCOME_VERSION, so players updating from an SSF with an
-- older note see the new one once too. Waits for the loading screen to go, so the window
-- opens into a drawn, shown UI. The main window's "Create macros" shows the same note.
--
-- Listens: SSF_SHOW_WELCOME (Window's "Create macros").
--
-- Reads:  profile.welcomed. Calls Options:IsHelpOn(), Options:ToggleHelp(),
--         Window:ShowNote(), DeleteHelp:Text(), Macros:Create() (the note's button).
--         Touches nothing else.
-- Saves:  profile.welcomed = WELCOME_VERSION once the welcome has shown at load.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Welcome = SSF:NewModule("Welcome", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("SoulShardForever")

-- The welcome's version, two digits per part (Blizzard's ## Interface scheme): 1.8 = 10800.
-- Raised only when the note changes, so players see a changed note once; 1.8.1 leaves it.
local WELCOME_VERSION = 10800

-- The note: the pointer at the help button, the gold line, every way to delete with the two
-- macros (DeleteHelp), and the button that makes them (Macros). Always the same box.
function Welcome:Show()
    local Macros = SSF:GetModule("Macros")
    SSF:GetModule("Window"):ShowNote(L["Welcome to SSF"], L["Click for in-game tooltip help."],
        L["You won't see this welcome screen again on this character unless you click Create macros in the UI."],
        {
            extra = SSF:GetModule("DeleteHelp"):Text(L["Use your keybind, click Delete Shard, bottom left in the UI, use a macro, or mix and match. Deletes one Soul Shard if you are over the cap."]),
            button = L["Create recommended macros"],
            onClick = function() Macros:Create() end,
            buttonNote = L["Creates the macros, reloads your UI and opens the macro box after the reload."],
            buttonDisabled = not Macros:AnyMissing(), -- both made already: nothing to do
        })
end

function Welcome:LOADING_SCREEN_DISABLED()
    self:UnregisterEvent("LOADING_SCREEN_DISABLED")
    SSF.db.profile.welcomed = WELCOME_VERSION
    -- first run starts with help on: the "i" shows blue, and every option explains itself
    local Options = SSF:GetModule("Options")
    if not Options:IsHelpOn() then Options:ToggleHelp() end
    self:Show()
end

-- Setup lives in OnEnable, not OnInitialize: Core's warlock gate switches modules off
-- before OnEnable, so other classes never get the welcome.
function Welcome:OnEnable()
    -- 1.7 saved true; true, false or nothing all count as older than any version number
    local seen = SSF.db.profile.welcomed
    if type(seen) ~= "number" or seen < WELCOME_VERSION then
        self:RegisterEvent("LOADING_SCREEN_DISABLED")
    end
    -- the main window's "Create macros": the same note, welcomed untouched
    self:RegisterMessage("SSF_SHOW_WELCOME", "Show")
end
