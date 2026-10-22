-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Core: the addon object, the warlock gate, the saved settings (the AceDB profile, its
-- defaults and the migrations of old values), the Language switch (ApplyLanguage) and the
-- shared constants on the addon object. Nothing else. The work is in the modules under
-- Modules\. SSF started as a fork of SoulSort by Anilusion and was rewritten from scratch
-- on Ace3 for Forever only; no original code remains. The standard every file follows is
-- CLAUDE.md at the addon root; the map of files and messages is ARCHITECTURE.md.
--
-- Public:  SSF.SHARD_ITEM_ID, SSF.ICON, SSF.VERSION and SSF.AUTHOR (from the toc), SSF.db
--          (AceDB), SSF:ApplyLanguage() (Options' Language setting calls it, then rebuilds).
-- Lib internals: db.keys.char (AceDB's key for this character) and the raw
--          SoulShardForeverDB.profileKeys table, both only in the profile-key migration.
--          An AceDB bump that renames them makes the migration a no-op: a character on the
--          new key starts a fresh profile, nothing worse.
-- Reads:   NS.locales from Locales\Register.lua; KeyBindings:ApplyLabels(),
--          Sounds:DefaultName/LevelVolume/LevelKey for the defaults and a migration;
--          profile.language (ApplyLanguage: the saved pick, or the client's locale).
-- Saves:   every profile key's default; the migrations: profile.window.open (dropped in
--          1.8), profile.pauseSoundVolume (a dropped level goes back to full, 1.8.1), and
--          the one-time copy of a 1.8.1 profile key into the AceDB 39 key (1.9.0).
-- Exceptions: ApplyLanguage rewrites the AceLocale table in place, repeating AceLocale's
--          two rules (enGB is enUS; a `true` value in the default means the key is the
--          string). AceLocale has no runtime switch: NewLocale keeps only the default and
--          the client's locale (GAME_LOCALE, when set, stands in for the client's), so the
--          Language setting can only be done by writing into the table every module holds.
-- Touches nothing else.

local ADDON, NS = ... -- NS: the addon-private table; Locales\Register.lua fills NS.locales
-- Registered as "SSF": AceConsole prefixes every chat line with the registered name.
local SSF = LibStub("AceAddon-3.0"):NewAddon("SSF", "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)

SSF.SHARD_ITEM_ID = 6265
SSF.ICON = "Interface\\Icons\\inv_misc_gem_amethyst_02"
SSF.VERSION = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
SSF.AUTHOR = C_AddOns.GetAddOnMetadata(ADDON, "Author") or "?"

-- Built at OnInitialize, when every module is loaded: the two sound values are Sounds'.
-- Each key's comment says what the key means; the rule it feeds is in the module named.
local function Defaults()
    local Sounds = SSF:GetModule("Sounds")
    return {
        profile = {
            maxShards = 8,              -- the cap while autoMax is off, or no soul bag is equipped (Cap clamps to MIN-MAX)
            autoMax = false,            -- cap follows the soul bags' slot total (Cap)
            counter = true,             -- the number on a bag button (Counter)
            counterSoulBag = true,      -- under counter: the number sits on a soul bag while one is equipped
            counterFont = "Arial Narrow", -- LibSharedMedia font name (NumberFontNormal's face); size auto-fits
            counterColorize = true,     -- the number in the state color (Colors); off = white
            lowGlow = true,             -- glow the bag button while the count is low (LowGlow)
            lowMark = 4,                -- the low mark; Cap holds the mark in use to the cap
            soulsortLegacy = false,     -- sort like SoulSort: shards swap with other items (Sorter)
            soulsortReverse = false,    -- under soulsortLegacy: bottom slot first (SoulSort's reverse)
            announce = false,           -- one chat line per deletion (Trimmer)
            paused = false,             -- a press neither moves nor deletes
            pauseSound = false,         -- while paused, every press out of combat plays a sound (Trimmer)
            pauseLog = false,           -- ... and prints a chat line
            pauseSoundName = Sounds:DefaultName(),     -- LibSharedMedia sound name (Sounds)
            pauseSoundVolume = Sounds:LevelVolume("full"), -- 0-1; SSF's own sounds only (Sounds)
            minimap = { hide = false }, -- LibDBIcon state
            welcomed = false,           -- the welcome version this character last saw at load (Welcome)
            welcomeAgain = false,       -- Drain Soul learned, note not yet closed: its second title (Welcome)
            macroWindowAfterReload = false, -- Macros made macros and reloaded: open the macro window
            window = {},                -- options window position: top, left and the screen size (set after a drag)
            -- language: absent = Auto (the client's locale); a code in NS.locales (deDE) forces it
        },
    }
end

-- Old saved values that no longer mean anything, fixed once at load. Each line names the
-- release that dropped the value.
local function Migrate(p)
    p.window.open = nil -- 1.8: a reopen-after-reload try that was dropped
    -- 1.8.1: a saved volume that is no longer a level (the dropped Faint) goes back to full
    local Sounds = SSF:GetModule("Sounds")
    p.pauseSoundVolume = Sounds:LevelVolume(Sounds:LevelKey(p.pauseSoundVolume))
end

-- 1.9.0: the AceDB in this release names a character "Name Surname" on Forever, where the
-- one before named it "Name - PvE" (or PvP, RP, Hardcore, or the realm name). A character
-- whose profile is new under the new name takes its old profile over, settings and welcome
-- mark alike, so a library update resets nobody. The keys are read before AceDB:New,
-- which writes the new one. Can be dropped a few releases on.
local function KnownProfileKeys()
    local sv, known = SoulShardForeverDB, {}
    if sv and sv.profileKeys then
        for key in pairs(sv.profileKeys) do known[key] = true end
    end
    return known
end

local function MigrateProfileKey(db, known)
    local char = db.keys.char
    if known[char] or db:GetCurrentProfile() ~= char then return end -- had one, or picked one by hand
    local name = char:match("^(%S+)")
    for _, suffix in ipairs({ "PvE", "PvP", "RP", "Hardcore", GetRealmName() }) do
        local old = name .. " - " .. suffix
        if known[old] then
            db:CopyProfile(old)
            return
        end
    end
end

-- The Language setting. Rewrites the one AceLocale table every module holds, in place:
-- English first (the default, key = string), then the chosen locale over it, the way
-- AceLocale built it at load for the client's locale (with two differences: esES takes the
-- esMX table, and GetLocale() is read, not GAME_LOCALE). Auto = the client's locale. Callers
-- that cached strings rebuild afterwards (Options:Rebuild); modules that read L live need
-- nothing.
function SSF:ApplyLanguage()
    local code = self.db.profile.language or GetLocale()
    if code == "enGB" then code = "enUS" end -- AceLocale's own rule
    if code == "esES" then code = "esMX" end -- one Spanish table for both clients
    local chosen = NS.locales[code] or NS.locales.enUS
    for key, value in pairs(NS.locales.enUS.strings) do
        L[key] = value == true and key or value
    end
    if chosen ~= NS.locales.enUS then
        for key, value in pairs(chosen.strings) do L[key] = value end
    end
    self:GetModule("KeyBindings"):ApplyLabels()
end

function SSF:OnInitialize()
    -- Warlock gate. On any other class nothing is set up and the addon never enables,
    -- so no saved variables, no slash command, no button, no message. Ace3 queues each
    -- module as its own addon with its own enabled state, so they are switched off too;
    -- modules therefore do their setup in OnEnable, never OnInitialize.
    if UnitClassBase("player") ~= "WARLOCK" then
        self:SetEnabledState(false)
        for _, module in self:IterateModules() do
            module:SetEnabledState(false)
        end
        return
    end

    local known = KnownProfileKeys()
    self.db = LibStub("AceDB-3.0"):New("SoulShardForeverDB", Defaults()) -- per-character profiles
    MigrateProfileKey(self.db, known)
    Migrate(self.db.profile)
    self:ApplyLanguage() -- before any module's OnEnable reads L
end
