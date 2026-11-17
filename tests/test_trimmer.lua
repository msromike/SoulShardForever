-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_trimmer: WhyNot, the one gate the Delete Shard button and the press share; the press
-- in combat (it deletes, moves nothing, and a paused press stays silent); what the
-- bags hold once the server confirms a press (WoW.Settle); and that a press waits while
-- the server still holds a shard, so presses faster than the server never go under the cap.
-- Saves:   profile.paused, maxShards, autoMax, pauseLog, for the test at hand.
-- Touches nothing else.

local SHARD = SSF.SHARD_ITEM_ID
local Trimmer = SSF:GetModule("Trimmer")
local profile = SSF.db.profile

test("WhyNot: paused is the only answer while paused", function()
    profile.paused = true
    profile.maxShards = 8
    profile.autoMax = false
    eq(Trimmer:WhyNot(0), "paused", "under cap, still paused")
    eq(Trimmer:WhyNot(8), "paused", "at cap, still paused")
    eq(Trimmer:WhyNot(20), "paused", "over cap, still paused")
    profile.paused = false
end)

test("WhyNot unpaused: nil over the cap, atcap at it, undercap below", function()
    profile.paused = false
    profile.maxShards = 8
    profile.autoMax = false
    eq(Trimmer:WhyNot(9), nil, "one over: a press deletes")
    eq(Trimmer:WhyNot(8), "atcap", "exactly the cap")
    eq(Trimmer:WhyNot(7), "undercap", "one under")
    eq(Trimmer:WhyNot(0), "undercap", "zero")
end)

test("WhyNot before Drain Soul: quiet, whatever the count; paused still wins", function()
    profile.paused = false
    profile.maxShards = 8
    profile.autoMax = false
    local Cap = SSF:GetModule("Cap")
    WoW.unknownSpells[Cap.QUIET_UNTIL] = true
    eq(Trimmer:WhyNot(0), "quiet", "zero, no Drain Soul")
    eq(Trimmer:WhyNot(9), "quiet", "over the cap, no Drain Soul")
    profile.paused = true
    eq(Trimmer:WhyNot(0), "paused", "paused and quiet: paused")
    profile.paused = false
    WoW.unknownSpells[Cap.QUIET_UNTIL] = nil
end)

test("WhyNot with no count reads the bags", function()
    WoW.SetBags({ [0] = WoW.PlainBag(16, { [1] = SHARD, [2] = SHARD }) })
    profile.paused = false
    profile.maxShards = 1
    eq(Trimmer:WhyNot(), nil, "2 shards, cap 1: over")
    profile.maxShards = 2
    eq(Trimmer:WhyNot(), "atcap", "2 shards, cap 2")
    profile.maxShards = 8
end)

-- One delete press, and how many shards it deleted: the stub's cursor really takes the
-- shard and really deletes it, and WoW.deleted holds every one that went.
local function PressCountingDeletes()
    local before = #WoW.deleted
    Trimmer:Delete()
    return #WoW.deleted - before
end

