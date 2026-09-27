-- Soul Shard Forever (SSF): a Soul Shard cap for warlocks on WoW Forever.
-- Started as a fork of SoulSort by Anilusion; rewritten from scratch on Ace3 for Forever
-- only. No original code remains. MIT, see LICENSE.
--
-- HOUSE RULE: Ace everywhere. If an Ace3 library (or LibDBIcon/LDB) does a job, use it;
-- never hand-roll a replacement or reach around it. One way to print (AceConsole), one
-- settings table (AceConfig), one event path (AceEvent/AceBucket), one db (AceDB).
--
-- Core: the addon object, the warlock gate and the saved settings. Nothing else.
-- The work is in the modules under Modules\.

local ADDON = "SoulShardForever"
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
        autoMax = true,             -- cap follows the soul bag's slot count
        counter = false,            -- number on the far-left bag button
        counterFont = "Arial Narrow", -- LibSharedMedia font name (NumberFontNormal's face); size auto-fits
        counterColorize = true,       -- grey at zero, green in range, yellow over the cap; off = white
        lowGlow = true,               -- glow the bag button while shards are below the low mark
        lowMark = 4,                  -- the low mark (1-20)
        announce = false,           -- one chat line per deletion
        minimap = { hide = false }, -- LibDBIcon state
        deleteOrder = "front",      -- "front" = backpack first, "back" = far-left bag first; no UI
        -- 1-100 is what the slider allows; any other value is clamped by Cap.
    },
}

function SSF:OnInitialize()
    -- Warlock gate. On any other class nothing is set up and the addon never enables,
    -- so no saved variables, no slash command, no button, no message.
    if UnitClassBase("player") ~= "WARLOCK" then
        self:SetEnabledState(false)
        return
    end

    self.db = LibStub("AceDB-3.0"):New("SoulShardForeverDB", defaults) -- per-character profiles
end

function SSF:OnEnable()
    local version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
    local author = self:GetModule("Settings"):Accent("msromike")
    self:Printf(L["Soul Shard Forever (SSF) v%s by %s. Type /ssf for options."], version, author)
end
