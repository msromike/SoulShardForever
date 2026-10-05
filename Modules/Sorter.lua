-- Soul Shard Forever (SSF). MIT, see LICENSE.
--
-- Sorter: one pass moves shards toward the front of the sort order (Bags header): every
-- shard that sits in a later bag than a free slot is picked up, dropped into that free
-- slot, cursor cleared. Only into free slots; other items are never touched; a shard
-- already in the frontmost possible bag stays put. Shards the server still has locked are
-- skipped. Nothing runs in combat and nothing is queued: a pass in combat does nothing and
-- forgets any leftovers; the next press out of combat finishes the job.
--
-- SoulSort legacy (soulsortLegacy on): SoulSort's sort instead. A shard goes to any earlier
-- slot in the order, in its own bag too, and the slot may hold another item: that item
-- swaps into the shard's old slot (SoulSort did the same pickup-pickup). The order is top
-- slot first (Normal) or bottom slot first (Reverse, soulsortReverse); Bags walks it.
--
-- A pass plans every move from one snapshot and fires them all; it never reads the bags
-- back between moves (a move in flight shows its shard locked at the source and maybe not
-- yet at the target). Leftovers (locked slots, shards still in flight) are picked up by
-- re-running the pass on the next bucketed BAG_UPDATE, until a pass finds nothing to do.
-- Sends SSF_SORTED with the number of moves when a pass moved something. Reads Bags and the
-- two legacy settings.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Sorter = SSF:NewModule("Sorter", "AceEvent-3.0", "AceBucket-3.0")

local MAX_RERUNS = 5 -- bag updates a press may follow up on; a server that keeps refusing a move does not loop forever

-- Runs one pass. Returns the number of moves fired.
function Sorter:Pass()
    if InCombatLockdown() then
        self.reruns = nil
        return 0
    end
    local Bags, profile = SSF:GetModule("Bags"), SSF.db.profile
    local legacy = profile.soulsortLegacy
    local topFirst = legacy and not profile.soulsortReverse

    -- snapshot, in sort order: target slots and movable shards, each with its rank: the
    -- bag position (a shard moves only to an earlier bag), or under legacy the slot's
    -- place in the walk (a shard moves to any earlier slot). Targets are free slots, and
    -- under legacy also slots holding a swappable item.
    local free, shards, locked, n = {}, {}, false, 0
    Bags:ForEachSlot(function(bag, slot, position)
        n = n + 1
        local rank = legacy and n or position
        if Bags:IsShardAt(bag, slot) then
            if Bags:IsLocked(bag, slot) then
                locked = true
            else
                shards[#shards + 1] = { bag, slot, rank }
            end
        elseif Bags:IsFreeAt(bag, slot) or (legacy and Bags:IsSwappableAt(bag, slot)) then
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

function Sorter:OnBagUpdate()
    if self.reruns then self:Pass() end
end

function Sorter:OnEnable()
    self:RegisterBucketEvent({ "BAG_UPDATE", "BAG_CONTAINER_UPDATE" }, 0.5, "OnBagUpdate")
end
