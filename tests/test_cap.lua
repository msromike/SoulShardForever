-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_cap: the cap right now, the low mark in use, SetManual and SSF_CAP_CHANGED.

local SHARD = 6265
local Cap = SSF:GetModule("Cap")
local profile = SSF.db.profile

local function soul(slots) return { slots = slots, family = 1, items = {} } end
local function plain(slots) return { slots = slots, family = 0, items = {} } end

test("manual cap is the slider value, clamped to 1-100 and whole", function()
    profile.autoMax = false
    profile.maxShards = 8
    eq(Cap:Get(), 8, "plain")
    profile.maxShards = 0
    eq(Cap:Get(), 1, "below MIN clamps to MIN")
    profile.maxShards = 150
    eq(Cap:Get(), 100, "above MAX clamps to MAX")
    profile.maxShards = 7.6
    eq(Cap:Get(), 7, "fraction floors")
    profile.maxShards = "12"
    eq(Cap:Get(), 12, "a numeric string counts")
    profile.maxShards = "junk"
    eq(Cap:Get(), 1, "junk falls to MIN")
    profile.maxShards = 8
end)

test("AutoMax follows the soul bags' slot total when one is equipped", function()
    WoW.SetBags({ [0] = plain(16), [2] = soul(20), [5] = soul(24) })
    profile.autoMax = true
    profile.maxShards = 8
    eq(Cap:IsAuto(), true, "auto with a soul bag")
    eq(Cap:Get(), 44, "slot total")
end)

test("AutoMax with no soul bag falls back to the slider", function()
    WoW.SetBags({ [0] = plain(16) })
    profile.autoMax = true
    profile.maxShards = 8
    eq(Cap:IsAuto(), false, "not auto without a soul bag")
    eq(Cap:Get(), 8, "slider value")
    profile.autoMax = false
end)

test("low mark in use never exceeds the cap", function()
    profile.autoMax = false
    profile.maxShards = 8
    profile.lowMark = 4
    eq(Cap:LowMark(), 4, "below the cap: as saved")
    profile.lowMark = 12
    eq(Cap:LowMark(), 8, "above the cap: the cap")
    profile.maxShards = 12
    eq(Cap:LowMark(), 12, "cap raised: the saved mark is back")
    profile.lowMark = 4
    profile.maxShards = 8
end)

test("the low mark in use is held to the cap, paused or not", function()
    profile.autoMax = false
    profile.maxShards = 8
    profile.lowMark = 73
    profile.paused = true
    eq(Cap:LowMark(), 8, "paused: still the cap")
    profile.paused = false
    eq(Cap:LowMark(), 8, "unpaused: the cap")
    profile.lowMark = 4
end)

test("State: low below the mark, ok to the cap, over above it", function()
    profile.autoMax = false
    profile.maxShards = 8
    profile.lowMark = 4
    profile.paused = false
    eq(Cap:State(0), "low", "zero is low")
    eq(Cap:State(3), "low", "3 < 4")
    eq(Cap:State(4), "ok", "at the mark is ok")
    eq(Cap:State(8), "ok", "at the cap is ok")
    eq(Cap:State(9), "over", "9 > 8")
end)

test("State with a mark above the cap: over wins while unpaused", function()
    profile.autoMax = false
    profile.maxShards = 8
    profile.lowMark = 73
    profile.paused = false
    eq(Cap:State(33), "over", "33 shards, cap 8: over, not low")
    eq(Cap:State(5), "low", "5 < 8 (the mark in use is the cap)")
    eq(Cap:State(8), "ok", "at the cap")
    profile.lowMark = 4
end)

test("State ignores pause", function()
    profile.autoMax = false
    profile.maxShards = 8
    profile.lowMark = 73
    profile.paused = true
    eq(Cap:State(33), "over", "33 > 8, paused or not")
    eq(Cap:State(5), "low", "5 < 8 (the mark in use is the cap)")
    eq(Cap:State(8), "ok", "at the cap")
    profile.paused = false
    profile.lowMark = 4
end)

test("SetManual stores the clamped value and sends SSF_CAP_CHANGED once per change", function()
    profile.autoMax = false
    local got = {}
    local listener = {}
    LibStub("AceEvent-3.0"):Embed(listener)
    listener:RegisterMessage("SSF_CAP_CHANGED", function(_, cap) got[#got + 1] = cap end)
    Cap:SetManual(8) -- establishes the baseline for change detection
    got = {}
    Cap:SetManual(300)
    eq(profile.maxShards, 100, "stored clamped")
    eq(#got, 1, "one message")
    eq(got[1], 100, "with the new cap")
    Cap:SetManual(100)
    eq(#got, 1, "no message when the cap did not move")
    listener:UnregisterAllMessages()
    Cap:SetManual(8)
end)
