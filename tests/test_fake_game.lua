-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_fake_game: the fake game's timers behave as the game's do, since every test that
-- waits leans on them. A timer fires when it falls due, not when it was made; the clock
-- reads each timer's own time as it fires; a cancelled timer never fires; AceTimer, which
-- SSF uses for every wait, keeps that order.
-- Touches nothing else.

test("timers fire in the order they fall due", function()
    local order = {}
    C_Timer.After(0.5, function() order[#order + 1] = "late" end)
    C_Timer.After(0, function() order[#order + 1] = "now" end)
    C_Timer.After(0.5, function() order[#order + 1] = "late, made second" end)
    WoW.RunTimers()
    eq(table.concat(order, ", "), "now, late, late, made second", "by due time, then by when made")
end)

test("the clock reads each timer's own time as it fires", function()
    local start, at = GetTime(), nil
    C_Timer.After(2, function() at = GetTime() end)
    eq(GetTime(), start, "the clock stands still until time passes")
    WoW.RunTimers()
    eq(at, start + 2, "two seconds later")
end)

test("a cancelled timer never fires", function()
    local fired = false
    local t = C_Timer.NewTimer(1, function() fired = true end)
    t:Cancel()
    WoW.RunTimers()
    eq(fired, false, "cancelled")
end)

test("AceTimer keeps the same order", function()
    local probe, order = {}, {}
    LibStub("AceTimer-3.0"):Embed(probe)
    probe:ScheduleTimer(function() order[#order + 1] = "half" end, 0.5)
    probe:ScheduleTimer(function() order[#order + 1] = "tick" end, 0)
    local gone = probe:ScheduleTimer(function() order[#order + 1] = "cancelled" end, 0.2)
    probe:CancelTimer(gone)
    WoW.RunTimers()
    eq(table.concat(order, ", "), "tick, half", "due order, and a cancelled AceTimer does not fire")
end)
