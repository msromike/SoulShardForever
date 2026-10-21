-- Soul Shards Forever (SSF): a Soul Shard cap for warlocks on WoW Forever.
-- Started as a fork of SoulSort by Anilusion; rewritten from scratch on Ace3 for Forever
-- only. No original code remains. MIT, see LICENSE.
--
-- The standard every file follows is CLAUDE.md at the addon root; the map of files and
-- messages is ARCHITECTURE.md.
--
-- Core: the addon object, the warlock gate, the saved settings (the AceDB profile, its
-- defaults and the migrations of old values), the Language switch (ApplyLanguage) and the
-- shared constants on the addon object. Nothing else. The work is in the modules under
-- Modules\.
--
-- Public:  SSF.SHARD_ITEM_ID, SSF.ICON, SSF.VERSION (the toc version), SSF.db (AceDB),
--          SSF:ApplyLanguage() (Options' Language setting calls it, then rebuilds).
-- Reads:   NS.locales from Locales\Register.lua; KeyBindings:ApplyLabels(),
--          Sounds:IsLevel() for a migration; the raw SoulShardForeverDB profile keys
--          before AceDB opens it (the profile-key migration).
-- Saves:   the whole profile's defaults; migrations below.
-- Touches nothing else.

local ADDON, NS = ... -- NS: the addon-private table; Locales\Register.lua fills NS.locales
-- Registered as "SSF": AceConsole prefixes every chat line with the registered name.
local SSF = LibStub("AceAddon-3.0"):NewAddon("SSF", "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)

SSF.SHARD_ITEM_ID = 6265
SSF.ICON = "Interface\\Icons\\inv_misc_gem_amethyst_02"
SSF.VERSION = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"

local defaults = {
    profile = {
        maxShards = 8,              -- the cap while autoMax is off (1-100)
        autoMax = false,            -- cap follows the soul bags' slot total
        counter = true,             -- number on the far-left bag button
        counterSoulBag = true,      -- under counter: the number sits on a soul bag while one is equipped
        counterFont = "Arial Narrow", -- LibSharedMedia font name (NumberFontNormal's face); size auto-fits
        counterColorize = true,       -- grey at zero, green in range, yellow over the cap; off = white
        lowGlow = true,               -- glow the bag button while shards are below the low mark
        lowMark = 4,                  -- the low mark (1-100, the cap's range)
        soulsortLegacy = false,     -- sort like SoulSort: shards swap with other items
        soulsortReverse = false,    -- under soulsortLegacy: bottom slot first (SoulSort's reverse)
        announce = false,           -- one chat line per deletion
        paused = false,             -- a press neither moves nor deletes
        pauseSound = false,         -- while paused, a press that would have deleted plays a sound
        pauseLog = false,           -- ... and prints a chat line
        pauseSoundName = "SSF: Bag thunk", -- LibSharedMedia sound name (Sounds module)
        pauseSoundVolume = 1,       -- 0-1; applies to SSF's own sounds only (Sounds module)
        minimap = { hide = false }, -- LibDBIcon state
        welcomed = false,           -- the welcome version this character last saw at load (Welcome)
        macroWindowAfterReload = false, -- Macros made macros and reloaded: open the macro window
        window = {},                -- options window position: top, left (set after a drag)
        -- language: absent = Auto (the client's locale); a code in NS.locales (deDE) forces it
        -- 1-100 is what the slider allows; any other value is clamped by Cap.
    },
}

-- Old saved values that no longer mean anything, fixed once at load. Each line names the
-- release that dropped the value.
local function Migrate(p)
    p.window.open = nil -- 1.8: a reopen-after-reload try that was dropped
    -- 1.8.1: a saved volume that is no longer a level (the dropped Faint) goes back to Full
    if not SSF:GetModule("Sounds"):IsLevel(p.pauseSoundVolume) then p.pauseSoundVolume = 1 end
end

-- 1.8.2: the AceDB in this release names a character "Name Surname" on Forever, where the
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
    if known[char] or db.keys.profile ~= char then return end -- had one, or picked one by hand
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
-- English first (the default, key = string), then the chosen locale over it, which is
-- exactly what AceLocale built at load for the client's locale. Auto = the client's locale,
-- so switching back restores the stock result. Callers that cached strings rebuild
-- afterwards (Options:Rebuild); modules that read L live need nothing.
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
    self.db = LibStub("AceDB-3.0"):New("SoulShardForeverDB", defaults) -- per-character profiles
    MigrateProfileKey(self.db, known)
    Migrate(self.db.profile)
    self:ApplyLanguage() -- before any module's OnEnable reads L
end
