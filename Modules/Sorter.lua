-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Sorter: one pass moves shards into free soul bag slots (SSF Mode): every shard that sits
-- in a later bag than a free soul bag slot (Bags header order) is picked up, dropped into
-- that slot, cursor cleared. Only into free soul bag slots; other items are never touched;
-- with no soul bag, or no free slot in one, nothing moves. Nothing moves in combat: a pass
-- asked for in combat notes that it was asked (a pass held back from before the fight, see
-- below, is forgotten in it without a note); when combat ends, a noted pass runs once and
-- the note clears (not while paused: the note is dropped). No note, nothing runs: SSF only
-- ever moves shards because of a press. A pass out of combat clears the note too. Every
-- move is silent: the moves go through MoveSounds:Moving.
-- Paused, a pass moves nothing, whoever asks for it: Pass asks Trimmer:Paused itself, and
-- drops any note and any pass held back, so nothing moves a shard after the player paused.
--
-- SoulSort legacy (soulsortLegacy on): SoulSort's sort instead. A shard goes to any earlier
-- slot in the order, in its own bag too, and the slot may hold another item: that item
-- swaps into the shard's old slot (SoulSort did the same pickup-pickup). The order is top
-- slot first in a regular bag (Normal) or bottom slot first (Reverse, soulsortReverse); a
-- soul bag is bottom first either way. Bags walks it, and TopFirst() is the one place the
-- Normal/Reverse rule is written (Trimmer asks it too).
--
-- One try per press, at any speed of the server. A pass runs only while no shard is locked
-- (Bags:AnyShardLocked, asked at the pass): a locked shard is a delete or a move the server
-- has not answered, so the bags are not what they will be, and a slot a move is heading to
-- still reads as free. A pass that finds one locked moves nothing and is held back; it is
-- tried again at each change in the locks (SSF_LOCKS_CHANGED) and in the bags
-- (SSF_BAGS_CHANGED: after a delete the game fires no lock event, the shard just goes),
-- asking the lock again each time, and runs once. A pass that ran plans every move from
-- one snapshot, fires them all and is finished: nothing follows it up. A move the server
-- refused leaves its shard where it was until the next press. Deliberate: nothing is
-- counted and no list of moves is kept, so a server that keeps refusing gets one try per
-- press and cannot be looped against.
-- What cannot be known: the game has no event for a refused move, and none at all when the
-- server never answers. Then the lock stays on, no signal comes, and the pass stays held
-- back; every press asks the lock again.
--
-- Public:  Pass() -> moves fired (0 while paused, in combat, or held back by a lock); TopFirst() -> true under SoulSort legacy Normal.
-- Listens: SSF_LOCKS_CHANGED and SSF_BAGS_CHANGED (try a pass that was held back);
--          PLAYER_REGEN_ENABLED (combat ended: run a noted pass).
-- Sends:   SSF_SORTED (the number of moves, then the moves as a list of { from bag, from
--          slot, to bag, to slot }) when a pass moved something; SSF_SORT_NOTED when a
--          pass was asked for in combat and was noted; SSF_SORT_RESUMED when combat ended
--          and the noted pass is about to run (Debug records the last two; no other
--          listener).
-- Reads:   Bags; MoveSounds:Moving; Trimmer:Paused (the pause gate, at every pass and when
--          combat ends); Combat:Locked (nothing moves in combat);
--          profile.soulsortLegacy, soulsortReverse.
-- Acts on: the bags: moves shards (PickupContainerItem on the shard, then on the free soul
--          bag slot), with ClearCursor before and after each move.
-- Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Sorter = SSF:NewModule("Sorter", "AceEvent-3.0")

function Sorter:TopFirst()
    local p = SSF.db.profile
    return p.soulsortLegacy and not p.soulsortReverse
end

-- Runs one pass. Returns the number of moves fired.
function Sorter:Pass()
    if SSF:GetModule("Trimmer"):Paused() then -- paused: nothing moves, whoever asks; a pass held back is dropped
        self.held, self.noted = nil, nil
        return 0
    end
    if SSF:GetModule("Combat"):Locked() then -- the note takes the place of a pass held back
        self.held = nil
        self.noted = true
        self:SendMessage("SSF_SORT_NOTED")
        return 0
    end
    self.noted = nil
    local Bags = SSF:GetModule("Bags")
    if Bags:AnyShardLocked() then -- the server has not answered a delete or a move: held back (see the header)
        self.held = true
        return 0
    end
    self.held = nil
    local legacy = SSF.db.profile.soulsortLegacy
    local topFirst = self:TopFirst()

    -- snapshot, in sort order: target slots and movable shards, each with its rank: the
    -- bag position (a shard moves only to an earlier bag), or under legacy the slot's
    -- place in the walk (a shard moves to any earlier slot). Targets are free soul bag
    -- slots, or under legacy any free slot or slot holding a swappable item.
    local free, shards, n = {}, {}, 0
    Bags:ForEachSlot(function(bag, slot, position)
        n = n + 1
        local rank = legacy and n or position
        if Bags:IsShardAt(bag, slot) then
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
    -- fire them all, through MoveSounds, which keeps them silent
    if moved > 0 then
        SSF:GetModule("MoveSounds"):Moving("sort", function()
            for _, move in ipairs(moves) do
                ClearCursor()
                C_Container.PickupContainerItem(move[1], move[2])
                C_Container.PickupContainerItem(move[3], move[4])
                ClearCursor()
            end
        end)
        self:SendMessage("SSF_SORTED", moved, moves)
    end
    return moved
end

-- The locks or the bags changed: a pass that was held back is tried again. Pass asks every
-- gate afresh, the lock too, and stays held back while a shard is still locked. In combat
-- it is forgotten, with no note: only a pass asked for by a press during the fight runs
-- when the fight ends.
function Sorter:OnChange()
    if not self.held then return end
    if SSF:GetModule("Combat"):Locked() then
        self.held = nil
        return
    end
    self:Pass()
end

-- Combat ended: a pass that was asked for during the fight runs now, once.
function Sorter:OnCombatEnd()
    if not self.noted then return end
    self.noted = nil
    if SSF:GetModule("Trimmer"):Paused() then return end -- Pass would refuse too; this keeps SSF_SORT_RESUMED unsent
    self:SendMessage("SSF_SORT_RESUMED")
    self:Pass()
end

function Sorter:OnEnable()
    self:RegisterMessage("SSF_LOCKS_CHANGED", "OnChange")
    self:RegisterMessage("SSF_BAGS_CHANGED", "OnChange")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")
end
