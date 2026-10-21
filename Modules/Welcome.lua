-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Welcome: the first-load welcome. The first time a character loads SSF, the window opens
-- by itself with a note beside it: the help button, every way to delete, and the button
-- that makes the macros. Once per WELCOME_VERSION, so players updating from an SSF with an
-- older note see the new one once too. Waits for the loading screen to go, so the window
-- opens into a drawn, shown UI. The main window's "Create macros" shows the same note.
--
-- Once shown, the note is owed until the player closes it outside a fight: showing it
-- clears profile.welcomed, and only that close sets it again. So a fight that closes the
-- window and the note with it leaves it owed, and it comes back with the next open of the
-- window, from anywhere, and at the next load or reload.
--
-- Public:  Show() (the note, through Window:ShowNote).
-- Listens: SSF_SHOW_WELCOME (Window's "Create macros"), SSF_WINDOW_OPENED (any open),
--          LOADING_SCREEN_DISABLED once at load while a note is owed.
-- Reads:   profile.welcomed; Options:IsHelpOn/ToggleHelp, Window:ShowNote/InFight,
--          DeleteHelp:Blocks, Macros:AnyMissing/Create (the note's button).
-- Saves:   profile.welcomed: false while the note is owed (set when it shows), and
--          WELCOME_VERSION once the player closes it outside a fight.
-- Touches nothing else.

local ADDON = ...
local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Welcome = SSF:NewModule("Welcome", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)

-- The welcome's version, two digits per part (Blizzard's ## Interface scheme): 1.8 = 10800.
-- Raised only when the note changes, so players see a changed note once. 1.8.1 raises it:
-- the note was redone and Delete Shard moved, so updaters see the window once more.
local WELCOME_VERSION = 10801

-- in a fight: Window's one test (the window and the note close together)
local function InFight() return SSF:GetModule("Window"):InFight() end

-- the note is owed: this version's welcome not yet closed by the player (1.7 saved true;
-- true, false or nothing all count as older than any version number)
local function Owed()
    local seen = SSF.db.profile.welcomed
    return type(seen) ~= "number" or seen < WELCOME_VERSION
end

-- The note: the pointer at the help button, every way to delete with the two macros
-- (DeleteHelp), what the button does, the button that makes them (Macros), and the gold
-- line last. Always the same box. Owed from here until a close outside a fight, saved, so
-- a reload in between still brings it back.
function Welcome:Show()
    if InFight() then return end -- the window stays shut in a fight (Window)
    self.noteOpen = true
    SSF.db.profile.welcomed = false
    local Macros = SSF:GetModule("Macros")
    SSF:GetModule("Window"):ShowNote(L["Welcome to SSF"], L["Click for in-game tooltip help."],
        L["You won't see this welcome screen again on this character unless you click Create macros in the UI."],
        {
            blocks = SSF:GetModule("DeleteHelp"):Blocks(L["SSF deletes one Soul Shard when you're over the cap. Use the Delete Shard keybind, the Delete Shard button, a macro, or mix and match."]),
            button = L["Create recommended macros"],
            onClick = function() Macros:Create() end,
            buttonNote = L["Creates the macros, reloads your UI and opens the macro box after the reload."],
            buttonDisabled = not Macros:AnyMissing(), -- both made already: nothing to do
            onClose = function()
                self.noteOpen = false
                if InFight() then return end -- a fight closed it: still owed
                SSF.db.profile.welcomed = WELCOME_VERSION
            end,
        })
end

-- Any open of the window: a note still owed comes up with it. (ShowNote opens the window
-- too; the note is already marked open by then, so no loop.)
function Welcome:OnWindowOpened()
    if not self.noteOpen and Owed() then self:Show() end
end

function Welcome:LOADING_SCREEN_DISABLED()
    self:UnregisterEvent("LOADING_SCREEN_DISABLED")
    -- first run starts with help on: the "i" shows blue, and every option explains itself
    local Options = SSF:GetModule("Options")
    if not Options:IsHelpOn() then Options:ToggleHelp() end
    self:Show()
end

-- Setup lives in OnEnable, not OnInitialize: Core's warlock gate switches modules off
-- before OnEnable, so other classes never get the welcome.
function Welcome:OnEnable()
    if Owed() then self:RegisterEvent("LOADING_SCREEN_DISABLED") end
    -- the main window's "Create macros": the same note
    self:RegisterMessage("SSF_SHOW_WELCOME", function() self:Show() end)
    self:RegisterMessage("SSF_WINDOW_OPENED", "OnWindowOpened")
end
