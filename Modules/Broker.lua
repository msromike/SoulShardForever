-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Broker: the LibDataBroker data object and the LibDBIcon minimap icon. Click toggles the
-- options window (opens it, or closes it if open).
-- Fields: type, label "SSF", icon, text = the count alone in its state color (the icon
-- names it, the color is the state; the cap is a setting and lives in the tooltip: Mike,
-- 2026-10-21), value = N. No suffix, no "Full", no per-bag breakdown.
-- Tooltip: the same rows every time. The title in the class color; the count, always in
-- its state color (the tooltip teaches the bag's colors); a blank line; then the settings
-- in white: the cap, the low mark, and SSF paused Yes/No. Every value's wording and color
-- comes from Status, so chat, window and tooltip never drift apart.
--
-- Listens: SSF_BAGS_CHANGED, SSF_CAP_CHANGED, SSF_SHARD_DELETED, SSF_OPTIONS_CHANGED
--          (the text; "minimap" also shows or hides the icon).
-- Reads:   Bags:Count(), Status:CountValue/CapValue/LowMarkValue/PausedValue, Colors:Class
--          and Colors.DIM, Window:Toggle(), SSF.ICON;
--          profile.minimap.
-- Touches nothing else.

local ADDON = ...
local NAME = "SSF" -- the broker object and minimap icon: what bar addons list
local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Broker = SSF:NewModule("Broker", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)
local LDB = LibStub("LibDataBroker-1.1")
local DBIcon = LibStub("LibDBIcon-1.0")

-- The minimap and broker tooltip: the live count, a blank line, then the settings.
local function ShowTooltip(tooltip)
    local Status, Colors = SSF:GetModule("Status"), SSF:GetModule("Colors")
    local dr, dg, db = Colors.DIM[1], Colors.DIM[2], Colors.DIM[3]
    tooltip:AddLine(L["Soul Shards Forever"], Colors:Class())
    tooltip:AddDoubleLine(L["Soul Shards"], Status:CountValue(), dr, dg, db)
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine(L["Soul shard cap"], Status:CapValue(), dr, dg, db)
    tooltip:AddDoubleLine(L["Low shard warn"], Status:LowMarkValue(), dr, dg, db)
    tooltip:AddDoubleLine(L["SSF paused"], Status:PausedValue(), dr, dg, db)
end

function Broker:Refresh()
    local count = SSF:GetModule("Bags"):Count()
    self.object.text = SSF:GetModule("Status"):CountValue(count)
    self.object.value = count
end

-- OnEnable runs once: SSF never disables and re-enables a module (Core's warlock gate only
-- switches them off at load).
function Broker:OnEnable()
    self.object = LDB:NewDataObject(NAME, {
        type = "data source",
        label = L["SSF"],
        icon = SSF.ICON,
        text = "",
        value = 0,
        OnClick = function() SSF:GetModule("Window"):Toggle() end, -- open, or close if open
        OnTooltipShow = ShowTooltip,
    })
    DBIcon:Register(NAME, self.object, SSF.db.profile.minimap)
    self:RegisterMessage("SSF_BAGS_CHANGED", "Refresh")
    self:RegisterMessage("SSF_CAP_CHANGED", "Refresh")
    self:RegisterMessage("SSF_SHARD_DELETED", "Refresh")
    self:RegisterMessage("SSF_OPTIONS_CHANGED", "OnOptionsChanged")
    self:Refresh()
end

function Broker:OnOptionsChanged(_, key)
    if key == "minimap" then
        if SSF.db.profile.minimap.hide then DBIcon:Hide(NAME) else DBIcon:Show(NAME) end
    end
    self:Refresh()
end
