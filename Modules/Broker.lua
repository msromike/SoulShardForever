-- Soul Shard Forever (SSF). GPLv3, see LICENSE.
--
-- Broker: the LibDataBroker data object and the LibDBIcon minimap button. Listens only:
-- SSF_CAP_CHANGED, SSF_SHARD_DELETED, SSF_OPTIONS_CHANGED and a bucketed BAG_UPDATE
-- refresh the text. Click opens the options window.
-- Fields: type, label, icon, text "N / cap", value = N. No suffix, no per-bag breakdown.

local ADDON = "SoulShardForever"
local SSF = LibStub("AceAddon-3.0"):GetAddon(ADDON)
local Broker = SSF:NewModule("Broker", "AceEvent-3.0", "AceBucket-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)
local LDB = LibStub("LibDataBroker-1.1")
local DBIcon = LibStub("LibDBIcon-1.0")

local RED = "|cffff4040%d|r"

function Broker:Refresh()
    local count, cap = SSF:GetModule("Bags"):Count(), SSF:GetModule("Cap"):Get()
    local shown = count > cap and RED:format(count) or tostring(count)
    self.object.text = shown .. " / " .. cap
    self.object.value = count
end

function Broker:OnEnable()
    if not self.object then
        self.object = LDB:NewDataObject(ADDON, {
            type = "data source",
            label = L["SSF"],
            icon = SSF.ICON,
            text = "",
            value = 0,
            OnClick = function() SSF:GetModule("Options"):Open() end,
            OnTooltipShow = function(tooltip)
                local count, cap = SSF:GetModule("Bags"):Count(), SSF:GetModule("Cap"):Get()
                tooltip:AddLine(L["Soul Shard Forever"])
                tooltip:AddDoubleLine(L["Soul Shards"], count, 0.8, 0.8, 0.8, 1, 1, 1)
                tooltip:AddDoubleLine(L["Cap"], cap, 0.8, 0.8, 0.8, 1, 1, 1)
                if count > cap then
                    tooltip:AddLine(L["Over by %d. The next press trims one."]:format(count - cap), 1, 0.25, 0.25)
                end
            end,
        })
        DBIcon:Register(ADDON, self.object, SSF.db.profile.minimap)
    end
    self:RegisterMessage("SSF_CAP_CHANGED", "Refresh")
    self:RegisterMessage("SSF_SHARD_DELETED", "Refresh")
    self:RegisterMessage("SSF_OPTIONS_CHANGED", "OnOptionsChanged")
    self:RegisterBucketEvent("BAG_UPDATE", 0.5, "Refresh")
    self:Refresh()
end

function Broker:OnOptionsChanged(_, key)
    if key == "minimap" then
        if SSF.db.profile.minimap.hide then DBIcon:Hide(ADDON) else DBIcon:Show(ADDON) end
    end
    self:Refresh()
end
