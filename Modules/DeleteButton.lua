-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- DeleteButton: the global button "SSFDelete". "/click SSFDelete" from a macro, keybind
-- addon or WeakAura, or the SSF_DELETE key binding's SSFDelete:Click(), runs Trimmer:Delete()
-- inside a real hardware event. Invisible, sizeless: no mouse can reach it, it exists only
-- to be clicked by name.
--
-- Reads:   Trimmer:Delete().
-- Exceptions: a raw, named CreateFrame. /click resolves a GLOBAL frame name, and AceGUI
--          widgets are pooled frames meant for windows, unnamed or named by a counter, so a
--          raw frame with a fixed name is the only way to give /click a target. One of the
--          five exceptions CLAUDE.md lists.
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
