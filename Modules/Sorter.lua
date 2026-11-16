-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Sorter: one pass moves shards into free soul bag slots (SSF Mode): every shard that sits
-- in a later bag than a free soul bag slot (Bags header order) is picked up, dropped into
-- that slot, cursor cleared. Only into free soul bag slots; other items are never touched;
-- with no soul bag, or no free slot in one, nothing moves. Shards the server still has
-- locked are skipped. Nothing moves in combat: a pass asked for in combat forgets any
-- leftovers and notes that it was asked (a follow-up for leftovers that lands in combat
-- is forgotten without a note); when combat ends, a noted pass runs once and the
-- note clears (not while paused: Trimmer:WhyNot is asked, and the note is dropped). No
-- note, nothing runs: SSF only ever moves shards because of a press. A pass out of combat
-- clears the note too. Every move is silent: the moves go through Sounds:Moving.
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
-- Listens: SSF_BAGS_CHANGED (re-run a pass with leftovers); PLAYER_REGEN_ENABLED (combat
--          ended: run a noted pass).
-- Sends:   SSF_SORTED (the number of moves, then the moves as a list of { from bag, from
--          slot, to bag, to slot }) when a pass moved something; SSF_SORT_NOTED when a
--          pass was asked for in combat and was noted; SSF_SORT_RESUMED when combat ended
--          and the noted pass is about to run (Debug records the last two; no other
--          listener).
-- Reads:   Bags; Sounds:Moving; Trimmer:WhyNot (paused, when combat ends);
--          profile.soulsortLegacy, soulsortReverse.
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
        self.noted = true
        self:SendMessage("SSF_SORT_NOTED")
        return 0
    end
    self.noted = nil
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
    local moved, f, moves = 0, 1, {}
    for i = #shards, 1, -1 do
        local shard, target = shards[i], free[f]
        if not target or target[3] >= shard[3] then break end
        moved, f = moved + 1, f + 1
        moves[moved] = { shard[1], shard[2], target[1], target[2] }
    end
    -- fire them all, through Sounds, which keeps them silent
    if moved > 0 then
        SSF:GetModule("Sounds"):Moving("sort", function()
            for _, move in ipairs(moves) do
                ClearCursor()
                C_Container.PickupContainerItem(move[1], move[2])
                C_Container.PickupContainerItem(move[3], move[4])
                ClearCursor()
            end
        end)
    end

    if moved > 0 or locked then
        self.reruns = (self.reruns or 0) + 1
        if self.reruns > MAX_RERUNS then self.reruns = nil end
    else
        self.reruns = nil
    end
    if moved > 0 then self:SendMessage("SSF_SORTED", moved, moves) end
    return moved
end

-- A follow-up for leftovers. In combat it is forgotten, with no note: only a pass asked
-- for by a press during the fight runs when the fight ends.
function Sorter:OnBagsChanged()
    if not self.reruns then return end
    if InCombatLockdown() then
        self.reruns = nil
        return
    end
    self:Pass()
end

-- Combat ended: a pass that was asked for during the fight runs now, once.
function Sorter:OnCombatEnd()
    if not self.noted then return end
    self.noted = nil
    if SSF:GetModule("Trimmer"):WhyNot() == "paused" then return end
    self:SendMessage("SSF_SORT_RESUMED")
    self:Pass()
end

function Sorter:OnEnable()
    self:RegisterMessage("SSF_BAGS_CHANGED", "OnBagsChanged")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")
end
