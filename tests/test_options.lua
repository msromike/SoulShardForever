-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_options: the rules the options table must keep that no header can make it keep. The
-- table is the real one, asked of AceConfigRegistry the way the window and /ssf ask, so
-- AceConfig's own validation runs on it. Every group is inline (one that is not turns the
-- window into a tree and Window's fitting measures the wrong thing); every control names
-- a widget that exists; every control in the window has a help line; a chat setting's
-- usage line names the word it was placed under; and the Delete Shard button has a text
-- for every answer Trimmer:WhyNot can give (the answers are read from Trimmer's own file,
-- so a new one with no text fails here, not as a nil call on every redraw in the game).
-- Reads:   Options (APP, Rebuild), Settings:ValueWords, Trimmer:WhyNot (replaced for one
--          test and put back); Modules/Trimmer.lua (WoW.root); WoW.chat.
-- Touches nothing else.

local Registry = LibStub("AceConfigRegistry-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local Options = SSF:GetModule("Options")
local Trimmer = SSF:GetModule("Trimmer")
local Settings = SSF:GetModule("Settings")

local function Table() return Registry:GetOptionsTable(Options.APP, "dialog", "AceConfigDialog-3.0") end

-- fn(key, entry) for every entry under a group, at any depth
local function Walk(group, fn)
    for key, entry in pairs(group.args) do
        fn(key, entry)
        if entry.args then Walk(entry, fn) end
    end
end

test("the real table builds and passes AceConfig's validation", function()
    local root = Table()
    eq(type(root), "table", "the window's view of it")
    eq(root.type, "group", "a group at the root")
    eq(type(Registry:GetOptionsTable(Options.APP, "cmd", "AceConfigCmd-3.0")), "table", "the chat view of it")
    Options:Rebuild()
    eq(type(Table()), "table", "and again after a rebuild")
end)

test("every group is inline", function()
    local groups = 0
    Walk(Table(), function(key, entry)
        if entry.type == "group" then
            groups = groups + 1
            eq(entry.inline, true, key .. " is inline")
        end
    end)
    ok(groups > 0, "there are groups to check")
end)

test("every dialogControl names a widget that is registered", function()
    local controls = 0
    Walk(Table(), function(key, entry)
        if entry.dialogControl then
            controls = controls + 1
            ok(AceGUI:GetWidgetVersion(entry.dialogControl) ~= nil, key .. ": " .. entry.dialogControl)
        end
    end)
    ok(controls > 0, "there are controls to check")
end)

test("every control in the window has a help line", function()
    Walk(Table(), function(key, entry)
        if entry.type ~= "group" and entry.type ~= "description" and not entry.dialogHidden then
            ok(entry.desc ~= nil, key .. " has a help line")
        end
    end)
end)

test("a chat setting's usage line names the word it sits under", function()
    local slash = SlashCmdList.ACECONSOLE_SSF
    local settings = 0
    for word, entry in pairs(Table().args) do
        if entry.type == "input" and not entry.cmdHidden then
            settings = settings + 1
            slash(word .. " zzz")
            local line = WoW.chat[#WoW.chat]
            ok(line:find("Use: /ssf " .. word .. " ", 1, true) ~= nil, word .. ": the usage line says /ssf " .. word)
            eq(Settings:ValueWords(word) ~= nil, line:find("on|off", 1, true) ~= nil,
                word .. ": Tab offers on and off exactly when the usage does")
        end
    end
    ok(settings > 0, "there are chat settings to check")
end)

-- the answers WhyNot can give, from its own source: every quoted word it returns
local function WhyNotAnswers()
    local file = assert(io.open(WoW.root .. "/Modules/Trimmer.lua"))
    local source = file:read("*a")
    file:close()
    local body = assert(source:match("function Trimmer:WhyNot%(.-\nend"), "Trimmer:WhyNot not found")
    local answers = {}
    for line in body:gmatch("[^\n]+") do
        local returned = line:match("return%s+(.*)$")
        if returned then
            for answer in returned:gmatch('"(%w+)"') do answers[#answers + 1] = answer end
        end
    end
    return answers
end

test("an answer WhyNot gives with no text of its own shows the cap, not an error", function()
    local button = Table().args.deletebutton
    local real = Trimmer.WhyNot
    function Trimmer:WhyNot() return "brandnew" end
    local okay, _, reason = pcall(button.arg)
    Trimmer.WhyNot = real
    eq(okay, true, "no error")
    ok(type(reason) == "string" and reason:find("cap is", 1, true) ~= nil, "the button says the cap")
end)

-- the answers Options has a text of its own for: the keys of its BLOCKER_TEXT, from its
-- source (the button falls back to "cap is N" for any other, so only the source can tell)
local function BlockerKeys()
    local file = assert(io.open(WoW.root .. "/Modules/Options.lua"))
    local source = file:read("*a")
    file:close()
    local body = assert(source:match("local BLOCKER_TEXT = (%b{})"), "BLOCKER_TEXT not found")
    local keys = {}
    for key in body:gmatch("(%w+)%s*=") do keys[key] = true end
    return keys
end

test("the Delete Shard button has a text for every answer WhyNot can give", function()
    local answers = WhyNotAnswers()
    ok(#answers >= 2, "answers were found in Trimmer's file")
    local keys = BlockerKeys()
    for _, answer in ipairs(answers) do
        ok(keys[answer], answer .. ": has its own line in Options' BLOCKER_TEXT")
    end
    local button = Table().args.deletebutton
    local real = Trimmer.WhyNot
    local okay, err = pcall(function()
        for _, answer in ipairs(answers) do
            function Trimmer:WhyNot() return answer end
            local _, reason, all = button.arg()
            ok(type(reason) == "string" and reason ~= "", answer .. ": a reason on the button's face")
            ok(type(button.desc()) == "string", answer .. ": a tooltip")
            eq(button.disabled(), true, answer .. ": greyed")
            local listed = false
            for _, text in ipairs(all) do listed = listed or text == reason end
            ok(listed, answer .. ": its text is among the ones the button sizes itself to")
        end
        function Trimmer:WhyNot() return nil end
        local _, reason = button.arg()
        eq(reason, nil, "a press that would delete: no reason")
        eq(button.disabled(), false, "and the button is live")
    end)
    Trimmer.WhyNot = real
    assert(okay, err)
end)