test("in combat, over the cap: one press deletes one shard and moves nothing", function()
    -- a soul bag with free slots and loose shards: out of combat this press would sort
    local function bags()
        WoW.SetBags({ [0] = WoW.PlainBag(16, { [1] = SHARD, [2] = SHARD, [3] = SHARD }), [1] = WoW.SoulBag(4) })
    end
    bags()
    profile.paused = false
    profile.maxShards = 1
    profile.autoMax = false
    WoW.combat = true
    eq(PressCountingDeletes(), 1, "3 shards, cap 1, in combat: one delete")
    eq(#WoW.picks, 1, "one pickup, the delete's: no sorting in a fight")
    SSF:GetModule("Sorter").noted = nil
    WoW.combat = false
    WoW.picks = {}
    bags()
    PressCountingDeletes()
    ok(#WoW.picks > 1, "the same press out of combat does sort, so the line above proves the gate")
    SSF:GetModule("Sorter").reruns = nil
    profile.maxShards = 8
end)

test("a press over the cap: one shard gone once the server confirms, and the rest sorted", function()
    WoW.SetBags({ [0] = WoW.PlainBag(16, { [1] = SHARD, [2] = SHARD, [3] = SHARD }), [1] = WoW.SoulBag(4) })
    profile.paused = false
    profile.maxShards = 2
    profile.autoMax = false
    local Bags = SSF:GetModule("Bags")
    eq(PressCountingDeletes(), 1, "3 shards, cap 2: one delete")
    eq(Bags:Count(), 3, "asked for, not yet gone: the bags still show three, as in the game")
    WoW.Settle()
    WoW.Settle()
    eq(Bags:Count(), 2, "the server confirms: two left")
    local inSoulBag = 0
    for slot = 1, 4 do
        if WoW.bags[1].items[slot] == SHARD then inSoulBag = inSoulBag + 1 end
    end
    eq(inSoulBag, 2, "and both are in the soul bag: the press sorted what it kept")
    eq(PressCountingDeletes(), 0, "at the cap now: the next press deletes nothing")
end)

test("WhyNot: locked when over the cap and the server still holds a shard; the cap answers come first", function()
    WoW.SetBags({ [0] = WoW.PlainBag(16, { [1] = SHARD, [2] = SHARD, [3] = SHARD }, { [2] = true }) })
    profile.paused = false
    profile.autoMax = false
    profile.maxShards = 2
    eq(Trimmer:WhyNot(), "locked", "3 shards, cap 2, one locked: a press waits")
    profile.maxShards = 3
    eq(Trimmer:WhyNot(), "atcap", "at the cap: the cap is the reason, locked or not")
    profile.maxShards = 8
    eq(Trimmer:WhyNot(), "undercap", "under the cap: the same")
    WoW.SetBags({ [0] = WoW.PlainBag(16, { [1] = SHARD, [2] = SHARD, [3] = SHARD, [4] = 1234 }, { [4] = true }) })
    profile.maxShards = 2
    eq(Trimmer:WhyNot(), nil, "another item locked says nothing: a press deletes")
end)

test("one over the cap, pressed again before the server confirms: one shard gone, not two", function()
    -- no soul bag: nothing for the sort to move, so the only shard in flight is the delete's
    WoW.SetBags({ [0] = WoW.PlainBag(16, { [1] = SHARD, [2] = SHARD, [3] = SHARD }) })
    profile.paused = false
    profile.autoMax = false
    profile.maxShards = 2
    local Bags = SSF:GetModule("Bags")
    eq(PressCountingDeletes(), 1, "3 shards, cap 2: the first press deletes")
    eq(Bags:Count(), 3, "not confirmed yet: the bags still show three")
    eq(PressCountingDeletes(), 0, "the second press, before the server confirms: nothing")
    eq(PressCountingDeletes(), 0, "and the third")
    WoW.Settle()
    eq(Bags:Count(), 2, "the server confirms: two left, the cap")
    eq(PressCountingDeletes(), 0, "at the cap now: nothing")
end)

test("three over the cap, a press after each confirm: three gone, one at a time", function()
    WoW.SetBags({ [0] = WoW.PlainBag(16, { [1] = SHARD, [2] = SHARD, [3] = SHARD, [4] = SHARD, [5] = SHARD }) })
    profile.paused = false
    profile.autoMax = false
    profile.maxShards = 2
    local Bags = SSF:GetModule("Bags")
    for left = 4, 2, -1 do
        eq(PressCountingDeletes(), 1, "over the cap, nothing in flight: a delete")
        eq(PressCountingDeletes(), 0, "pressed again at once: it waits")
        WoW.Settle()
        eq(Bags:Count(), left, "the server confirms: " .. left .. " left")
    end
    eq(PressCountingDeletes(), 0, "at the cap: nothing more")
end)

test("paused in combat: the press is silent; out of combat it prints", function()
    WoW.SetBags({ [0] = WoW.PlainBag(16, { [1] = SHARD, [2] = SHARD }) })
    local pauseLog = profile.pauseLog
    profile.paused = true
    profile.pauseLog = true
    profile.maxShards = 1
    WoW.combat = true
    local before = #WoW.chat
    eq(PressCountingDeletes(), 0, "paused: no delete")
    eq(#WoW.chat, before, "in combat: no chat line")
    WoW.combat = false
    PressCountingDeletes()
    eq(#WoW.chat, before + 1, "out of combat: the paused-press line")
    profile.paused = false
    profile.pauseLog = pauseLog
    profile.maxShards = 8
end)
