-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_window: three rules around the window that live in three modules. Help:Apply (an
-- option with a help line shows it only while help is on; one without never shows a
-- tooltip; a chat command is left alone). The welcome note's life (owed until the player
-- closes it outside a fight; a fight that closes it leaves it owed; learning Drain Soul
-- owes it again under its own title, shown when the trainer closes). And where the window
-- opens (the saved spot only on the screen size it was saved on; an open SSF makes by
-- itself forgets the spot).
-- The window is the real one. What shows in it is asked of the stub's frames
-- (WoW.Controls), as tests/window.lua does.
-- Reads:   Help, Welcome, Window, Cap.QUIET_UNTIL; AceConfigDialog's status table for the
--          app (where Window:Open puts the spot); WoW.Controls, WoW.FireEvent, WoW.combat,
--          WoW.unknownSpells.
-- Saves:   profile.welcomed, welcomeAgain, window, for the test at hand.
-- Touches nothing else.

local Help = SSF:GetModule("Help")
local Welcome = SSF:GetModule("Welcome")
local Window = SSF:GetModule("Window")
local Cap = SSF:GetModule("Cap")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local profile = SSF.db.profile

-- is this text on screen in the window (the notes beside it included)?
local function showing(text)
    if not Window.window then return false end
    for _, control in ipairs(WoW.Controls(Window.window.frame)) do
        if control.shown and control.text == text then return true end
    end
    return false
end

local function open() return Window.window ~= nil and Window.window.frame:IsShown() end

-- the window shut and no note open, out of a fight: the same start for every test here
local function shut()
    WoW.combat = false
    if Window.window then Window.window:Hide() end
    Welcome.noteOpen = false
end

-- ---------------------------------------------------------------- Help:Apply

test("Help:Apply: a help line shows only while help is on; no help line, no tooltip", function()
    local root = { args = {
        withHelp = { desc = "a help line" },
        without = {},
        group = { args = { inner = { desc = "inside a group" }, innerWithout = {} } },
        chat = { desc = "AceConfigCmd's help text", dialogHidden = true },
    } }
    if Help:IsOn() then Help:Toggle() end
    Help:Apply(root)
    eq(root.args.withHelp.descStyle, "hidden", "help off: hidden")
    eq(root.args.group.args.inner.descStyle, "hidden", "help off, in a group: hidden")
    eq(root.args.without.descStyle, "hidden", "no help line: hidden")
    eq(root.args.chat.descStyle, nil, "a chat command is left alone")
    Help:Toggle()
    Help:Apply(root)
    eq(root.args.withHelp.descStyle, "tooltip", "help on: a tooltip")
    eq(root.args.group.args.inner.descStyle, "tooltip", "help on, in a group: a tooltip")
    eq(root.args.without.descStyle, "hidden", "no help line: still hidden")
    eq(root.args.group.args.innerWithout.descStyle, "hidden", "no help line in a group: still hidden")
    eq(root.args.chat.descStyle, nil, "a chat command is still left alone")
    eq(root.args.group.descStyle, nil, "a group itself gets none")
end)

test("Help:Toggle flips the switch and the options table follows", function()
    local Registry = LibStub("AceConfigRegistry-3.0")
    local function style()
        return Registry:GetOptionsTable("SSF", "dialog", "AceConfigDialog-3.0").args.cap.args.automax.descStyle
    end
    if Help:IsOn() then Help:Toggle() end
    eq(style(), "hidden", "off: the real table's options are hidden")
    Help:Toggle()
    eq(Help:IsOn(), true, "on")
    eq(style(), "tooltip", "and the real table was rebuilt with tooltips")
end)

-- ---------------------------------------------------------------- the welcome note

test("the welcome is owed until the player closes it outside a fight", function()
    shut()
    profile.welcomed, profile.welcomeAgain = false, false
    Window:Open()
    ok(showing("Welcome to SSF"), "any open of the window brings the owed note with it")
    eq(profile.welcomed, false, "still owed while it shows")
    Window.window:Hide()
    ok(type(profile.welcomed) == "number", "closed outside a fight: this version is marked seen")
    Window:Open()
    ok(open(), "the window opens again")
    ok(not showing("Welcome to SSF"), "without the note")
end)

test("a fight that closes the note leaves it owed", function()
    shut()
    profile.welcomed, profile.welcomeAgain = false, false
    Window:Open()
    ok(showing("Welcome to SSF"), "showing")
    WoW.combat = true
    WoW.FireEvent("PLAYER_REGEN_DISABLED")
    ok(not open(), "the fight closed the window")
    eq(profile.welcomed, false, "and the note is still owed")
    Window:Open()
    ok(not open(), "nothing opens in the fight")
    WoW.combat = false
    Window:Open()
    ok(showing("Welcome to SSF"), "after the fight the next open brings it back")
end)

