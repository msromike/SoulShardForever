-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_sorter: TopFirst, the moves one pass plans from a snapshot (read back from the
-- stub's record of PickupContainerItem calls, pairs: source, then target), and where the
-- shards are once the server confirms those moves (WoW.Settle). The end of a fight is the
-- game's own event (PLAYER_REGEN_ENABLED), which reaches Sorter the way it does in game.
-- A pass is held back while a shard is locked and runs once when the lock is gone; a move
-- the server refused, and a server that never answers, each end with nothing running.
-- Saves:   profile.soulsortLegacy, soulsortReverse, paused, autoMax, maxShards, for the
--          test at hand.
-- Exceptions: reads and seeds Sorter.held, the module's private mark that a pass is held
--          back, and Sorter.noted, its note that a pass was asked for in combat, to prove a
--          held or a noted pass is pending or forgotten; nothing public exposes them, and a
--          test is the one place allowed to look. Calls Sorter:OnChange, its handler for
--          SSF_LOCKS_CHANGED and SSF_BAGS_CHANGED, to land one change in a fight without
--          the other listeners.
-- Touches nothing else.

local SHARD = SSF.SHARD_ITEM_ID
local Sorter = SSF:GetModule("Sorter")
local profile = SSF.db.profile
local soul, plain = WoW.SoulBag, WoW.PlainBag
local function moves()
    local out = {}
    for i = 1, #WoW.picks, 2 do
        local s, t = WoW.picks[i], WoW.picks[i + 1]
        out[#out + 1] = s[1] .. ":" .. s[2] .. ">" .. t[1] .. ":" .. t[2]
    end
    return table.concat(out, " ")
end
-- where every shard sits, as "bag:slot" in bag then slot order
local function shards()
    local out = {}
    for bag = 0, 5 do
        local b = WoW.bags[bag]
        for slot = 1, b and b.slots or 0 do
            if b.items[slot] == SHARD then out[#out + 1] = bag .. ":" .. slot end
        end
    end
    return table.concat(out, " ")
end
local function endFight()
    WoW.combat = false
    WoW.FireEvent("PLAYER_REGEN_ENABLED")
end

test("TopFirst only under SoulSort legacy Normal", function()
    profile.soulsortLegacy, profile.soulsortReverse = false, false
    eq(Sorter:TopFirst(), false, "SSF Mode")
    profile.soulsortLegacy, profile.soulsortReverse = true, false
    eq(Sorter:TopFirst(), true, "legacy Normal")
    profile.soulsortLegacy, profile.soulsortReverse = true, true
    eq(Sorter:TopFirst(), false, "legacy Reverse")
    profile.soulsortLegacy, profile.soulsortReverse = false, false
end)

test("SSF Mode: shards in regular bags move into free soul bag slots, last shard first", function()
    profile.soulsortLegacy = false
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD, [9] = SHARD }), [1] = soul(4, { [4] = SHARD }) })
    local n = Sorter:Pass()
    eq(n, 2, "two moves")
    -- walk order: soul bag 1 bottom first (free 3, 2, 1), then backpack bottom first (9, 2)
    eq(moves(), "0:2>1:3 0:9>1:2", "backpack shards into the soul bag's free slots")
    eq(shards(), "0:2 0:9 1:4", "asked for, not yet moved: the bags still show them where they were")
    WoW.Settle()
    eq(shards(), "1:2 1:3 1:4", "once the server confirms, every shard is in the soul bag")
    eq(Sorter:Pass(), 0, "and a second pass has nothing left to move")
end)

test("SSF Mode: nothing moves with no soul bag, or no free soul bag slot", function()
    profile.soulsortLegacy = false
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD }) })
    eq(Sorter:Pass(), 0, "no soul bag")
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD }), [1] = soul(1, { [1] = SHARD }) })
    eq(Sorter:Pass(), 0, "soul bag full")
    eq(#WoW.picks, 0, "no pickup")
end)

