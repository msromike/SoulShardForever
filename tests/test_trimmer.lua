-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_trimmer: WhyNot, the one gate the Delete Shard button and the press share; and the
-- press in combat (it deletes, moves nothing, and a paused press stays silent).
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

-- The stub's cursor never holds anything; here a pickup puts a shard on it and a delete
-- takes it off, counted. The stub's own functions go back whatever the press does.
local function PressCountingDeletes()
    local held, deletes = false, 0
    local pickup, info, delete = C_Container.PickupContainerItem, GetCursorInfo, DeleteCursorItem
    C_Container.PickupContainerItem = function(bag, slot) pickup(bag, slot) held = true end
    GetCursorInfo = function() if held then return "item", SHARD end end
    DeleteCursorItem = function() if held then deletes, held = deletes + 1, false end end
    local okay, err = pcall(Trimmer.Delete, Trimmer)
    C_Container.PickupContainerItem, GetCursorInfo, DeleteCursorItem = pickup, info, delete
    assert(okay, err)
    return deletes
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
