-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Core: the addon object, the warlock gate, the saved settings (the AceDB profile, its
-- defaults and the migrations of old values), the Language switch (ApplyLanguage) and the
-- shared constants on the addon object. Nothing else. The work is in the modules under
-- Modules\. SSF started as a fork of SoulSort by Anilusion and was rewritten from scratch
-- on Ace3 for Forever only; no original code remains. The standard every file follows is
-- CLAUDE.md at the addon root; the map of files and messages is ARCHITECTURE.md.
--
-- Public:  SSF.SHARD_ITEM_ID; SSF.SPELLS (the spell ids SSF names, by key); SSF.HALF_LINE (px: SSF's half line of empty space, the one
--          spacing unit its widgets share); SSF.ICON, SSF.VERSION and SSF.AUTHOR (each from the toc); SSF.db
--          (AceDB), SSF:ApplyLanguage() (Options' Language setting calls it, then rebuilds).
-- Lib internals: db.keys.char (AceDB's key for this character) and the raw
--          SoulShardForeverDB.profileKeys table, both only in the profile-key migration.
--          An AceDB bump that renames them makes the migration a no-op: a character on the
--          new key starts a fresh profile, nothing worse.
-- Reads:   NS.locales from Locales\Register.lua; KeyBindings:ApplyLabels(),
--          Sounds:DefaultName for a default and Sounds:LevelFromOld for a migration;
--          profile.language (ApplyLanguage: the saved pick, or the client's locale).
-- Saves:   every profile key's default; the migrations: profile.window.open (dropped in
--          1.8), profile.pauseSound and pauseSoundVolume (replaced by pauseSoundLevel, the
--          pause sound slider), and the one-time copy of a 1.8.1 profile key into the
--          AceDB 39 key (1.9.0).
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
-- The spells SSF names, by id: the one home for each number. Macros makes its macros from
-- two of them, Cap's quiet state ends with Drain Soul, and the announcement names them by
-- key. The game gives each one's name in the client's language (Spells:NameOf).
SSF.SPELLS = { LIFE_TAP = 1454, BANE_OF_AGONY = 980, DRAIN_SOUL = 1120 }
-- Half a line of empty space, in px: the air under the radio row in the options (a look
-- chosen on purpose) and between a divider and the text in the announcement panel.
-- One home, so the two stay the same; the widgets read it when they lay out (they load
-- before this file).
SSF.HALF_LINE = 5
-- the toc's IconTexture (the AddOns list shows it) is the icon's one home; a client that
-- cannot read that field shows the question mark on the minimap, which says so
SSF.ICON = C_AddOns.GetAddOnMetadata(ADDON, "IconTexture") or "Interface\\Icons\\INV_Misc_QuestionMark"
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
            pauseSoundLevel = 0,        -- while paused, every press out of combat plays a sound this loud: a notch 0-1, 0 = off (Sounds)
            pauseLog = false,           -- ... and prints a chat line
            pauseSoundName = Sounds:DefaultName(),     -- LibSharedMedia sound name (Sounds)
            minimap = { hide = false }, -- LibDBIcon state
            welcomed = false,           -- the welcome version this character closed outside a fight; false while a note is owed (Welcome)
            welcomeAgain = false,       -- Drain Soul learned, note not yet closed: its second title (Welcome)
            newsSeen = false,           -- the id of the announcement this character ticked "Don't show this again" on (NewsShow)
            macroWindowAfterReload = false, -- Macros made macros and reloaded: open the macro window
            window = {},                -- options window position: top, left and the screen size (set after a drag)
            -- debugLog: absent until the debug record is first turned on; its events, kept until cleared (Debug)
            -- language: absent = Auto (the client's locale); a code in NS.locales (deDE) forces it
        },
    }
end

-- Old saved values that no longer mean anything, fixed once at load. Each line names the
-- release that dropped the value.
local function Migrate(p)
    p.window.open = nil -- 1.8: a reopen-after-reload try that was dropped
    -- the pause sound slider: sound on/off and its volume became one notch. Neither old key
    -- has a default any more, so each is here only if the player had changed it (AceDB
    -- never saves a value equal to its default): on with no volume was on at full.
    if p.pauseSound ~= nil or p.pauseSoundVolume ~= nil then
        p.pauseSoundLevel = SSF:GetModule("Sounds"):LevelFromOld(p.pauseSound, p.pauseSoundVolume)
        p.pauseSound = nil
        p.pauseSoundVolume = nil
    end
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
