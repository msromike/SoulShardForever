-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_cap: the cap right now, the low mark held under it, State (paused first), IsFull,
-- SetManual and SSF_CAP_CHANGED.
-- Touches nothing else.

local Cap = SSF:GetModule("Cap")
local profile = SSF.db.profile
local soul, plain = WoW.SoulBag, WoW.PlainBag

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

test("the cap dropping under the mark writes the mark down, once; rising leaves it", function()
    profile.autoMax = false
    profile.paused = false
    Cap:SetManual(32)
    profile.lowMark = 20
    Cap:SetManual(15)
    eq(profile.lowMark, 15, "cap 15 under mark 20: the mark follows")
    eq(Cap:LowMark(), 15, "LowMark is the saved mark, nothing hidden")
    Cap:SetManual(32)
    eq(profile.lowMark, 15, "cap back up: the mark stays where the player saw it")
    Cap:SetManual(8)
    profile.lowMark = 4
end)

test("AutoMax writes the bag size into the cap and the mark down to it; off leaves both", function()
    WoW.SetBags({ [0] = plain(16), [2] = soul(6) })
    profile.autoMax = false
    Cap:SetManual(32)
    profile.lowMark = 20
    profile.autoMax = true
    Cap:Recompute()
    eq(Cap:Get(), 6, "cap is the bag")
    eq(profile.maxShards, 6, "and the saved cap is the bag: nothing hidden")
    eq(profile.lowMark, 6, "mark followed")
    profile.autoMax = false
    Cap:Recompute()
    eq(Cap:Get(), 6, "AutoMax off: the cap stays where the player saw it, no jump to 32")
    Cap:SetManual(8)
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

test("State with the mark at the cap: low below, ok at, over above", function()
    profile.autoMax = false
    profile.paused = false
    Cap:SetManual(8)
    profile.lowMark = 8
    eq(Cap:State(33), "over", "33 shards, cap 8: over")
    eq(Cap:State(5), "low", "5 < 8")
    eq(Cap:State(8), "ok", "at the cap and at the mark")
    profile.lowMark = 4
end)

test("IsFull: at or over the cap", function()
    profile.autoMax = false
    profile.maxShards = 8
    eq(Cap:IsFull(7), false, "under")
    eq(Cap:IsFull(8), true, "at")
    eq(Cap:IsFull(9), true, "over")
end)

test("State says paused first, whatever the count; unpaused it is the scale again", function()
    profile.autoMax = false
    Cap:SetManual(8)
    profile.lowMark = 4
    profile.paused = true
    eq(Cap:State(0), "paused", "zero, paused")
    eq(Cap:State(3), "paused", "under the mark, paused: no red")
    eq(Cap:State(8), "paused", "at the cap, paused")
    eq(Cap:State(33), "paused", "over the cap, paused: no yellow")
    profile.paused = false
    eq(Cap:State(3), "low", "unpaused: 3 < 4")
    eq(Cap:State(8), "ok", "unpaused: at the cap")
    eq(Cap:State(33), "over", "unpaused: 33 > 8")
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
