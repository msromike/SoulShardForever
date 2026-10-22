-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_trimmer: WhyNot, the one gate the Delete Shard button and the press share.
-- Saves:   profile.paused, maxShards, autoMax, for the test at hand.
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