test("Welcome:Show in a fight does nothing", function()
    shut()
    profile.welcomed = 99999
    WoW.combat = true
    Welcome:Show()
    eq(profile.welcomed, 99999, "nothing is owed by it")
    ok(not open(), "and nothing opened")
end)

test("Create macros shows the note again, and closing it settles it again", function()
    shut()
    profile.welcomed = 99999
    Window:Open()
    ok(not showing("Welcome to SSF"), "seen: no note")
    Welcome:SendMessage("SSF_SHOW_WELCOME")
    ok(showing("Welcome to SSF"), "the note is back")
    eq(profile.welcomed, false, "and owed until closed")
    Window.window:Hide()
    ok(type(profile.welcomed) == "number", "closed: settled")
end)

test("learning Drain Soul owes the note again, shown when the trainer closes", function()
    shut()
    profile.welcomed, profile.welcomeAgain = 99999, false
    Welcome:OnQuietEnded(nil, false)
    eq(profile.welcomed, 99999, "found known at login: nothing owed")
    Welcome:OnQuietEnded(nil, true)
    eq(profile.welcomed, false, "learned: owed again")
    eq(profile.welcomeAgain, true, "under its own title")
    ok(not open(), "not shown while the trainer is open")
    WoW.FireEvent("TRAINER_CLOSED")
    ok(showing("You learned Drain Soul"), "shown when the trainer closes, with the second title")
    Window.window:Hide()
    eq(profile.welcomeAgain, false, "closed: the second title is done")
    WoW.FireEvent("TRAINER_CLOSED")
    ok(not open(), "a later trainer visit shows nothing")
end)

test("seen and closed at the trainer, the note does not come back when the trainer closes", function()
    shut()
    profile.welcomed, profile.welcomeAgain = 99999, false
    Welcome:OnQuietEnded(nil, true) -- learned at the trainer: owed again
    Window:Open()                   -- the player opens SSF's window before leaving the trainer
    ok(showing("You learned Drain Soul"), "the note comes up with the window")
    Window.window:Hide()            -- and he closes it outside a fight
    ok(type(profile.welcomed) == "number", "seen: settled")
    WoW.FireEvent("TRAINER_CLOSED")
    ok(not open(), "the trainer closing brings nothing back")
    ok(type(profile.welcomed) == "number", "and the note is not owed again")
end)

test("a trainer closing shows the welcome only while it is still owed", function()
    shut()
    profile.welcomed, profile.welcomeAgain = 99999, false -- seen and settled
    Welcome:RegisterEvent("TRAINER_CLOSED")              -- a wait left over, whatever its cause
    WoW.FireEvent("TRAINER_CLOSED")
    ok(not open(), "settled: a trainer closing shows nothing")
end)

test("before Drain Soul the note leads with the line about level 10", function()
    shut()
    local lead = "For now you can play around with the addon. When you learn Drain Soul at level 10, we'll show you this window again."
    profile.welcomed = false
    Window:Open()
    ok(not showing(lead), "Drain Soul known: no lead line")
    shut()
    profile.welcomed = false
    WoW.unknownSpells[Cap.QUIET_UNTIL] = true
    Window:Open()
    ok(showing(lead), "not known yet: the lead line shows")
end)

-- ---------------------------------------------------------------- where the window opens

local function spot() -- where Window:Open told AceConfigDialog to put the window
    local status = AceConfigDialog:GetStatusTable("SSF")
    return status.top, status.left
end

test("the saved spot is used only on the screen size it was saved on", function()
    shut()
    profile.welcomed = 99999
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    profile.window = { top = 700, left = 300, width = w, height = h }
    Window:Open()
    local top, left = spot()
    ok(top == 700 and left == 300, "same screen: the saved spot")
    shut()
    profile.window = { top = 700, left = 300, width = w + 640, height = h }
    Window:Open()
    top, left = spot()
    ok(top == nil and left == nil, "another screen size: centered")
    ok(profile.window.top == 700, "and the saved spot is kept for the screen it belongs to")
    shut()
    profile.window = { top = 700, left = 300 }
    Window:Open()
    top, left = spot()
    ok(top == nil and left == nil, "a spot saved with no screen size: centered")
    shut()
    profile.window = {}
    Window:Open()
    top, left = spot()
    ok(top == nil and left == nil, "never dragged: centered")
end)

