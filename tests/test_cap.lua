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
