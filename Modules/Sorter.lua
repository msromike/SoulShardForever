-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Sorter: one pass moves shards into free soul bag slots (SSF Mode): every shard that sits
-- in a later bag than a free soul bag slot (Bags header order) is picked up, dropped into
-- that slot, cursor cleared. Only into free soul bag slots; other items are never touched;
-- with no soul bag, or no free slot in one, nothing moves. Shards the server still has
-- locked are skipped. Nothing runs in combat and nothing is queued: a pass in combat does
-- nothing and forgets any leftovers; the next press out of combat finishes the job.
--
-- SoulSort legacy (soulsortLegacy on): SoulSort's sort instead. A shard goes to any earlier
-- slot in the order, in its own bag too, and the slot may hold another item: that item
-- swaps into the shard's old slot (SoulSort did the same pickup-pickup). The order is top
-- slot first in a regular bag (Normal) or bottom slot first (Reverse, soulsortReverse); a
-- soul bag is bottom first either way. Bags walks it, and TopFirst() is the one place the
-- Normal/Reverse rule is written (Trimmer asks it too).
--
-- A pass plans every move from one snapshot and fires them all; it never reads the bags
-- back between moves (a move in flight shows its shard locked at the source and maybe not
-- yet at the target). Leftovers (locked slots, shards still in flight) are picked up by
-- re-running the pass on the next SSF_BAGS_CHANGED, until a pass finds nothing to do or
-- MAX_RERUNS follow-ups have run.
--
-- Public:  Pass() -> moves fired; TopFirst() -> true under SoulSort legacy Normal.
-- Listens: SSF_BAGS_CHANGED (re-run a pass with leftovers).
-- Sends:   SSF_SORTED (moves) when a pass moved something.
-- Reads:   Bags; profile.soulsortLegacy, soulsortReverse.
-- Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Sorter = SSF:NewModule("Sorter", "AceEvent-3.0")

local MAX_RERUNS = 5 -- follow-up passes in a row (a press mid-chain does not reset the count); a server that keeps refusing a move does not loop forever

function Sorter:TopFirst()
    local p = SSF.db.profile
    return p.soulsortLegacy and not p.soulsortReverse
end

-- Runs one pass. Returns the number of moves fired.
function Sorter:Pass()
    if InCombatLockdown() then
        self.reruns = nil
        return 0
    end
    local Bags = SSF:GetModule("Bags")
    local legacy = SSF.db.profile.soulsortLegacy
    local topFirst = self:TopFirst()

    -- snapshot, in sort order: target slots and movable shards, each with its rank: the
    -- bag position (a shard moves only to an earlier bag), or under legacy the slot's
    -- place in the walk (a shard moves to any earlier slot). Targets are free soul bag
    -- slots, or under legacy any free slot or slot holding a swappable item.
    local free, shards, locked, n = {}, {}, false, 0
    Bags:ForEachSlot(function(bag, slot, position)
        n = n + 1
        local rank = legacy and n or position
        local shard = Bags:IsShardAt(bag, slot)
        if shard and Bags:IsLocked(bag, slot) then
            locked = true
        elseif shard then
            shards[#shards + 1] = { bag, slot, rank }
        elseif legacy and (Bags:IsFreeAt(bag, slot) or Bags:IsSwappableAt(bag, slot))
            or (not legacy and Bags:IsSoulBag(bag) and Bags:IsFreeAt(bag, slot)) then
            free[#free + 1] = { bag, slot, rank }
        end
    end, topFirst)

    -- pair the last shard with the first target, and so on inward, while the target ranks
    -- earlier than the shard
    local moved, f = 0, 1
    for i = #shards, 1, -1 do
        local shard, target = shards[i], free[f]
        if not target or target[3] >= shard[3] then break end
        ClearCursor()
        C_Container.PickupContainerItem(shard[1], shard[2])
        C_Container.PickupContainerItem(target[1], target[2])
        ClearCursor()
        moved, f = moved + 1, f + 1
    end

    if moved > 0 or locked then
        self.reruns = (self.reruns or 0) + 1
        if self.reruns > MAX_RERUNS then self.reruns = nil end
    else
        self.reruns = nil
    end
    if moved > 0 then self:SendMessage("SSF_SORTED", moved) end
    return moved
end

function Sorter:OnBagsChanged()
    if self.reruns then self:Pass() end
end

function Sorter:OnEnable()
    self:RegisterMessage("SSF_BAGS_CHANGED", "OnBagsChanged")
end