test("an open SSF makes by itself forgets the spot; the player's own open keeps it", function()
    shut()
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    profile.welcomed = false
    profile.window = { top = 700, left = 300, width = w, height = h }
    Welcome:Show() -- the player's own (Create macros)
    ok(profile.window.top == 700, "the player's own open keeps the spot")
    shut()
    profile.welcomed = false
    Welcome:Show(true) -- SSF's own (at load, after a learn)
    ok(profile.window.top == nil and profile.window.left == nil, "SSF's own open forgets it")
    local top, left = spot()
    ok(top == nil and left == nil, "and the window opens centered")
end)

-- the window's text for the pause setting: what a redraw would change
local function pauseTicked()
    local Registry = LibStub("AceConfigRegistry-3.0")
    return Registry:GetOptionsTable("SSF", "dialog", "AceConfigDialog-3.0").args.pausegroup.args.pauseGui.get()
end

test("a change from anywhere but the window redraws an open window", function()
    shut()
    profile.welcomed = 99999
    Window:Open()
    local feeds = 0
    local real = Window.Refresh
    function Window:Refresh() feeds = feeds + 1 return real(self) end
    local okay, err = pcall(function()
        Window:SendMessage("SSF_OPTIONS_CHANGED", "pause", "chat")
        eq(feeds, 0, "not inside the message")
        WoW.RunTimers()
        eq(feeds, 1, "a chat command: redrawn, a tick later")
        Window:SendMessage("SSF_OPTIONS_CHANGED", "pause", "window")
        WoW.RunTimers()
        eq(feeds, 1, "the window's own control: not redrawn (AceConfigDialog does it)")
        Window:SendMessage("SSF_OPTIONS_CHANGED", "pause")
        Window:SendMessage("SSF_OPTIONS_CHANGED", "log")
        WoW.RunTimers()
        eq(feeds, 2, "a source not named: redrawn; two in one tick make one redraw")
        -- a deleted shard (sent from inside Delete Shard's click) and a bag change: never
        -- a rebuild inside the message
        Window:SendMessage("SSF_SHARD_DELETED", 1, 2, 0, 1)
        eq(feeds, 2, "a deleted shard: not redrawn inside the message")
        WoW.RunTimers()
        eq(feeds, 3, "a deleted shard: redrawn a tick later")
        Window:SendMessage("SSF_BAGS_CHANGED")
        eq(feeds, 3, "a bag change: not redrawn inside the message")
        WoW.RunTimers()
        eq(feeds, 4, "a bag change: redrawn a tick later")
    end)
    Window.Refresh = real
    assert(okay, err)
    ok(pauseTicked() ~= nil, "the pause setting is readable")
end)

-- The click on Delete Shard deletes a shard, which sends SSF_SHARD_DELETED while
-- AceConfigDialog is still inside the button's func. Spare buttons in AceGUI's pool (in
-- the game: after SSF's page in Blizzard's options was opened and closed) make a rebuild
-- right then hand back a different button and break AceConfigDialog's read-back.
test("clicking Delete Shard in the window raises no error, with spare buttons pooled", function()
    shut()
    profile.welcomed, profile.paused, profile.autoMax, profile.maxShards = 99999, false, false, 2
    local items = {}
    for i = 1, 8 do items[i] = SSF.SHARD_ITEM_ID end
    WoW.SetBags({ [0] = WoW.PlainBag(16, items), [4] = WoW.SoulBag(20) })
    local AceGUI, spares = LibStub("AceGUI-3.0"), {}
    for i = 1, 5 do spares[i] = AceGUI:Create("SSFCountButton") end
    for i = 1, 5 do AceGUI:Release(spares[i]) end
    Window:Open()
    WoW.RunTimers()
    local function find(widget)
        if widget.type == "SSFCountButton" then return widget end
        for _, child in ipairs(widget.children or {}) do
            local hit = find(child)
            if hit then return hit end
        end
    end
    local errors = #WoW.errors
    for click = 1, 4 do
        local button = find(Window.window)
        button.inner.frame:GetScript("OnClick")(button.inner.frame, "LeftButton")
        WoW.Settle()
    end
    eq(#WoW.deleted, 4, "four clicks, four deletes")
    eq(#WoW.errors, errors, "and no error the game would show in red")
end)

test("a redraw AceConfigDialog makes after a change in the window is refit a tick later", function()
    shut()
    profile.welcomed = 99999
    Window:Open()
    WoW.RunTimers()
    local feeds = 0
    local real = Window.Refresh
    function Window:Refresh() feeds = feeds + 1 return real(self) end
    local okay, err = pcall(function()
        -- what AceConfigDialog does after a set made in the window
        LibStub("AceConfigDialog-3.0"):Open("SSF", Window.window)
        eq(feeds, 0, "not inside AceConfigDialog's redraw")
        WoW.RunTimers()
        eq(feeds, 1, "refit a tick later")
        WoW.RunTimers()
        eq(feeds, 1, "once: SSF's own refit does not ask for another")
    end)
    Window.Refresh = real
    assert(okay, err)
end)

test("an open does not start a second open of itself", function()
    shut()
    profile.welcomed = false -- the welcome is owed: its note opens the window inside this open
    local opened = 0
    local ear = LibStub("AceEvent-3.0"):Embed({})
    ear:RegisterMessage("SSF_WINDOW_OPENED", function() opened = opened + 1 end)
    Window:Open()
    ear:UnregisterAllMessages()
    eq(opened, 1, "one open, one message, with the note brought back inside it")
    ok(showing("Welcome to SSF"), "the note is showing")
end)

test("the first open's second fit does not reopen a window closed in that tick", function()
    shut()
    profile.welcomed = 99999
    Window.window = nil -- the session's first open: it schedules the second fit
    Window:Open()
    Window.window:Hide()
    WoW.RunTimers()
    ok(not open(), "still closed")
end)

-- AceConfigDialog calls an option's set on every drag tick and again at the let-go; the
-- slider's `released` is the let-go alone, which is what the pause sound's preview plays on.
test("the slider tells its option of a let-go once, not of every drag tick", function()
    local AceGUI = LibStub("AceGUI-3.0")
    local slider = AceGUI:Create("SSFStepperSlider")
    local released, ups = {}, 0
    slider:SetSliderValues(0, 1, 0.25)
    slider:SetValue(0.5)
    slider:SetCustomData({ released = function(value) released[#released + 1] = value end })
    slider:SetCallback("OnMouseUp", function() ups = ups + 1 end)
    slider.inner:Fire("OnValueChanged", 0.75) -- a drag tick
    eq(#released, 0, "a drag tick: not told")
    slider.inner:Fire("OnMouseUp", 0.75) -- the handle let go, or a typed value entered
    eq(#released, 1, "the let-go: told once")
    eq(released[1], 0.75, "with the value")
    eq(ups, 1, "after AceConfigDialog heard the same let-go")
    slider.inner:SetValue(0.5)
    slider.right:GetScript("OnClick")(slider.right) -- "+"
    eq(#released, 2, "a press of +: told once")
    eq(released[2], 0.75, "with the value one notch up")
    slider.left:GetScript("OnClick")(slider.left) -- "-"
    eq(#released, 3, "a press of -: told once")
    slider:SetCustomData(4) -- a plain bound, as the Low shard mark's slider gets
    slider.inner:Fire("OnMouseUp", 0.5)
    eq(#released, 3, "a slider with only a bound: nobody told")
    AceGUI:Release(slider)
end)

-- The pause sound slider shows where its thumb can rest: one tick per notch. A slider that
-- did not ask for them (Shards to keep, Low shard mark) shows none.
test("a slider with notches shows one tick at each step, and none otherwise", function()
    local AceGUI = LibStub("AceGUI-3.0")
    local slider = AceGUI:Create("SSFStepperSlider")
    local function shown()
        local n = 0
        for _, tick in ipairs(slider.notchTicks) do
            if tick:IsShown() then n = n + 1 end
        end
        return n
    end
    slider:SetSliderValues(0, 1, 0.25)
    eq(shown(), 0, "not asked for: no ticks")
    slider:SetCustomData({ notches = true })
    eq(shown(), 5, "0, 25, 50, 75 and 100%: five ticks")
    slider:SetSliderValues(0, 1, 0.5)
    eq(shown(), 3, "a coarser scale: the spare ticks are hidden")
    slider:SetCustomData(4) -- a plain bound, as the Low shard mark's slider gets
    eq(shown(), 0, "a slider with only a bound: none")
    slider:SetCustomData({ notches = true })
    AceGUI:Release(slider)
    slider = AceGUI:Create("SSFStepperSlider")
    eq(shown(), 0, "handed to another row: the ticks do not come along")
    AceGUI:Release(slider)
end)

test("dragging the window saves the spot with the screen size", function()
    shut()
    profile.welcomed = 99999
    profile.window = {}
    Window:Open()
    -- the player's drag on the title, through AceGUI's own mouse handlers and SSFFrame's hook
    WoW.Drag(Window.window.titletext:GetParent(), 512, 256)
    eq(profile.window.top, 512, "top")
    eq(profile.window.left, 256, "left")
    eq(profile.window.width, UIParent:GetWidth(), "the screen's width")
    eq(profile.window.height, UIParent:GetHeight(), "the screen's height")
end)
