-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_owners: the rules several modules share, each asked of its one owner. Combat's two
-- questions told apart (the lockdown; in a fight, which starts a moment sooner).
-- Cap:IsOver, the delete gate. Cap:SetLowMark, the low mark's one setter, and LowMark,
-- never read above the cap. Trimmer:Paused, the pause gate, which Sorter:Pass asks
-- itself: paused, no pass moves a shard, whoever calls it, and a pass held back from
-- before the pause is dropped. Colors refuses a state that is not on its scale.
-- Reads:   Combat, Cap, Trimmer, Sorter, Bags, Colors, Window; WoW.combat, WoW.flagged,
--          WoW.picks, WoW.Settle, WoW.FireEvent, WoW.RunTimers.
-- Saves:   profile.paused, autoMax, maxShards, lowMark, for the test at hand.
-- Touches nothing else.

local SHARD = SSF.SHARD_ITEM_ID
local Combat = SSF:GetModule("Combat")
local Cap = SSF:GetModule("Cap")
local Trimmer = SSF:GetModule("Trimmer")
local Sorter = SSF:GetModule("Sorter")
local Colors = SSF:GetModule("Colors")
local Window = SSF:GetModule("Window")
local profile = SSF.db.profile

test("Combat: the lockdown and the fight are two questions", function()
    eq(Combat:Locked(), false, "peace: not locked")
    eq(Combat:InFight(), false, "peace: not in a fight")
    WoW.flagged = true
    eq(Combat:Locked(), false, "the fight just started: the lockdown is not on yet")
    eq(Combat:InFight(), true, "but it is a fight already")
    WoW.flagged, WoW.combat = nil, true
    eq(Combat:Locked(), true, "locked")
    eq(Combat:InFight(), true, "and in a fight")
end)

test("the window stays shut from the first moment of a fight", function()
    if Window.window then Window.window:Hide() end
    WoW.flagged = true
    Window:Open()
    ok(not (Window.window and Window.window.frame:IsShown()), "flagged, not yet locked: no window")
end)

test("Cap:IsOver is the delete gate, and State's over is the same test", function()
    profile.paused, profile.autoMax, profile.maxShards, profile.lowMark = false, false, 5, 2
    eq(Cap:IsOver(5), false, "at the cap: not over")
    eq(Cap:IsOver(6), true, "one more: over")
    eq(Cap:State(6), "over", "State agrees")
    eq(Trimmer:WhyNot(6), nil, "a press would delete")
    eq(Trimmer:WhyNot(5), "atcap", "at the cap it would not")
    profile.paused = true
    eq(Cap:IsOver(6), true, "paused: still over the cap, as a count")
    eq(Trimmer:WhyNot(6), "paused", "but a press would not delete")
end)

test("the low mark has one setter, and is never above the cap", function()
    profile.paused, profile.autoMax, profile.maxShards = false, false, 10
    Cap:SetLowMark(15)
    eq(profile.lowMark, 10, "set above the cap: held at the cap")
    Cap:SetLowMark(0)
    eq(profile.lowMark, Cap.MIN, "set under the floor: held at MIN")
    Cap:SetLowMark(4)
    eq(profile.lowMark, 4, "in range: as set")
    -- the cap drops before Cap has heard about it: whoever reads first reads it right
    profile.lowMark, profile.maxShards = 8, 5
    eq(Cap:LowMark(), 5, "never read above the cap, even before Recompute")
    eq(Cap:State(4), "low", "so a count under the cap reads against the right mark")
    Cap:Recompute()
    eq(profile.lowMark, 5, "Recompute writes the saved mark down to the same number")
end)

test("the window's low mark slider goes through Cap", function()
    profile.autoMax, profile.maxShards, profile.lowMark = false, 10, 4
    local Registry = LibStub("AceConfigRegistry-3.0")
    local slider = Registry:GetOptionsTable("SSF", "dialog", "AceConfigDialog-3.0").args.cap.args.lowmark
    slider.set(nil, 50)
    eq(profile.lowMark, 10, "a value past the cap is held at the cap")
    eq(slider.get(), 10, "and read back as saved")
end)

