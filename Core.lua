-- SoulShard Sort Forever (SSF): a Soul Shard cap for warlocks on WoW Forever.
-- Fork of SoulSort by Anilusion (GPLv3), rewritten on Ace3 for Forever only.
-- GPLv3, see LICENSE.
--
-- Core: the addon object, the warlock gate and the saved settings. Nothing else.
-- The work is in the modules under Modules\.

local ADDON = "SoulShardSortForever"
local SSF = LibStub("AceAddon-3.0"):NewAddon(ADDON, "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)

SSF.SHARD_ITEM_ID = 6265
SSF.ICON = "Interface\\Icons\\spell_shadow_soulgem"

local defaults = {
    profile = {
        maxShards = 20,             -- the cap while autoMax is off (1-100)
        autoMax = true,             -- cap follows the soul bag's slot count
        counter = false,            -- number on the far-left bag button
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

    self.db = LibStub("AceDB-3.0"):New("SoulShardSortForeverDB", defaults) -- per-character profiles
end
