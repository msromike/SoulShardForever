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

-- the chat lines printed while fn runs, color codes taken out
local function printed(fn)
    local from = #WoW.chat
    fn()
    local lines = {}
    for i = from + 1, #WoW.chat do lines[#lines + 1] = plain(WoW.chat[i]) end
    return lines
end

-- a fresh login, as the game announces it, with the login lines not yet printed
local function freshLogin()
    Status.loginStatusPrinted = nil
    Status:PLAYER_ENTERING_WORLD("PLAYER_ENTERING_WORLD", true)
end

test("a fresh login: the lines wait until the count agrees with the game's own", function()
    profile.paused, profile.autoMax, profile.maxShards = false, false, 8
    -- the first login after the game starts: the pouch's shards are not counted yet
    WoW.SetBags({ [0] = WoW.PlainBag(16, { [1] = SHARD }) })
    WoW.itemCount = 3
    eq(#printed(freshLogin), 0, "entering the world prints nothing")
    eq(#printed(function() WoW.FireEvent("BAG_UPDATE_DELAYED") end), 0, "bags ready, the count short of the game's: nothing yet")
    eq(#printed(function() WoW.FireEvent("GET_ITEM_INFO_RECEIVED", 1, true) end), 0, "an item's data, still short: nothing yet")
    -- the game now says the pouch is a soul bag
    WoW.SetBags({ [0] = WoW.PlainBag(16, { [1] = SHARD }), [5] = WoW.SoulBag(14, { [1] = SHARD, [2] = SHARD }) })
    WoW.itemCount = nil
    local lines = printed(function() WoW.FireEvent("GET_ITEM_INFO_RECEIVED", SHARD, true) end)
    eq(lines[2], "SSF: Soul Shards: 3 (cap 8)", "the count agrees: the lines print, with the right number")
    eq(#printed(function() WoW.FireEvent("BAG_UPDATE_DELAYED") end), 0, "once: a later signal prints nothing")
end)

test("a fresh login with the bags readable at once prints at the first signal", function()
    profile.paused, profile.autoMax, profile.maxShards = false, false, 8
    WoW.SetBags({ [0] = WoW.PlainBag(16, { [1] = SHARD }), [5] = WoW.SoulBag(14, { [1] = SHARD }) })
    eq(#printed(freshLogin), 0, "entering the world prints nothing")
    local lines = printed(function() WoW.FireEvent("BAG_UPDATE_DELAYED") end)
    eq(lines[2], "SSF: Soul Shards: 2 (cap 8)", "bags ready and agreeing: printed")
end)

test("a fresh login where the count never agrees still prints, when the timer runs out", function()
    profile.paused, profile.autoMax, profile.maxShards = false, false, 8
    WoW.SetBags({ [0] = WoW.PlainBag(16, { [1] = SHARD }) })
    WoW.itemCount = 3
    eq(#printed(freshLogin), 0, "entering the world prints nothing")
    eq(#printed(function() WoW.FireEvent("BAG_UPDATE_DELAYED") end), 0, "short: nothing")
    local lines = printed(function() Status:PrintLoginStatus() end)
    eq(lines[2], "SSF: Soul Shards: 1 (cap 8)", "the timer's call prints what SSF counts")
    WoW.itemCount = nil
end)

test("a reload prints the lines at once", function()
    profile.paused, profile.autoMax, profile.maxShards = false, false, 8
    WoW.SetBags({ [0] = WoW.PlainBag(16, { [1] = SHARD }) })
    Status.loginStatusPrinted = nil
    local lines = printed(function() Status:PLAYER_ENTERING_WORLD("PLAYER_ENTERING_WORLD", false) end)
    eq(lines[2], "SSF: Soul Shards: 1 (cap 8)", "printed on entering the world")
end)

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

-- Cap owns what the low mark is, and it is never above the cap. The tooltip asks Cap; it
-- does not read the saved number itself.
test("LowMarkValue is Cap's low mark, never above the cap", function()
    profile.autoMax = false
    profile.maxShards = 8
    profile.lowMark = 4
    eq(plain(Status:LowMarkValue()), "4", "under the cap: the mark")
    profile.lowMark = 73
    eq(plain(Status:LowMarkValue()), "8", "a saved number above the cap: the cap, as everywhere else")
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
