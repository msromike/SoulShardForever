-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Cap: the thresholds. What the cap is right now, the low mark in use, and which state a
-- count is in against them.
--   The cap: AutoMax on AND a soul bag equipped -> the soul bags' slot total;
--            otherwise the slider value, clamped to MIN-MAX and whole.
--   The low mark in use: the saved Low shard warn, but never above the cap. A low mark
--     over the cap would make a count both "over the cap" and "low" at once (Match soul
--     bag size can drop the cap under it). The saved value is not touched, so when the
--     cap rises again the saved low mark is back by itself.
--   State(count): "over" above the cap (over the cap wins), "low" below the low mark in
--     use, "ok" between. IsFull(count): at or over the cap (the broker's "Full", the
--     Delete Shard button's "At cap"). The threshold tests live here and nowhere else;
--     Counter's color, the glow, the chat and tooltip count and the Delete Shard gate all
--     ask.
-- Recomputes the cap at login and on bag changes and sends SSF_CAP_CHANGED when the number
-- moves. Trimmer calls Get() fresh on every press, so a missed event can never stale a
-- delete.
--
-- Public:  Cap.MIN, Cap.MAX; Get() -> cap, IsAuto() -> bool, LowMark() -> mark in use,
--          State(count) -> "low" | "ok" | "over", IsFull(count) -> bool, SetManual(n)
--          (Options' slider and /ssf setmax; turning AutoMax off is the caller's job),
--          Recompute().
-- Listens: PLAYER_ENTERING_WORLD, SSF_BAGS_CHANGED.
-- Sends:   SSF_CAP_CHANGED (cap).
-- Reads:   Bags:SoulBagSlots(), Bags:HasSoulBag(); profile.autoMax, maxShards, lowMark.
-- Saves:   profile.maxShards (SetManual only).
-- Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Cap = SSF:NewModule("Cap", "AceEvent-3.0")

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
    return SSF.db.profile.autoMax and SSF:GetModule("Bags"):HasSoulBag()
end

function Cap:Get()
    if self:IsAuto() then
        return SSF:GetModule("Bags"):SoulBagSlots()
    end
    return clamp(SSF.db.profile.maxShards)
end

function Cap:LowMark()
    return math.min(SSF.db.profile.lowMark, self:Get())
end

function Cap:State(count)
    if count > self:Get() then return "over" end
    if count < self:LowMark() then return "low" end
    return "ok"
end

function Cap:IsFull(count)
    return count >= self:Get()
end

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
    self:RegisterMessage("SSF_BAGS_CHANGED", "Recompute")
    self:Recompute()
end
