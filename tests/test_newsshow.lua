-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_newsshow: when the announcement is owed, and when and how NewsShow shows it. The
-- window is the real module with the two methods NewsShow asks of it replaced for this
-- file (put back at its end): each records what was asked and answers an open the way the
-- real one does (the window-opened message comes back before the note shows), and counts
-- the opens NewsShow marks as its own (auto: the real window centers those). The check
-- holds the replaced names to Window's Public, so a rename there fails here too. The
-- announcement is one the tests swap in (WoW.NS.news), its lines added the way a
-- News\News_<code>.lua adds them, so nothing here depends on the announcement that ships.
-- Reads:   NewsShow; NS.AddLocaleStrings (Locales\Register.lua); Colors (the expected gold).
-- Saves:   profile.newsSeen, for the test at hand.
-- Touches nothing else.

local NS = WoW.NS
local shipped = NS.news -- the announcement that ships, put back at the end of this file
local NewsShow = SSF:GetModule("NewsShow")
local profile = SSF.db.profile
local ID = 11400

NS.AddLocaleStrings("enUS", { ["A test title"] = true, ["First line."] = true, ["Second line."] = true })

-- what NewsShow asked of the window since the last fresh()
local asked
local Window = SSF:GetModule("Window")
local real = { ShowLeftNote = Window.ShowLeftNote, RefreshLeftNote = Window.RefreshLeftNote }
function Window:ShowLeftNote(title, opts, auto)
    if auto then asked.centered = asked.centered + 1 end
    NewsShow:OnWindowOpened() -- the real open sends SSF_WINDOW_OPENED before the note shows
    asked.shown[#asked.shown + 1] = { title = title, opts = opts }
end
function Window:RefreshLeftNote(title, opts)
    asked.refilled[#asked.refilled + 1] = { title = title, opts = opts }
end

local function sample(id, on)
    return { id = id or ID, on = on ~= false, title = "A test title", text = { "First line.", "Second line." } }
end

-- a clean slate: this announcement, nothing ticked, nothing showing, no event waited for
local function fresh(news)
    NS.news = news
    profile.newsSeen = false
    NewsShow.noteOpen = nil
    NewsShow:UnregisterAllEvents()
    asked = { centered = 0, shown = {}, refilled = {} }
end

test("owed until ticked; a newer one is owed again; none or switched off is never owed", function()
    fresh(nil)
    eq(NewsShow:Owed(), false, "no announcement shipped")
    fresh(sample())
    eq(NewsShow:Owed(), true, "unticked")
    profile.newsSeen = ID
    eq(NewsShow:Owed(), false, "ticked")
    NS.news = sample(ID + 100)
    eq(NewsShow:Owed(), true, "a newer announcement after an old one was ticked")
    fresh(sample(ID, false))
    eq(NewsShow:Owed(), false, "switched off, unticked")
    profile.newsSeen = ID
    eq(NewsShow:Owed(), false, "switched off, ticked")
end)

test("a load opens it by itself, centered, once the loading screen is gone", function()
    fresh(sample())
    NewsShow:OnEnable()
    eq(#asked.shown, 0, "waits for the loading screen")
    WoW.FireEvent("LOADING_SCREEN_DISABLED")
    eq(#asked.shown, 1, "shown once")
    eq(asked.centered, 1, "the window centered first")
    local note = asked.shown[1]
    eq(note.title, "A test title", "the title")
    eq(#note.opts.blocks, 2, "both paragraphs")
    eq(note.opts.blocks[2].text, "Second line.", "in order")
    eq(note.opts.tick, "Don't show this again", "the tick box")
    eq(note.opts.ticked, false, "unticked")
    eq(note.opts.button, "Remind me later", "the button, unticked")
    eq(note.opts.buttonTicked, "Got it", "the button, ticked")
    note.opts.onClose()
    WoW.FireEvent("LOADING_SCREEN_DISABLED")
    eq(#asked.shown, 1, "a later loading screen opens nothing")
end)

test("a paragraph's lead is gold, its text follows in white after two spaces", function()
    local Colors = SSF:GetModule("Colors")
    local news = sample()
    news.text = { { lead = "A test title", blank = true }, { lead = "First line.", text = "Second line." }, "Second line." }
    fresh(news)
    NewsShow:OnWindowOpened()
    local blocks = asked.shown[1].opts.blocks
    eq(blocks[1].text, Colors:Gold("A test title"), "a lead alone: the whole paragraph gold")
    eq(blocks[2].text, Colors:Gold("First line.") .. "  Second line.", "lead in gold, two spaces, the text plain")
    eq(blocks[3].text, "Second line.", "a plain line stays plain")
    eq(blocks[1].blank, true, "a blank line asked for is passed on")
    eq(blocks[2].blank, nil, "and only where it was asked for")
end)

test("a load in a fight opens nothing, nor when the fight ends; the next open shows it", function()
    fresh(sample())
    NewsShow:OnEnable()
    WoW.combat = true
    WoW.FireEvent("LOADING_SCREEN_DISABLED")
    eq(#asked.shown, 0, "nothing in the fight")
    eq(asked.centered, 0, "the window not moved")
    WoW.combat = false
    WoW.FireEvent("PLAYER_REGEN_ENABLED")
    eq(#asked.shown, 0, "nothing when the fight ends")
    NewsShow:OnWindowOpened()
    eq(#asked.shown, 1, "with the player's own open")
    eq(asked.centered, 0, "on his spot, not centered")
end)

test("closed without the tick it comes back; ticked it stays gone; unticked it is owed again", function()
    fresh(sample())
    NewsShow:OnWindowOpened()
    eq(#asked.shown, 1, "shown with the window")
    NewsShow:OnWindowOpened()
    eq(#asked.shown, 1, "not shown over itself")
    asked.shown[1].opts.onClose()
    NewsShow:OnWindowOpened()
    eq(#asked.shown, 2, "back with the next open")
    local opts = asked.shown[2].opts
    opts.onTick(true)
    eq(profile.newsSeen, ID, "the tick saves the id at once")
    opts.onClose()
    NewsShow:OnWindowOpened()
    eq(#asked.shown, 2, "ticked: gone")

    fresh(sample())
    NewsShow:OnWindowOpened()
    opts = asked.shown[1].opts
    opts.onTick(true)
    opts.onTick(false)
    eq(profile.newsSeen, false, "the untick takes it back at once")
    opts.onClose()
    NewsShow:OnWindowOpened()
    eq(#asked.shown, 2, "unticked: back with the next open")
end)

test("a rebuild (a Language change) fills the open panel again, the tick as it was left", function()
    fresh(sample())
    NewsShow:OnOptionsRebuilt()
    eq(#asked.refilled, 0, "nothing while the panel is closed")
    NewsShow:OnWindowOpened()
    NewsShow:OnOptionsRebuilt()
    eq(#asked.refilled, 1, "filled again while open")
    eq(#asked.shown, 1, "without another open of the window")
    eq(asked.refilled[1].opts.ticked, false, "still unticked")
    asked.shown[1].opts.onTick(true)
    NewsShow:OnOptionsRebuilt()
    eq(asked.refilled[2].opts.ticked, true, "the tick survives")
    eq(asked.refilled[2].title, "A test title", "the title again")
    asked.refilled[2].opts.onClose()
    NewsShow:OnOptionsRebuilt()
    eq(#asked.refilled, 2, "nothing once it is closed")
end)

test("no announcement, or one switched off: nothing at a load and nothing with the window", function()
    for label, news in pairs({ none = false, off = sample(ID, false) }) do
        fresh(news or nil)
        NewsShow:OnEnable()
        WoW.FireEvent("LOADING_SCREEN_DISABLED")
        NewsShow:OnWindowOpened()
        eq(#asked.shown, 0, label)
    end
end)

-- the announcement that ships and the real Window's own methods again, for the test files
-- after this one
NS.news = shipped
Window.ShowLeftNote, Window.RefreshLeftNote = real.ShowLeftNote, real.RefreshLeftNote
