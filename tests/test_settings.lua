-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_settings: Settings:Define, one definition into a window control and a chat command,
-- and the chat rule the command keeps: typed naked it reports, typed with a value it
-- applies and echoes, a bad value prints the usage line and changes nothing. The message
-- after a change says whether chat made it (Window redraws only then). ValueWords, which
-- tab completion reads.
-- Reads:   Settings, Colors; WoW.chat.
-- Touches nothing else.

local Settings = SSF:GetModule("Settings")
local Colors = SSF:GetModule("Colors")

-- every SSF_OPTIONS_CHANGED since the last Hear(), as { key, source }
local heard = {}
local ear = LibStub("AceEvent-3.0"):Embed({})
ear:RegisterMessage("SSF_OPTIONS_CHANGED", function(_, key, source) heard[#heard + 1] = { key = key, source = source } end)
local function Hear() heard = {} end

local function lastLine() return WoW.chat[#WoW.chat] or "" end
local function has(text) return lastLine():find(text, 1, true) ~= nil end

-- a toggle and a range, each holding its value in a local
local flag, number
local function Toggle(more)
    local def = { order = 1, kind = "toggle", name = "Probe", desc = "a probe",
        get = function() return flag end, apply = function(v) flag = v end }
    for k, v in pairs(more or {}) do def[k] = v end
    return Settings:Define("probe", def)
end
local function Range()
    return Settings:Define("proberange", { order = 2, kind = "range", name = "Probe range", min = 1, max = 10, step = 1,
        get = function() return number end, apply = function(v) number = v end })
end

test("one definition gives a window control and a chat command", function()
    local gui, cmd = Toggle()
    eq(gui.type, "toggle", "the control is a toggle")
    eq(gui.cmdHidden, true, "the control is hidden from chat")
    eq(gui.dialogControl, "SSFIndentCheckBox", "drawn as SSF's check box")
    eq(gui.desc, "a probe", "it carries the help line")
    eq(cmd.type, "input", "the command takes typed input")
    eq(cmd.dialogHidden, true, "the command is hidden from the window")
    local rangeGui = Range()
    eq(rangeGui.type, "range", "a range")
    eq(rangeGui.dialogControl, "SSFStepperSlider", "drawn as SSF's slider")
    ok(rangeGui.min == 1 and rangeGui.max == 10 and rangeGui.step == 1, "with its bounds")
end)

test("a toggle in chat: naked reports, a value applies and echoes", function()
    local _, cmd = Toggle()
    flag = true
    Hear()
    cmd.set(nil, "")
    ok(has("Probe: " .. Colors:OnOff(true)), "naked: reports ON")
    eq(flag, true, "and changes nothing")
    eq(#heard, 0, "and sends nothing")
    cmd.set(nil, "off")
    eq(flag, false, "off applies")
    ok(has("Probe: " .. Colors:OnOff(false)), "and echoes OFF")
    eq(#heard, 1, "one message")
    eq(heard[1].key, "probe", "with the key")
    eq(heard[1].source, "chat", "marked as from chat")
    cmd.set(nil, "  ON ")
    eq(flag, true, "spaces and capitals are forgiven")
    cmd.set(nil, "false")
    eq(flag, false, "false is accepted")
    cmd.set(nil, "true")
    eq(flag, true, "true is accepted")
end)

test("a toggle in chat: a bad value prints the usage line and changes nothing", function()
    local _, cmd = Toggle()
    flag = true
    Hear()
    cmd.set(nil, "maybe")
    ok(has("Use: /ssf probe on|off"), "the usage line names the key")
    eq(flag, true, "nothing applied")
    eq(#heard, 0, "nothing sent")
end)

test("a range in chat: a number in range applies, anything else is the usage line", function()
    local _, cmd = Range()
    number = 4
    cmd.set(nil, "")
    ok(has("Probe range: " .. Colors:Value(4)), "naked: reports the number")
    cmd.set(nil, "7")
    eq(number, 7, "7 applies")
    ok(has("Probe range: " .. Colors:Value(7)), "and echoes")
    for _, bad in ipairs({ "0", "11", "abc" }) do
        cmd.set(nil, bad)
        ok(has("Use: /ssf proberange 1-10"), bad .. ": the usage line with the bounds")
        eq(number, 7, bad .. ": nothing applied")
    end
end)

test("the echo: extra is added after the value, echo replaces the whole line", function()
    local _, cmd = Toggle({ extra = function() return "(and more)" end })
    flag = true
    cmd.set(nil, "")
    ok(has("Probe: " .. Colors:OnOff(true) .. " (and more)"), "extra follows the value")
    _, cmd = Toggle({ echo = function() return "the whole line" end })
    cmd.set(nil, "")
    ok(has("the whole line"), "echo is the line")
    ok(not has("Probe:"), "in place of name: value")
end)

test("a change in the window applies and sends, with no chat line, marked as the window's", function()
    local gui = Toggle()
    flag = false
    Hear()
    local before = #WoW.chat
    gui.set(nil, true)
    eq(flag, true, "applied")
    eq(gui.get(), true, "and read back")
    eq(#WoW.chat, before, "no chat line")
    eq(#heard, 1, "one message")
    eq(heard[1].source, "window", "marked as from the window")
end)

test("ValueWords: a toggle's two words, nothing for a range or an unknown key", function()
    Toggle()
    Range()
    local words = Settings:ValueWords("probe")
    ok(words and words[1] == "off" and words[2] == "on" and #words == 2, "off, on")
    eq(Settings:ValueWords("proberange"), nil, "a range has none")
    eq(Settings:ValueWords("nosuchkey"), nil, "an unknown key has none")
end)
