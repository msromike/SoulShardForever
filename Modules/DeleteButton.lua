-- Soul Shard Forever (SSF). GPLv3, see LICENSE.
--
-- DeleteButton: the global button "SSFDelete". A click, or "/click SSFDelete" from a macro,
-- keybind addon or WeakAura, runs Trimmer:Delete() inside a real hardware event. Invisible,
-- sizeless; it exists only to be clicked.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SoulShardForever")
local DeleteButton = SSF:NewModule("DeleteButton")

function DeleteButton:OnEnable()
    if self.button then return end
    self.button = CreateFrame("Button", "SSFDelete", UIParent)
    self.button:SetScript("OnClick", function()
        SSF:GetModule("Trimmer"):Delete()
    end)
end
