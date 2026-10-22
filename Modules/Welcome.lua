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
-- Drain Soul (Cap's quiet state): while quiet, the note leads with one more line under the
-- help pointer, in green, that it comes back at level 10. Learning the spell owes the note again, under its own title, and
-- it shows when the trainer window closes, so it never lands on the trainer while the
-- player is still buying (Mike, 2026-10-21). Learned away from a trainer, it waits for the
-- next load or window open, like any owed note.
--
-- Public:  Show() (the note, through Window:ShowNote).
-- Listens: SSF_SHOW_WELCOME (Window's "Create macros"), SSF_WINDOW_OPENED (any open),
--          LOADING_SCREEN_DISABLED once at load while a note is owed, SSF_QUIET_ENDED
--          (learned), TRAINER_CLOSED once after a learn.
-- Reads:   profile.welcomed, welcomeAgain; Cap:IsQuiet; Colors.GREEN (the lead line and the
--          button note's "reloads your UI");
--          Options:IsHelpOn/ToggleHelp,
--          Window:ShowNote/InFight, DeleteHelp:Blocks, Macros:AnyMissing/Create (the note's
--          button).
-- Saves:   profile.welcomed: false while the note is owed (set when it shows, and when Drain
--          Soul is learned), and WELCOME_VERSION once the player closes it outside a fight.
--          profile.welcomeAgain: true from the learn until that close (the second title).
-- Touches nothing else.

local ADDON = ...
local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Welcome = SSF:NewModule("Welcome", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)

-- The welcome's version, two digits per part (Blizzard's ## Interface scheme): 1.8 = 10800.
-- Raised only when the note changes, so players see a changed note once. 1.8.1 raised it:
-- the note was redone and Delete Shard moved. 1.10.0 raises it again: the quiet state
-- changed the note, and it is the last release (Mike, 2026-10-22).
local WELCOME_VERSION = 11000

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
    local p = SSF.db.profile
    p.welcomed = false
    local Macros = SSF:GetModule("Macros")
    local title = p.welcomeAgain and L["You learned Drain Soul"] or L["Welcome to SSF"]
    local quiet = SSF:GetModule("Cap"):IsQuiet()
    local Colors = SSF:GetModule("Colors")
    SSF:GetModule("Window"):ShowNote(title, L["Click for in-game tooltip help."],
        L["You won't see this welcome screen again on this character unless you click %s in the UI."]:format(L["Create macros"]),
        {
            -- in green, the note's one highlight color (as "reloads your UI"), so it stands out from the gold
            lead = quiet and Colors:Paint(Colors.GREEN, L["For now you can play around with the addon. When you learn Drain Soul at level 10, we'll show you this window again."]) or nil,
            blocks = SSF:GetModule("DeleteHelp"):Blocks(L["SSF deletes one Soul Shard when you're over the cap. Use the %s keybind, the %s button, a macro, or mix and match."]:format(L["Delete Shard"], L["Delete Shard"])),
            button = L["Create recommended macros"],
            onClick = function() Macros:Create() end,
            buttonNote = L["Creates the macros, %s and opens the macro box after the reload."]:format(Colors:Paint(Colors.GREEN, L["reloads your UI"])),
            buttonDisabled = not Macros:AnyMissing(), -- both made already: nothing to do
            onClose = function()
                self.noteOpen = false
                if InFight() then return end -- a fight closed it: still owed
                p.welcomed = WELCOME_VERSION
                p.welcomeAgain = false
            end,
        })
end

-- Any open of the window: a note still owed comes up with it. (ShowNote opens the window
-- too; the note is already marked open by then, so no loop.)
function Welcome:OnWindowOpened()
    if not self.noteOpen and Owed() then self:Show() end
end

-- Drain Soul learned (not just found known at login): owe the note again, under its own
-- title, and show it when the trainer window closes.
function Welcome:OnQuietEnded(_, learned)
    if not learned then return end
    SSF.db.profile.welcomed = false
    SSF.db.profile.welcomeAgain = true
    self:RegisterEvent("TRAINER_CLOSED")
end

function Welcome:TRAINER_CLOSED()
    self:UnregisterEvent("TRAINER_CLOSED")
    self:Show()
end

function Welcome:LOADING_SCREEN_DISABLED()
    self:UnregisterEvent("LOADING_SCREEN_DISABLED")
    -- a load with the note owed starts with help on: the "i" shows blue, and every option
    -- explains itself
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
    self:RegisterMessage("SSF_QUIET_ENDED", "OnQuietEnded")
end
