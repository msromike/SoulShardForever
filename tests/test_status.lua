-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_status: the one wording for the numbers, with its color codes, as chat, the window
-- and the minimap tooltip all build from it. The expected codes are Colors', by name.
-- Reads:   Colors (the expected escape codes).
-- Saves:   profile.paused, autoMax, maxShards, lowMark, for the test at hand.
-- Touches nothing else.

local SHARD = SSF.SHARD_ITEM_ID
local Status = SSF:GetModule("Status")
local Colors = SSF:GetModule("Colors")
local profile = SSF.db.profile

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
    ok(Status:CapText(3, 8):find(Colors:Paint(Colors.RED, 3), 1, true), "3 is red (low)")
    ok(Status:CapText(5, 8):find(Colors:Paint(Colors.GREEN, 5), 1, true), "5 is green (ok)")
    ok(Status:CapText(9, 8):find(Colors:Paint(Colors.YELLOW, 9), 1, true), "9 is yellow (over)")
    ok(Status:CapText(5, 8):find(Colors:Paint(Colors.WHITE, 8), 1, true), "the cap is white")
end)

test("the count is white while paused, everywhere it is painted; the cap stays white", function()
    profile.autoMax = false
    profile.maxShards = 8
    profile.lowMark = 4
    profile.paused = true
    eq(Status:CountValue(3), Colors:Paint(Colors.WHITE, 3), "under the mark: white, not red")
    eq(Status:CountValue(5), Colors:Paint(Colors.WHITE, 5), "in range: white, not green")
    eq(Status:CountValue(9), Colors:Paint(Colors.WHITE, 9), "over the cap: white, not yellow")
    ok(Status:StatusText(9, 8):find(Colors:Paint(Colors.WHITE, 9), 1, true), "the chat line too")
    profile.paused = false
    eq(Status:CountValue(3), Colors:Paint(Colors.RED, 3), "unpaused: red again")
end)

test("CountValue, CountText and InBagsText with no count read the bags", function()
    WoW.SetBags({ [0] = WoW.PlainBag(16, { [1] = SHARD, [3] = SHARD }) })
    profile.maxShards = 8
    profile.lowMark = 4
    eq(plain(Status:CountValue()), "2", "two shards in the fake bags")
    eq(plain(Status:CountText()), "Soul Shards: 2", "window top line")
    eq(plain(Status:InBagsText()), "(in bags: 2)", "the cap command's echo tail")
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
    ok(Status:PausedValue():find(Colors:Paint(Colors.RED, "Yes"), 1, true), "Yes in the one red")
    profile.paused = false
    eq(plain(Status:PauseText()), "SSF paused: No", "running")
    ok(Status:PausedValue():find(Colors:Paint(Colors.GREEN, "No"), 1, true), "No in green")
end)

test("the two press lines wrap StatusText", function()
    WoW.SetBags({ [0] = WoW.PlainBag(16, { [1] = SHARD, [3] = SHARD }) })
    profile.maxShards = 8
    profile.lowMark = 4
    eq(plain(Status:PausedPressText()), "All SSF actions paused. Soul Shards: 2 (cap 8)", "paused press")
    eq(plain(Status:DeletedText(1, 8)), "Deleted a Soul Shard. Soul Shards: 1 (cap 8)", "announce, with the press's count")
end)
