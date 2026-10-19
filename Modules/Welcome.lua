-- Soul Shard Forever (SSF). MIT, see LICENSE.
--
-- Welcome: the first-load welcome. The first time a character loads SSF, the window opens
-- by itself with a note beside it pointing at the help button, once. Players updating from
-- an older SSF see it once too. Waits for the loading screen to go, so the window opens
-- into a drawn, shown UI.
--
-- Reads:  profile.welcomed. Calls Options:IsHelpOn(), Options:ToggleHelp(),
--         Window:ShowNote(). Touches nothing else.
-- Saves:  profile.welcomed once the welcome has shown.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Welcome = SSF:NewModule("Welcome", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("SoulShardForever")

function Welcome:LOADING_SCREEN_DISABLED()
    self:UnregisterEvent("LOADING_SCREEN_DISABLED")
    SSF.db.profile.welcomed = true
    -- first run starts with help on: the "i" shows blue, and every option explains itself
    local Options = SSF:GetModule("Options")
    if not Options:IsHelpOn() then Options:ToggleHelp() end
    SSF:GetModule("Window"):ShowNote(L["Welcome to SSF"], L["Click for in-game tooltip help."],
        L["You'll only see this once."])
end

-- Setup lives in OnEnable, not OnInitialize: Core's warlock gate switches modules off
-- before OnEnable, so other classes never get the welcome.
function Welcome:OnEnable()
    if not SSF.db.profile.welcomed then self:RegisterEvent("LOADING_SCREEN_DISABLED") end
end
