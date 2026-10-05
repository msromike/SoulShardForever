-- Soul Shard Forever (SSF): a Soul Shard cap for warlocks on WoW Forever.
-- Started as a fork of SoulSort by Anilusion; rewritten from scratch on Ace3 for Forever
-- only. No original code remains. MIT, see LICENSE.
--
-- HOUSE RULE: Ace everywhere. If an Ace3 library (or LibDBIcon/LDB) does a job, use it;
-- never hand-roll a replacement or reach around it. One way to print (AceConsole), one
-- settings table (AceConfig), one event path (AceEvent/AceBucket), one db (AceDB).
--
-- Core: the addon object, the warlock gate, the saved settings and the Language switch
-- (ApplyLanguage). Nothing else. The work is in the modules under Modules\.

local ADDON, NS = ... -- NS: the addon-private table; Locales\Register.lua fills NS.locales
-- Registered as "SSF": AceConsole prefixes every chat line with the registered name.
local SSF = LibStub("AceAddon-3.0"):NewAddon("SSF", "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)

-- Label for the Bindings.xml row in Blizzard's Key Bindings screen (a global by Blizzard's rule)
BINDING_NAME_SSF_DELETE = L["Delete Shard"]

SSF.SHARD_ITEM_ID = 6265
SSF.ICON = "Interface\\Icons\\inv_misc_gem_amethyst_02"

local defaults = {
    profile = {
        maxShards = 20,             -- the cap while autoMax is off (1-100)
        autoMax = false,            -- cap follows the soul bags' slot total
        counter = false,            -- number on the far-left bag button
        counterFont = "Arial Narrow", -- LibSharedMedia font name (NumberFontNormal's face); size auto-fits
        counterColorize = true,       -- grey at zero, green in range, yellow over the cap; off = white
        lowGlow = true,               -- glow the bag button while shards are below the low mark
        lowMark = 4,                  -- the low mark (1-20)
        soulsortLegacy = false,     -- sort like SoulSort: shards swap with other items
        soulsortReverse = false,    -- under soulsortLegacy: bottom slot first (SoulSort's reverse)
        announce = false,           -- one chat line per deletion
        minimap = { hide = false }, -- LibDBIcon state
        -- language: absent = Auto (the client's locale); a code in NS.locales (deDE) forces it
        -- 1-100 is what the slider allows; any other value is clamped by Cap.
    },
}

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
    BINDING_NAME_SSF_DELETE = L["Delete Shard"]
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

    self.db = LibStub("AceDB-3.0"):New("SoulShardForeverDB", defaults) -- per-character profiles
    self:ApplyLanguage() -- before any module's OnEnable reads L
end

function SSF:OnEnable()
    local version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
    local author = self:GetModule("Settings"):Accent("msromike")
    self:Printf(L["Soul Shard Forever (SSF) v%s by %s. Type /ssf for options."], version, author)
end