test("Trimmer:Paused is the pause gate", function()
    profile.paused = false
    eq(Trimmer:Paused(), false, "not paused")
    profile.paused = true
    eq(Trimmer:Paused(), true, "paused")
end)

-- a loose shard in the backpack and a free slot in the soul bag: one move waiting
local function LooseShard()
    WoW.SetBags({ [0] = WoW.PlainBag(16, { [3] = SHARD }), [4] = WoW.SoulBag(4) })
end

test("paused, Sorter:Pass moves nothing, whoever calls it", function()
    LooseShard()
    profile.paused = true
    eq(Sorter:Pass(), 0, "no move fired")
    eq(#WoW.picks, 0, "nothing was picked up")
    profile.paused = false
    eq(Sorter:Pass(), 1, "unpaused, the same call moves the shard")
end)

test("a pause while a pass is held back drops it", function()
    -- two loose shards, the second still locked by the server: the pass is held back
    -- until the lock clears
    WoW.SetBags({ [0] = WoW.PlainBag(16, { [3] = SHARD, [5] = SHARD }, { [5] = true }), [4] = WoW.SoulBag(4) })
    profile.paused = false
    eq(Sorter:Pass(), 0, "a shard is locked: the pass is held back")
    profile.paused = true
    WoW.bags[0].locked = {}
    WoW.FireEvent("ITEM_LOCK_CHANGED", 0, 5) -- the lock clears: the held pass would run now
    WoW.RunTimers()
    eq(#WoW.picks, 0, "paused in between: the held pass moves nothing")
    profile.paused = false
    WoW.FireEvent("ITEM_LOCK_CHANGED", 0, 5)
    WoW.FireEvent("BAG_UPDATE", 0)
    WoW.RunTimers()
    eq(#WoW.picks, 0, "and nothing is left waiting to run after the unpause")
end)

test("paused when the fight ends, the noted sort does not run", function()
    LooseShard()
    profile.paused = false
    WoW.combat = true
    eq(Sorter:Pass(), 0, "in combat: noted, nothing moves")
    profile.paused = true
    WoW.combat = false
    WoW.FireEvent("PLAYER_REGEN_ENABLED")
    eq(#WoW.picks, 0, "the fight ended while paused: nothing moves")
    profile.paused = false
    WoW.FireEvent("PLAYER_REGEN_ENABLED")
    eq(#WoW.picks, 0, "and the note is gone: a later fight's end moves nothing either")
end)

-- Nothing in SSF switches a module off today, but nothing may rely on that: every module
-- can be switched off and on again with no error and no second frame.
test("every module can be switched off and on again", function()
    local button = _G.SSFDelete
    local names = {}
    for name in pairs(SSF.modules) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local module = SSF.modules[name]
        local frames, errors = #WoW.frames, #WoW.errors
        module:Disable()
        module:Enable()
        WoW.RunTimers()
        -- IsEnabled only says it was asked to be on; AceAddon's own status says OnEnable ran
        eq(LibStub("AceAddon-3.0").statuses[module.name], true, name .. ": on again, its OnEnable run")
        eq(#WoW.frames, frames, name .. ": no frame made a second time")
        eq(#WoW.errors, errors, name .. ": no error")
    end
    ok(_G.SSFDelete == button, "/click SSFDelete still finds the first button")
    -- and the window's hook on AceConfigDialog's Open is live again after Window's restart
    local Window = SSF:GetModule("Window")
    Window:Open()
    WoW.RunTimers()
    ok(Window:IsHooked(LibStub("AceConfigDialog-3.0"), "Open"), "Window's hook on AceConfigDialog.Open is back")
    Window.window:Hide()
end)

test("Colors refuses a state that is not on its scale", function()
    local okay, err = pcall(Colors.ForState, Colors, "starving")
    eq(okay, false, "ForState: an error, not a quiet white")
    ok(tostring(err):find("starving", 1, true) ~= nil, "that names the state")
    eq(pcall(Colors.PaintState, Colors, "starving", "x"), false, "PaintState: the same")
    for _, state in ipairs({ "paused", "quiet", "over", "low", "ok" }) do
        ok(pcall(Colors.ForState, Colors, state), state .. " is on the scale")
    end
end)