test("a locked shard holds the whole pass back; it runs once when the lock clears", function()
    profile.soulsortLegacy = false
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD, [9] = SHARD }, { [9] = true }), [1] = soul(4) })
    eq(Sorter:Pass(), 0, "a shard is locked: nothing moves, the unlocked one neither")
    eq(#WoW.picks, 0, "no pickup")
    eq(Sorter.held, true, "the pass is held back")
    WoW.bags[0].locked = nil -- the lock clears with no change in the bags
    WoW.FireEvent("ITEM_LOCK_CHANGED", 0, 9)
    eq(#WoW.picks, 0, "nothing runs inside the game's own lock event")
    WoW.RunTimers()
    eq(moves(), "0:2>1:4 0:9>1:3", "on the next tick the pass runs, with both shards")
    eq(Sorter.held, nil, "and is no longer held back")
    WoW.Settle()
    eq(shards(), "1:3 1:4", "once the server confirms, both are in the soul bag")
    WoW.picks = {}
    WoW.FireEvent("ITEM_LOCK_CHANGED", 0, 9)
    WoW.FireEvent("BAG_UPDATE", 0)
    WoW.RunTimers()
    eq(#WoW.picks, 0, "it ran once: later changes run nothing")
end)

test("after a delete the game fires no lock event when the server answers: the bag change lets the pass run", function()
    profile.soulsortLegacy = false
    profile.paused, profile.autoMax, profile.maxShards = false, false, 2
    WoW.SetBags({ [0] = plain(16, { [1] = SHARD, [2] = SHARD, [3] = SHARD }), [1] = soul(4) })
    SSF:GetModule("Trimmer"):Delete()
    eq(#WoW.deleted, 1, "three shards, cap two: the press deletes one")
    eq(#WoW.picks, 1, "one pickup, the delete's: the pass is held back while the delete is on its way")
    WoW.RunTimers() -- the next tick: the press's own lock events arrive, the shard still locked
    eq(#WoW.picks, 1, "still held back: the server has not answered")
    WoW.picks = {}
    WoW.Settle()
    eq(moves(), "0:2>1:4 0:3>1:3", "the bag change that follows the delete lets the held pass run")
    WoW.Settle()
    eq(shards(), "1:3 1:4", "and the two shards kept are in the soul bag")
end)

test("a move the server refused is left alone until the next press", function()
    profile.soulsortLegacy = false
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD }), [1] = soul(4) })
    eq(Sorter:Pass(), 1, "one move asked for")
    WoW.Settle("refuse")
    eq(shards(), "0:2", "refused: the shard is where it was")
    WoW.picks = {}
    WoW.FireEvent("BAG_UPDATE", 0)
    WoW.FireEvent("ITEM_LOCK_CHANGED", 0, 2)
    WoW.RunTimers()
    eq(#WoW.picks, 0, "no second try by itself, whatever changes afterwards")
    eq(Sorter:Pass(), 1, "the next press tries once more")
    WoW.Settle("refuse")
    WoW.picks = {}
    WoW.RunTimers()
    eq(#WoW.picks, 0, "and a server that keeps refusing gets one try per press, never a loop")
end)

test("no pass while an earlier pass's moves are on their way: no two shards to one slot", function()
    profile.soulsortLegacy = false
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD }), [1] = soul(4) })
    eq(Sorter:Pass(), 1, "the first pass moves the shard")
    eq(Sorter:Pass(), 0, "a second pass before the server answers moves nothing")
    eq(moves(), "0:2>1:4", "one move asked for, not two")
    WoW.Settle()
    eq(shards(), "1:4", "the shard is in the soul bag")
    eq(moves(), "0:2>1:4", "and the pass that was held back found nothing left to do")
    eq(Sorter.held, nil, "nothing is held back any more")
end)

