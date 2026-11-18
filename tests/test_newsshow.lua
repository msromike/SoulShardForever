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

NS.AddLocaleStrings("enUS", { ["A test title"] = true, ["First line."] = true, ["Second line."] = true,
    ["/cast %s"] = true })

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

-- What the player types or copies is in the code color. A macro is handed to the panel
-- as a macro block, plain, and the panel draws it in its box in that color; in any other
-- text only the commands it names are painted. The lines themselves carry no color.
test("a macro paragraph is a macro block for the panel, and a command inside a sentence is painted", function()
    local Colors = SSF:GetModule("Colors")
    local sentence = "In a macro, put /ssf delete on the line before the ability:"
    local news = sample()
    news.text = { { text = sentence }, { text = "Create macros", macro = true }, sentence }
    fresh(news)
    NewsShow:OnWindowOpened()
    local blocks = asked.shown[1].opts.blocks
    eq(blocks[1].text, Colors:Commands(sentence), "the command painted, the sentence around it plain")
    ok(blocks[1].text ~= sentence, "and it did paint one")
    eq(blocks[2].text, "Create macros", "a macro: its text as it is, the box colors it")
    eq(blocks[2].macro, true, "and marked a macro, so the panel boxes it")
    eq(blocks[1].macro, nil, "a sentence is not")
    eq(blocks[3].text, Colors:Commands(sentence), "a plain line's command too")
end)

-- The recommended macro's text has one source, Macros. An announcement names the spell
-- and never types the macro out.
test("a macro paragraph with a spell and no text is Macros' text for that spell", function()
    local Macros = SSF:GetModule("Macros")
    local news = sample()
    news.text = { { spell = "LIFE_TAP", macro = true } }
    fresh(news)
    NewsShow:OnWindowOpened()
    local name = SSF:GetModule("Spells"):NameOf(SSF.SPELLS.LIFE_TAP)
    eq(asked.shown[1].opts.blocks[1].text, Macros:BodyFor(name), "Macros' template")
    news.text = { { spell = "LIFE_TAP", macro = true, lines = { "/stopattack" } } }
    fresh(news)
    NewsShow:OnWindowOpened()
    eq(asked.shown[1].opts.blocks[1].text, Macros:BodyFor(name, { "/stopattack" }), "with the paragraph's own lines before the cast")
    eq(Macros:BodyFor(name), Macros:Body("LT"), "the same text the Life Tap macro is made with")
end)

test("a paragraph's spell is named by the game, in its text's %s", function()
    local news = sample()
    news.text = { { text = "/cast %s", spell = "BANE_OF_AGONY" }, "Second line." }
    fresh(news)
    NewsShow:OnWindowOpened()
    eq(asked.shown[1].opts.blocks[1].text, "/cast Spell 980", "the name the game gives for that spell's id")
end)

test("a white paragraph can carry a blank line under it", function()
    local news = sample()
    news.text = { { text = "First line.", blank = true }, "Second line." }
    fresh(news)
    NewsShow:OnWindowOpened()
    local blocks = asked.shown[1].opts.blocks
    eq(blocks[1].text, "First line.", "a text alone: a white paragraph")
    eq(blocks[1].blank, true, "with its blank line")
end)

-- The announcement that ships, built as players get it (switched on for the test whatever
-- its switch says), so a shape NewsShow cannot draw fails here and not at a player's login.
test("the shipped announcement builds", function()
    if not shipped then return end
    local copy = {}
    for k, v in pairs(shipped) do copy[k] = v end
    copy.on = true
    fresh(copy)
    NewsShow:OnWindowOpened()
    eq(#asked.shown, 1, "it shows")
    eq(#asked.shown[1].opts.blocks, #shipped.text, "every paragraph")
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
