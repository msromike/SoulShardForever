-- Soul Shard Forever (SSF). MIT, see LICENSE.
--
-- Broker: the LibDataBroker data object and the LibDBIcon minimap button. Listens only:
-- SSF_CAP_CHANGED, SSF_SHARD_DELETED, SSF_OPTIONS_CHANGED and a bucketed BAG_UPDATE
-- refresh the text. Click opens the options window.
-- Fields: type, label "SSF", icon, text "N (cap M)" (+ " Full" at or over the cap, the
-- count in the state color), value = N. No suffix, no per-bag breakdown.

local ADDON = "SoulShardForever" -- the folder: the locale
local NAME = "SSF"               -- the broker object and minimap button: what bar addons list
local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Broker = SSF:NewModule("Broker", "AceEvent-3.0", "AceBucket-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)
local LDB = LibStub("LibDataBroker-1.1")
local DBIcon = LibStub("LibDBIcon-1.0")

-- The count takes the one state color (Counter:StateColor) wherever it is shown here.
function Broker:Refresh()
    local count, cap = SSF:GetModule("Bags"):Count(), SSF:GetModule("Cap"):Get()
    local _, _, _, hex = SSF:GetModule("Counter"):StateColor(count, cap)
    local full = count >= cap and (" " .. L["Full"]) or ""
    self.object.text = L["%s (cap %d)"]:format("|cff" .. hex .. count .. "|r", cap) .. full
    self.object.value = count
end

function Broker:OnEnable()
    if not self.object then
        self.object = LDB:NewDataObject(NAME, {
            type = "data source",
            label = L["SSF"],
            icon = SSF.ICON,
            text = "",
            value = 0,
            OnClick = function() SSF:GetModule("Options"):Open() end,
            OnTooltipShow = function(tooltip)
                local count, cap = SSF:GetModule("Bags"):Count(), SSF:GetModule("Cap"):Get()
                local r, g, b = SSF:GetModule("Counter"):StateColor(count, cap)
                tooltip:AddLine(L["Soul Shard Forever"])
                tooltip:AddDoubleLine(L["Soul Shards"], count, 0.8, 0.8, 0.8, r, g, b)
                tooltip:AddDoubleLine(L["Cap"], cap, 0.8, 0.8, 0.8, 1, 1, 1)
                if count > cap then
                    tooltip:AddDoubleLine(L["Over by"], count - cap, r, g, b, r, g, b)
                end
            end,
        })
        DBIcon:Register(NAME, self.object, SSF.db.profile.minimap)
    end
    self:RegisterMessage("SSF_CAP_CHANGED", "Refresh")
    self:RegisterMessage("SSF_SHARD_DELETED", "Refresh")
    self:RegisterMessage("SSF_OPTIONS_CHANGED", "OnOptionsChanged")
    self:RegisterBucketEvent("BAG_UPDATE", 0.5, "Refresh")
    self:Refresh()
end

function Broker:OnOptionsChanged(_, key)
    if key == "minimap" then
        if SSF.db.profile.minimap.hide then DBIcon:Hide(NAME) else DBIcon:Show(NAME) end
    end
    self:Refresh()
end
