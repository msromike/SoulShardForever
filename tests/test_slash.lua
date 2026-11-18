-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_slash: /ssf as a player types it, through the slash command AceConsole registered
-- and the real AceConfigCmd: the bare command, help, an unknown word, the echo, each
-- setting's command, the words that work without being listed (announce, debug), the
-- debug command's own words. And Tab in the chat box, through the real AceTab on the
-- game's chat edit box: what it completes, what it offers, and that it never offers a
-- hidden word.
-- The chat edit box here is the stub's frame with the four methods AceTab drives (GetText,
-- GetCursorPosition, HighlightText, Insert) written out, so a Tab really edits a line.
-- Reads:   Window, Cap, Debug, Status:PauseText, Colors:Echo; WoW.chat, WoW.combat.
-- Saves:   profile.paused, announce, maxShards, autoMax, for the test at hand; the debug
--          record's switch (turned off again).
-- Touches nothing else.

local Window = SSF:GetModule("Window")
local Debug = SSF:GetModule("Debug")
local Colors = SSF:GetModule("Colors")
local profile = SSF.db.profile

local function plain(text) return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- type "/ssf <input>": the lines it printed, colors removed, and the same lines raw
local function slash(input)
    local from = #WoW.chat
    SlashCmdList.ACECONSOLE_SSF(input)
    local lines, raw = {}, {}
    for i = from + 1, #WoW.chat do
        lines[#lines + 1] = plain(WoW.chat[i])
        raw[#raw + 1] = WoW.chat[i]
    end
    return lines, raw
end

local function any(lines, text)
    for _, line in ipairs(lines) do
        if line:find(text, 1, true) then return true end
    end
    return false
end

-- the command list AceConfigCmd prints: is this word one of its rows?
local function listed(lines, word)
    for _, line in ipairs(lines) do
        if line:match("^%s*" .. word .. " %- ") then return true end
    end
    return false
end

local function shut()
    if Window.window then Window.window:Hide() end
end
local function open() return Window.window ~= nil and Window.window.frame:IsShown() end

local LISTED = { "delete", "log", "options", "pause", "setmax", "settings" }
local NEVER_LISTED = { "announce", "debug", "deletebutton", "pausegroup", "cap", "gap0" }

test("bare /ssf opens the window and prints the echo, the status and the pointer to help", function()
    shut()
    local lines = slash("")
    ok(open(), "the window is open")
    ok(lines[1]:find("> /ssf", 1, true), "the echo first")
    ok(any(lines, "Type /ssf help for commands."), "the pointer to help")
    ok(#lines >= 3, "and the status between them")
end)

test("bare /ssf in a fight opens nothing", function()
    shut()
    WoW.combat = true
    slash("")
    ok(not open(), "the window stays shut")
end)

test("/ssf help lists every command and no hidden word", function()
    local lines = slash("help")
    for _, word in ipairs(LISTED) do ok(listed(lines, word), word .. " is listed") end
    for _, word in ipairs(NEVER_LISTED) do ok(not listed(lines, word), word .. " is not listed") end
    eq(#slash("?"), #lines, "/ssf ? prints the same list")
end)

test("an unknown word says so, then prints the list", function()
    local lines = slash("bogus on")
    ok(any(lines, 'Unknown command "bogus".'), "the error line")
    ok(listed(lines, "pause"), "then the list")
end)

test("the typed command is echoed in grey, except delete", function()
    local _, raw = slash("log")
    ok(raw[1]:find(Colors:Echo("> /ssf log"), 1, true), "echoed in the echo grey")
    local lines = slash("delete")
    ok(not any(lines, "> /ssf"), "delete is not echoed (macros run it before every cast)")
end)

test("/ssf pause on and off, with the pause line as the echo", function()
    profile.paused = false
    local lines = slash("pause on")
    eq(profile.paused, true, "on")
    ok(any(lines, plain(SSF:GetModule("Status"):PauseText())), "the pause line a bare /ssf prints")
    slash("pause off")
    eq(profile.paused, false, "off")
    lines = slash("pause sideways")
    ok(any(lines, "Use: /ssf pause on|off"), "a bad value: the usage line")
    eq(profile.paused, false, "and nothing changed")
end)

test("/ssf setmax sets the cap by hand; naked reports it; out of range is the usage line", function()
    profile.autoMax, profile.maxShards = true, 20
    slash("setmax 5")
    eq(profile.autoMax, false, "Match soul bag size is turned off")
    eq(SSF:GetModule("Cap"):Get(), 5, "the cap is 5")
    local lines = slash("setmax")
    ok(any(lines, "Shards to keep: 5"), "naked reports the cap")
    lines = slash("setmax 500")
    ok(any(lines, "Use: /ssf setmax 1-100"), "500: the usage line")
    eq(SSF:GetModule("Cap"):Get(), 5, "and the cap is still 5")
end)

test("/ssf and a number sets the cap as setmax does; out of range answers in the short form", function()
    profile.autoMax, profile.maxShards = true, 20
    local lines = slash("25")
    eq(SSF:GetModule("Cap"):Get(), 25, "/ssf 25 sets the cap to 25")
    eq(profile.autoMax, false, "and turns Match soul bag size off, as setmax does")
    ok(any(lines, "Shards to keep: 25"), "and echoes it as setmax does")
    lines = slash("500")
    ok(any(lines, "Use: /ssf 1-100"), "/ssf 500: the usage line in the short form")
    ok(not any(lines, "setmax"), "which does not name setmax")
    eq(SSF:GetModule("Cap"):Get(), 25, "and the cap is still 25")
    lines = slash("setmax 500")
    ok(any(lines, "Use: /ssf setmax 1-100"), "/ssf setmax 500 keeps its own long usage line")
    lines = slash("3.5")
    ok(any(lines, 'Unknown command "3.5".'), "only a whole number counts")
    lines = slash("25 more")
    ok(any(lines, 'Unknown command "25".'), "and only on its own")
end)

test("/ssf log, and its old word announce, set the same thing", function()
    profile.announce = false
    slash("log on")
    eq(profile.announce, true, "log on")
    slash("announce off")
    eq(profile.announce, false, "announce off: old macros still work")
    slash("announce on")
    eq(profile.announce, true, "announce on")
end)

test("/ssf options and /ssf settings open the window", function()
    shut()
    slash("options")
    ok(open(), "options")
    shut()
    slash("settings")
    ok(open(), "settings")
end)

test("/ssf debug: naked reports, on and off set, anything else is the usage line", function()
    Debug:Set(false)
    local lines = slash("debug")
    ok(any(lines, "Debug: OFF"), "naked: off")
    lines = slash("debug on")
    eq(Debug:IsOn(), true, "on")
    ok(any(lines, "Debug: ON"), "and says so")
    lines = slash("debug OFF")
    eq(Debug:IsOn(), false, "off, capitals forgiven")
    ok(any(lines, "Debug: OFF"), "and says so")
    for _, bad in ipairs({ "debug sideways", "debug on now", "debug mark", "debug report now", "debug clear all", "debug login now" }) do
        -- the line as SSF hands it to the chat frame, each bar doubled: the game draws a
        -- doubled bar as one, and eats the "|r" of a single-barred "|report"
        local _, raw = slash(bad)
        ok(any(raw, "Use: /ssf debug on||off||mark <name>||report||clear||login"), bad .. ": the usage line")
    end
    eq(Debug:IsOn(), false, "none of them turned it on")
end)

test("/ssf debug login asks for the next login to be recorded, and leaves the record as it is", function()
    Debug:Set(false)
    local lines = slash("debug login")
    ok(any(lines, "Debug will record your next login or reload."), "says so")
    eq(SSF.db.profile.debugLogin, true, "asked for")
    eq(Debug:IsOn(), false, "the record is not turned on now")
    SSF.db.profile.debugLogin = nil
end)

test("/ssf debug mark turns the record on when it is off, and says so only then", function()
    Debug:Set(false)
    local lines = slash("debug mark first one")
    eq(Debug:IsOn(), true, "the mark turned the record on")
    ok(any(lines, "Debug: ON"), "and said so")
    lines = slash("debug mark second")
    eq(#lines, 1, "already on: the echo and nothing else")
    lines = slash("debug clear")
    ok(any(lines, "Debug record cleared."), "clear says so")
    lines = slash("debug report")
    ok(not any(lines, "Use:"), "report is a word it knows")
    Debug:Set(false)
end)

-- ---------------------------------------------------------------- Tab in the chat box

local box = ChatFrame1EditBox
local text, cursor, from, to = "", 0, nil, nil
function box:GetText() return text end
function box:GetCursorPosition() return cursor end
function box:HighlightText(a, b) from, to = a, b end
function box:Insert(s)
    if from then
        text = text:sub(1, from) .. s .. text:sub(to + 1)
        cursor, from, to = from + #s, nil, nil
    else
        text = text:sub(1, cursor) .. s .. text:sub(cursor + 1)
        cursor = cursor + #s
    end
end

-- press Tab: after typing `typed`, or again on the line as it stands. Returns the line and
-- what was printed.
local function Tab(typed)
    if typed then text, cursor = typed, #typed end
    local before = #WoW.chat
    box:GetScript("OnTabPressed")(box)
    local lines = {}
    for i = before + 1, #WoW.chat do lines[#lines + 1] = plain(WoW.chat[i]) end
    return text, lines
end

test("Tab completes a command word that has one match", function()
    eq(Tab("/ssf del"), "/ssf delete ", "del -> delete and a space")
    eq(Tab("/ssf setm"), "/ssf setmax ", "setm -> setmax")
    eq(Tab("/ssf h"), "/ssf help ", "h -> help")
end)

test("Tab on a toggle offers its two value words, then cycles them", function()
    local line, lines = Tab("/ssf pause o")
    eq(line, "/ssf pause o", "the line stays at what both share")
    ok(any(lines, "off  on"), "the usage line offers off and on")
    eq(Tab(), "/ssf pause off", "Tab again: the first")
    eq(Tab(), "/ssf pause on", "and again: the second")
    line, lines = Tab("/ssf l")
    eq(line, "/ssf log o", "l -> log, as far as both values share")
    ok(any(lines, "off  on"), "and the two values are offered")
end)

test("Tab on nothing typed offers the command words, sorted, and no hidden word", function()
    local _, lines = Tab("/ssf ")
    ok(any(lines, "delete  help  log  options  pause  setmax  settings"), "the command words on one line")
    ok(not any(lines, "announce") and not any(lines, "debug"), "no hidden word")
end)

test("Tab never completes a hidden word", function()
    eq(Tab("/ssf ann"), "/ssf ann", "announce")
    eq(Tab("/ssf deb"), "/ssf deb", "debug")
end)
