-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- LowGlow: while the count is in the "low" state (Cap:State: below the low mark in use),
-- the bag button the counter sits on glows (LibCustomGlow's button glow, the proc-alert
-- look). The glow stays on until the count is back at the mark, so a glance at the bag bar
-- says "go farm shards". Part of the bag display: it runs only while "Show shard count on
-- bag bar" is on (a glow with no number explains nothing; Counter sends no button then),
-- and is off via the "Glow bag button when low" option under it.
--
-- Listens: SSF_COUNTER_UPDATED (button or nil, count): Counter sends it after every refresh,
--          which covers bag, cap, delete and option changes; nothing else is needed.
-- Reads:   Cap:State(count); profile.lowGlow. Asks Counter:Refresh() once at enable, so
--          the first state is heard (Counter enables first and had already sent it).
-- Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local LowGlow = SSF:NewModule("LowGlow", "AceEvent-3.0")
local LCG = LibStub("LibCustomGlow-1.0")

function LowGlow:OnCounterUpdated(_, button, count)
    local low = button and SSF.db.profile.lowGlow and SSF:GetModule("Cap"):State(count) == "low"

    -- the anchor can change (bag bar collapsed): stop the old button before starting a new one
    if self.button and (self.button ~= button or not low) then
        LCG.ButtonGlow_Stop(self.button)
        self.button = nil
    end
    if low and self.button ~= button then
        LCG.ButtonGlow_Start(button)
        self.button = button
    end
end

function LowGlow:OnEnable()
    self:RegisterMessage("SSF_COUNTER_UPDATED", "OnCounterUpdated")
    SSF:GetModule("Counter"):Refresh()
end
