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

test("dragging the window saves the spot with the screen size", function()
    shut()
    profile.welcomed = 99999
    profile.window = {}
    Window:Open()
    Window.window:Fire("OnMoved", 512, 256)
    eq(profile.window.top, 512, "top")
    eq(profile.window.left, 256, "left")
    eq(profile.window.width, UIParent:GetWidth(), "the screen's width")
    eq(profile.window.height, UIParent:GetHeight(), "the screen's height")
end)