test("a server that never answers: the lock stays on and nothing runs", function()
    profile.soulsortLegacy = false
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD, [9] = SHARD }), [1] = soul(1) })
    eq(Sorter:Pass(), 1, "one move asked for; the server says nothing")
    WoW.picks = {}
    WoW.RunTimers()
    WoW.FireEvent("BAG_UPDATE", 0) -- other things happen in the bags meanwhile
    WoW.RunTimers()
    eq(Sorter:Pass(), 0, "a press, at any later time: the shard is still locked, nothing moves")
    eq(Sorter:Pass(), 0, "and the same at the press after it")
    eq(#WoW.picks, 0, "no pickup")
end)

test("in combat a pass does nothing and forgets a pass held back", function()
    profile.soulsortLegacy = false
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD }), [1] = soul(4) })
    Sorter.held = true
    WoW.combat = true
    eq(Sorter:Pass(), 0, "nothing in combat")
    eq(Sorter.held, nil, "the pass held back is forgotten: the note takes its place")
    eq(#WoW.picks, 0, "no pickup")
    Sorter.noted = nil
end)

test("a pass asked for in combat runs once when combat ends", function()
    profile.soulsortLegacy = false
    profile.paused = false
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD }), [1] = soul(4) })
    WoW.combat = true
    eq(Sorter:Pass(), 0, "nothing in combat")
    eq(Sorter.noted, true, "but it is noted")
    endFight()
    eq(moves(), "0:2>1:4", "the noted pass ran")
    eq(Sorter.noted, nil, "and the note is gone")
    WoW.Settle()
    eq(shards(), "1:4", "and the shard is in the soul bag")
    WoW.picks = {}
    endFight()
    eq(#WoW.picks, 0, "a second combat end runs nothing")
end)

test("combat ending with no pass asked for moves nothing", function()
    profile.soulsortLegacy = false
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD }), [1] = soul(4) })
    endFight()
    eq(#WoW.picks, 0, "no press, no move")
end)

test("a noted pass is dropped when SSF is paused at the end of the fight", function()
    profile.soulsortLegacy = false
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD }), [1] = soul(4) })
    WoW.combat = true
    Sorter:Pass()
    profile.paused = true
    endFight()
    eq(#WoW.picks, 0, "paused: nothing moves")
    eq(Sorter.noted, nil, "and the note is dropped, not kept for later")
    profile.paused = false
end)

test("a pass held back that is tried in combat is forgotten, with no note", function()
    profile.soulsortLegacy = false
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD }), [1] = soul(4) })
    Sorter.held, Sorter.noted = true, nil
    WoW.combat = true
    Sorter:OnChange()
    eq(Sorter.held, nil, "the pass held back is forgotten")
    eq(Sorter.noted, nil, "and nothing is noted: no press asked for it in this fight")
    eq(#WoW.picks, 0, "no pickup")
    endFight()
    eq(#WoW.picks, 0, "so nothing runs when the fight ends")
end)

test("a pass out of combat clears a note", function()
    profile.soulsortLegacy = false
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD }), [1] = soul(1, { [1] = SHARD }) })
    Sorter.noted = true
    eq(Sorter:Pass(), 0, "soul bag full: nothing to move")
    eq(Sorter.noted, nil, "the note is cleared all the same")
end)

test("SoulSort legacy Normal: a shard moves to an earlier slot, swapping with an item", function()
    profile.soulsortLegacy, profile.soulsortReverse = true, false
    -- no soul bag; backpack top first: slot 1 holds another item, slot 3 a shard
    WoW.SetBags({ [0] = plain(4, { [1] = 1234, [3] = SHARD }) })
    eq(Sorter:Pass(), 1, "one swap")
    eq(moves(), "0:3>0:1", "shard goes to the top slot, the item takes its place")
    WoW.Settle()
    eq(shards(), "0:1", "the shard is at the top")
    eq(WoW.bags[0].items[3], 1234, "and the item it swapped with is where the shard was")
    profile.soulsortLegacy, profile.soulsortReverse = false, false
end)
