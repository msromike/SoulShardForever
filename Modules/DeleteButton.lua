-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- DeleteButton: the global button "SSFDelete". A click, or "/click SSFDelete" from a macro,
-- keybind addon or WeakAura, runs Trimmer:Delete() inside a real hardware event. Invisible,
-- sizeless; it exists only to be clicked.
--
-- Reads:   Trimmer:Delete().
-- Exceptions: a raw, named CreateFrame. /click resolves a GLOBAL frame name, and AceGUI
--          widgets are unnamed, pooled frames meant for windows, so a raw frame with a name
--          is the only way to give /click a target. One of the three raw frames in SSF
--          (Counter's FontString on a bag button and Window's title strips are the others).
-- Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local DeleteButton = SSF:NewModule("DeleteButton")

-- OnEnable runs once: SSF never disables and re-enables a module.
function DeleteButton:OnEnable()
    self.button = CreateFrame("Button", "SSFDelete", UIParent)
    self.button:SetScript("OnClick", function()
        SSF:GetModule("Trimmer"):Delete()
    end)
end
