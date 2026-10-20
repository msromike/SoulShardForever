-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- DeleteButton: the global button "SSFDelete". A click, or "/click SSFDelete" from a macro,
-- keybind addon or WeakAura, runs Trimmer:Delete() inside a real hardware event. Invisible,
-- sizeless; it exists only to be clicked.
--
-- Deliberate exception to "Ace everywhere": /click resolves a GLOBAL frame name, and AceGUI
-- widgets are unnamed, pooled frames meant for windows. A raw CreateFrame with a name is the
-- only way to give /click a target. Nothing else in the addon builds a frame by hand.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local DeleteButton = SSF:NewModule("DeleteButton")

-- OnEnable runs once: SSF never disables and re-enables a module.
function DeleteButton:OnEnable()
    self.button = CreateFrame("Button", "SSFDelete", UIParent)
    self.button:SetScript("OnClick", function()
        SSF:GetModule("Trimmer"):Delete()
    end)
end
