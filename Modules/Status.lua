-- Soul Shard Forever (SSF). MIT, see LICENSE.
--
-- Status: the two status lines and when they print at login. Nothing else.
--   StatusText(count, cap) -> "Soul Shards: N (cap M)", the one count/cap wording (the
--     window's status line, a bare /ssf, the announce line, the paused-press line).
--   PauseText() -> "SSF actions - ON/OFF", the first line of a bare /ssf.
-- Login and reload: prints both lines once, after the version line.
--
-- Listens: PLAYER_ENTERING_WORLD (once), BAG_UPDATE_DELAYED (fresh login only).
-- Reads Bags, Cap, Counter:StateColor and Settings:Value/OnOff through their public methods.

local ADDON = "SoulShardForever"
local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Status = SSF:NewModule("Status", "AceEvent-3.0", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)

-- The one count/cap wording, used by the window and the announce line. The count takes
-- the one state color (Counter:StateColor: red / green / yellow, or white when colorizing
-- is off) so the window shows the effect of a cap change without looking at the bag; the
-- cap is a setting, so it gets the neutral value color. Both arguments are optional: the
-- Trimmer passes the count it knows right after a delete, when the bags still show the
-- deleted shard until the server confirms.
function Status:StatusText(count, cap)
    count, cap = count or SSF:GetModule("Bags"):Count(), cap or SSF:GetModule("Cap"):Get()
    local _, _, _, hex = SSF:GetModule("Counter"):StateColor(count, cap)
    return L["Soul Shards: %s (cap %s)"]:format("|cff" .. hex .. count .. "|r", SSF:GetModule("Settings"):Value(cap))
end

-- The first line of a bare /ssf: "SSF actions - ON" (green) while presses work,
-- "- OFF" (red) while paused.
function Status:PauseText()
    local on = not SSF.db.profile.paused
    return L["SSF actions"] .. " - " .. SSF:GetModule("Settings"):OnOff(on)
end

-- Setup lives in OnEnable, not OnInitialize: Core's warlock gate switches modules off
-- before OnEnable, so other classes never get the lines.
function Status:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

-- Login and reload: the same two lines as a bare /ssf, once, after the version line. The
-- count needs the bag contents. On a reload they are there when the world is entered; on
-- a fresh login they are not (tested: it counted 0), so the lines wait for the game's
-- BAG_UPDATE_DELAYED, with a timer in case that never comes.
function Status:PLAYER_ENTERING_WORLD(_, isInitialLogin)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    if isInitialLogin then
        self:RegisterEvent("BAG_UPDATE_DELAYED", "PrintLoginStatus")
        self.loginTimer = self:ScheduleTimer("PrintLoginStatus", 10)
    else
        self:PrintLoginStatus()
    end
end

function Status:PrintLoginStatus()
    if self.loginStatusPrinted then return end
    self.loginStatusPrinted = true
    self:UnregisterEvent("BAG_UPDATE_DELAYED")
    if self.loginTimer then self:CancelTimer(self.loginTimer) end
    SSF:Print(self:PauseText())
    SSF:Print(self:StatusText())
end
