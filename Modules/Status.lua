-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Status: the one wording for every number SSF shows, and the lines that print at login.
-- Chat, the window's top line and the minimap tooltip all build from these, so a change
-- here changes them all.
--   CountValue(count) -> "N" in its state color (Cap:State, Colors), always: only the bag
--     number follows the colorize option.
--   CapText(count, cap) -> "N (cap M)", the broker text; the cap in the value white.
--   StatusText(count, cap) -> "Soul Shards: N (cap M)", chat (a bare /ssf, the login
--     lines, the announce line, the paused-press line). Both arguments are optional: the
--     Trimmer passes the count it knows right after a delete, when the bags still show the
--     deleted shard until the server confirms.
--   CountText() -> "Soul Shards: N", the window's top line (its cap is the slider below).
--   CapValue() -> the cap, in the value white.
--   LowMarkValue() -> the saved low mark, in the value white.
--   PausedValue() -> red "Yes" while paused, green "No" otherwise.
--   PauseText() -> "SSF paused: Yes/No", the one pause wording in chat (a bare /ssf, the
--     login lines, the /ssf pause echo and the pause key binding).
--   PrintStatus() -> prints PauseText then StatusText (a bare /ssf, login).
-- Login and reload: the version line at enable, then both status lines once.
--
-- Listens: PLAYER_ENTERING_WORLD (once), BAG_UPDATE_DELAYED (fresh login only: the bags
--          are not readable yet when the world is entered; tested, it counted 0).
-- Reads:   Bags:Count(), Cap:Get/State, Colors; profile.lowMark, paused;
--          SSF.VERSION.
-- Touches nothing else.

local ADDON = ...
local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Status = SSF:NewModule("Status", "AceEvent-3.0", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)

local function Colors() return SSF:GetModule("Colors") end
local function Cap() return SSF:GetModule("Cap") end

function Status:CountValue(count)
    count = count or SSF:GetModule("Bags"):Count()
    local _, _, _, hex = Colors():ForState(Cap():State(count))
    return "|cff" .. hex .. count .. "|r"
end

function Status:CapText(count, cap)
    count, cap = count or SSF:GetModule("Bags"):Count(), cap or Cap():Get()
    return L["%s (cap %s)"]:format(self:CountValue(count), Colors():Value(cap))
end

function Status:StatusText(count, cap)
    return L["Soul Shards: %s"]:format(self:CapText(count, cap))
end

function Status:CountText()
    return L["Soul Shards: %s"]:format(self:CountValue())
end

function Status:CapValue()
    return Colors():Value(Cap():Get())
end

function Status:LowMarkValue()
    return Colors():Value(SSF.db.profile.lowMark)
end

-- Paused or not, as a stop/go word: "Yes" in red while paused (nothing moves or deletes),
-- "No" in green while presses work. SSF's own Yes/No, so they follow the Language setting.
function Status:PausedValue()
    local paused = SSF.db.profile.paused
    return Colors():State(paused and L["Yes"] or L["No"], not paused)
end

function Status:PauseText()
    return L["SSF paused"] .. ": " .. self:PausedValue()
end

function Status:PrintStatus()
    SSF:Print(self:PauseText())
    SSF:Print(self:StatusText())
end

-- Setup lives in OnEnable, not OnInitialize: Core's warlock gate switches modules off
-- before OnEnable, so other classes never get the lines.
function Status:OnEnable()
    SSF:Printf(L["Soul Shards Forever (SSF) v%s by %s. Type /ssf for options."],
        SSF.VERSION, Colors():Accent("msromike"))
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

-- Login and reload: the same two lines as a bare /ssf, once, after the version line. The
-- count needs the bag contents. On a reload they are there when the world is entered; on
-- a fresh login they are not, so the lines wait for the game's BAG_UPDATE_DELAYED, with a
-- timer in case that never comes.
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
    self:PrintStatus()
end
