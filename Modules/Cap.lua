-- Soul Shard Forever (SSF). GPLv3, see LICENSE.
--
-- Cap: answers one question, "what is the cap right now".
--   AutoMax on AND a soul bag equipped -> the soul bags' slot total.
--   Otherwise                          -> the slider value, clamped to 1-100.
-- Recomputes at login and on bag changes and sends SSF_CAP_CHANGED when the number moves.
-- Trimmer calls Get() fresh on every press, so a missed event can never stale a delete.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SoulShardForever")
local Cap = SSF:NewModule("Cap", "AceEvent-3.0", "AceBucket-3.0")

Cap.MIN, Cap.MAX = 1, 100

local last -- the cap as of the last Recompute, for change detection

local function clamp(n)
    n = tonumber(n) or Cap.MIN
    if n < Cap.MIN then return Cap.MIN end
    if n > Cap.MAX then return Cap.MAX end
    return math.floor(n)
end

-- true when AutoMax is on and there is a soul bag to bind to
function Cap:IsAuto()
    return SSF.db.profile.autoMax and SSF:GetModule("Bags"):SoulBagSlots() > 0
end

function Cap:Get()
    if self:IsAuto() then
        return SSF:GetModule("Bags"):SoulBagSlots()
    end
    return clamp(SSF.db.profile.maxShards)
end

-- Sets the slider value. Called by Options (slider, /ssf setmax). Turning AutoMax off is
-- the caller's job; this only stores the number.
function Cap:SetManual(n)
    SSF.db.profile.maxShards = clamp(n)
    self:Recompute()
end

function Cap:Recompute()
    local now = self:Get()
    if now ~= last then
        last = now
        self:SendMessage("SSF_CAP_CHANGED", now)
    end
end

function Cap:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Recompute")
    self:RegisterBucketEvent({ "BAG_UPDATE", "BAG_CONTAINER_UPDATE" }, 0.5, "Recompute")
    self:Recompute()
end
