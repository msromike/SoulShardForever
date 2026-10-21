-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_status: the one wording for the numbers, with its color codes, as chat, the window
-- and the minimap tooltip all build from it. Color codes are checked by their hex.

local Status = SSF:GetModule("Status")
local profile = SSF.db.profile
local SHARD = 6265

local function plain(text) return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

test("CapText and StatusText are one wording", function()
    profile.paused = false
    profile.autoMax = false
    profile.maxShards = 8
    profile.lowMark = 4
    eq(plain(Status:CapText(5, 8)), "5 (cap 8)", "broker text")
    eq(plain(Status:StatusText(5, 8)), "Soul Shards: 5 (cap 8)", "chat line wraps the same text")
end)

test("the count carries its state color, the cap the value white", function()
    profile.paused = false
    profile.autoMax = false
    profile.maxShards = 8
    profile.lowMark = 4
    ok(Status:CapText(3, 8):find("|cffff40403|r", 1, true), "3 is red (low)")
    ok(Status:CapText(5, 8):find("|cff00ff005|r", 1, true), "5 is green (ok)")
    ok(Status:CapText(9, 8):find("|cffffd1009|r", 1, true), "9 is yellow (over)")
    ok(Status:CapText(5, 8):find("|cffffffff8|r", 1, true), "the cap is white")
end)

test("CountValue with no count reads the bags", function()
    WoW.SetBags({ [0] = { slots = 16, family = 0, items = { [1] = SHARD, [3] = SHARD } } })
    profile.maxShards = 8
    profile.lowMark = 4
    eq(plain(Status:CountValue()), "2", "two shards in the fake bags")
    eq(plain(Status:CountText()), "Soul Shards: 2", "window top line")
end)

test("LowMarkValue is the saved mark", function()
    profile.autoMax = false
    profile.maxShards = 8
    profile.lowMark = 4
    eq(plain(Status:LowMarkValue()), "4", "as saved")
    profile.lowMark = 73
    eq(plain(Status:LowMarkValue()), "73", "as saved, even above the cap (the tooltip shows the setting)")
    profile.lowMark = 4
end)

test("PausedValue and PauseText", function()
    profile.paused = true
    eq(plain(Status:PauseText()), "SSF paused: Yes", "paused")
    ok(Status:PausedValue():find("|cffff4040", 1, true), "Yes in the one red")
    profile.paused = false
    eq(plain(Status:PauseText()), "SSF paused: No", "running")
    ok(Status:PausedValue():find("|cff00ff00", 1, true), "No in green")
end)
