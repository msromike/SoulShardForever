-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- LowGlow: while the shard count is below the low mark, the bag button the counter sits on
-- glows (LibCustomGlow's button glow, the proc-alert look). The glow stays on until the
-- count is back at the mark, so a glance at the bag bar says "go farm shards". Part of the
-- bag display: it runs only while "Show shard count on bag bar" is on (a glow with no
-- number explains nothing), and is off via the "Glow bag button when low" option under it.
--
-- Listens: bucketed BAG_UPDATE, SSF_SHARD_DELETED, SSF_OPTIONS_CHANGED.
-- Reads: Bags:Count(), Cap:LowMark() (the low mark in use, never above the cap),
-- Counter:Anchor(). Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local LowGlow = SSF:NewModule("LowGlow", "AceEvent-3.0", "AceBucket-3.0")
local LCG = LibStub("LibCustomGlow-1.0")

function LowGlow:Refresh()
    local p = SSF.db.profile
    local button = SSF:GetModule("Counter"):Anchor()
    -- the low mark in use, never above the cap, so the glow and the count color agree
    local low = p.counter and p.lowGlow and SSF:GetModule("Bags"):Count() < SSF:GetModule("Cap"):LowMark()

    -- the anchor can change (bag bar collapsed): stop the old button before starting a new one
    if self.button and (self.button ~= button or not low) then
        LCG.ButtonGlow_Stop(self.button)
        self.button = nil
    end
    if low and button and self.button ~= button then
        LCG.ButtonGlow_Start(button)
        self.button = button
    end
end

function LowGlow:OnEnable()
    self:RegisterMessage("SSF_SHARD_DELETED", "Refresh")
    self:RegisterMessage("SSF_OPTIONS_CHANGED", "Refresh")
    self:RegisterBucketEvent({ "BAG_UPDATE", "BAG_CONTAINER_UPDATE" }, 0.5, "Refresh")
    self:Refresh()
end
