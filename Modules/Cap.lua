-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Cap: the thresholds. What the cap is right now, the low mark in use, and which state a
-- count is in against them.
--   The cap: AutoMax on AND a soul bag equipped -> the soul bags' slot total, and that
--            number is written into the saved cap as it changes, so turning AutoMax off
--            leaves the cap where the player last saw it (no hidden value jumping back:
--            Mike, 2026-10-20); otherwise the saved cap, clamped to MIN-MAX and whole.
--   The low mark: the saved Low shard warn, never above the cap. The slider cannot set it
--     higher (SSFStepperSlider's bound, fed the cap by Options), and when the cap drops
--     under it (Match soul bag size, a lower cap) Recompute writes it down to the cap,
--     once, where the player sees it move. What the slider shows is what is saved: no
--     hidden value, nothing comes back by itself when the cap rises (Mike, 2026-10-20).
--   State(count): "paused" while SSF is paused, whatever the count (the player is
--     stockpiling on purpose: red "go farm" and yellow "delete one" would argue with that,
--     so the count goes white and the border off until unpause; Mike, 2026-10-21). Then
--     "over" above the cap (over the cap wins), "low" below the low mark, "ok" between.
--     Deleting is not gated here: Trimmer:WhyNot answers "paused" before it asks State.
--     IsFull(count): at or over the cap (the Delete Shard button's "At cap"). The
--     threshold tests live here and nowhere else; Counter's color, the glow, the chat,
--     tooltip and broker count and the Delete Shard gate all ask.
-- Recomputes the cap at login and on bag changes and sends SSF_CAP_CHANGED when the number
-- moves. Trimmer calls Get() fresh on every press, so a missed event can never stale a
-- delete.
--
-- Public:  Cap.MIN, Cap.MAX; Get() -> cap, IsAuto() -> bool, LowMark() -> the low mark,
--          State(count) -> "paused" | "low" | "ok" | "over", IsFull(count) -> bool, SetManual(n)
--          (Options' slider and /ssf setmax; turning AutoMax off is the caller's job),
--          Recompute().
-- Listens: PLAYER_ENTERING_WORLD, SSF_BAGS_CHANGED.
-- Sends:   SSF_CAP_CHANGED (cap).
-- Reads:   Bags:SoulBagSlots(), Bags:HasSoulBag(); profile.autoMax, maxShards, lowMark,
--          paused.
-- Saves:   profile.maxShards (SetManual, and Recompute while AutoMax follows a soul bag);
--          profile.lowMark, written down to the cap when the cap drops under it (Recompute).
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
    return SSF.db.profile.lowMark
end

function Cap:State(count)
    if SSF.db.profile.paused then return "paused" end
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
    local p = SSF.db.profile
    if self:IsAuto() then p.maxShards = now end -- what the slider shows is what is saved
    if p.lowMark > now then p.lowMark = now end -- the one invariant: the mark is never above the cap
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
