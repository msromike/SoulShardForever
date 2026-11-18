-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_macros: Macros, the three recommended macros. What Create writes and where (the
-- character's slots when all fit, else the account's, never split, else a red line and
-- nothing); that it hands back /reload and opens the macro window on the first of them
-- once after that reload; that with nothing to do it only shows them; the wand option (a
-- macro SSF made is rewritten in place to what the option says, with no reload, and one
-- the player edited never is); that in combat it
-- asks the game for nothing (the game refuses CreateMacro under lockdown); and that a
-- burst of UPDATE_MACROS is one SSF_MACROS_CHANGED.
-- Touches nothing else.

local Macros = SSF:GetModule("Macros")

local function names(list)
    local out = {}
    for _, m in ipairs(list) do out[#out + 1] = m.name end
    return table.concat(out, " ")
end

local function filler(n)
    local out = {}
    for i = 1, n do out[i] = "Other" .. i end
    return out
end

test("the macro text is /ssf delete before the spell, in the client's language", function()
    eq(Macros:Body("LT"), "#showtooltip\n/ssf delete\n/cast Spell 1454", "Life Tap")
    eq(Macros:Body("DS"), "#showtooltip\n/ssf delete\n/cast Spell 1120", "Drain Soul")
    eq(Macros:Body("BoA"), "#showtooltip\n/ssf delete\n/cast Spell 980", "Bane of Agony")
    eq(Macros:BodyFor("Any Spell"), "#showtooltip\n/ssf delete\n/cast Any Spell", "the one template, for any spell's name")
    eq(Macros:Body("LT"), Macros:BodyFor(Macros:SpellName("LT")), "and the recommended macros are made from it")
    eq(Macros:BodyFor("Any Spell", { "/stopattack", "/stopcasting" }),
        "#showtooltip\n/ssf delete\n/stopattack\n/stopcasting\n/cast Any Spell", "a variant's own lines sit before the cast")
    eq(table.concat(Macros:Names(), " "), "SSF_LT SSF_DS SSF_BoA", "found by these names")
    eq(table.concat(Macros:Keys(), " "), "LT DS BoA", "their keys, in the order shown and made")
    local keys = Macros:Keys()
    keys[1] = "changed"
    eq(Macros:Keys()[1], "LT", "a caller's copy: the order cannot be changed from outside")
end)

test("the delete help shows every recommended macro, in order, and nothing after them", function()
    local blocks = SSF:GetModule("DeleteHelp"):Blocks("first")
    eq(#blocks, 5, "the first paragraph, the lead-in, three macros")
    eq(blocks[1].text, "first", "the caller's paragraph")
    eq(blocks[3].text, Macros:Body("LT"), "Life Tap's")
    eq(blocks[4].text, Macros:Body("DS"), "Drain Soul's")
    eq(blocks[5].text, Macros:Body("BoA"), "Bane of Agony's")
    ok(blocks[3].macro and blocks[4].macro and blocks[5].macro, "each a macro block")
end)

test("any spell's name comes from the game; a macro's own falls back to English", function()
    local Spells = SSF:GetModule("Spells")
    eq(Spells:NameOf(1120), "Spell 1120", "Drain Soul, by id")
    local real = C_Spell.GetSpellName
    C_Spell.GetSpellName = function() return nil end
    local none, fallback = Spells:NameOf(1120), Macros:SpellName("BoA")
    C_Spell.GetSpellName = real
    eq(none, nil, "no name from the game: nil")
    eq(fallback, "Bane of Agony", "the macro's own English name")
end)

test("all missing: all made in the character's slots, then /reload", function()
    WoW.SetMacros({}, {})
    eq(Macros:Pending(), "create", "missing to begin with")
    eq(Macros:Create(), "/reload", "hands back /reload for the note's button")
    eq(names(WoW.macroList.character), "SSF_LT SSF_DS SSF_BoA", "all in the character's slots")
    eq(#WoW.macroList.account, 0, "none in the account's")
    eq(WoW.macroList.character[1].body, Macros:Body("LT"), "with the text Body gives")
    eq(Macros:Pending(), nil, "nothing left to do after")
    eq(SSF.db.profile.macroWindowAfterReload, true, "the macro window is owed after the reload")
end)

test("one missing: only that one is made", function()
    WoW.SetMacros({ "SSF_LT", "SSF_BoA" }, {})
    eq(Macros:Create(), "/reload", "made one")
    eq(names(WoW.macroList.character), "SSF_DS", "only Drain Soul's: the two an older SSF made are there")
    eq(names(WoW.macroList.account), "SSF_LT SSF_BoA", "the ones there stay where they are")
end)

test("the character's slots too full for all: all go to the account's, never split", function()
    WoW.SetMacros({}, filler(28)) -- two free character slots, three to make
    eq(Macros:Create(), "/reload", "made")
    eq(names(WoW.macroList.account), "SSF_LT SSF_DS SSF_BoA", "all in the account's slots")
    eq(#WoW.macroList.character, 28, "none in the two free character slots")
end)

test("no room anywhere: a red line and nothing made", function()
    WoW.SetMacros(filler(119), filler(29))
    eq(Macros:Create(), nil, "nothing to reload")
    eq(#WoW.redErrors, 1, "one red line")
    eq(#WoW.macroList.account + #WoW.macroList.character, 119 + 29, "nothing made")
    eq(SSF.db.profile.macroWindowAfterReload, false, "no macro window owed")
end)

test("in combat Create asks the game for nothing", function()
    WoW.SetMacros({}, {})
    WoW.combat = true
    eq(Macros:Create(), nil, "nothing to reload")
    eq(#WoW.blocked, 0, "no protected call made (the game would refuse it)")
    eq(#WoW.macroList.account + #WoW.macroList.character, 0, "nothing made")
    eq(WoW.macroWindow, nil, "and the macro window is not opened")
end)

test("nothing missing: Create only shows them, on the right tab", function()
    eq(Macros:Create(), nil, "nothing to reload")
    eq(WoW.macroWindow and WoW.macroWindow.tab, 1, "the account tab: SSF_LT is an account macro")
    eq(WoW.macroWindow.selected, 1, "SSF_LT selected")
    WoW.SetMacros({}, { "Other", "SSF_LT", "SSF_DS", "SSF_BoA" })
    Macros:Create()
    eq(WoW.macroWindow.tab, 2, "the character tab for a character macro")
    eq(WoW.macroWindow.selected, 2, "selected by its place within the tab")
end)

-- all three made by SSF, as the option says now
local function allMade()
    WoW.SetMacros({}, {})
    Macros:Create()
end

-- the texts of SSF's three macros, by key
local function bodies()
    local out = {}
    for _, key in ipairs(Macros:Keys()) do
        local _, _, body = GetMacroInfo(GetMacroIndexByName("SSF_" .. key))
        out[key] = body
    end
    return out
end

test("the wand option: off to begin with; on, every macro carries /stopattack before the cast", function()
    eq(Macros:StopWand(), false, "off")
    eq(Macros:Body("DS", true), "#showtooltip\n/ssf delete\n/stopattack\n/cast Spell 1120", "with the line, asked for by hand")
    Macros:SetStopWand(true)
    eq(SSF.db.profile.macroStopWand, true, "saved")
    eq(Macros:Body("LT"), "#showtooltip\n/ssf delete\n/stopattack\n/cast Spell 1454", "Body follows the option")
    eq(Macros:Body("LT", false), "#showtooltip\n/ssf delete\n/cast Spell 1454", "and still hands the other text when asked")
    Macros:SetStopWand(false)
end)

test("the option turned on with the macros made: a click rewrites them in place, no reload", function()
    allMade()
    eq(Macros:Pending(), nil, "made and matching: nothing to do")
    Macros:SetStopWand(true)
    eq(Macros:Pending(), "update", "the option changed: the click would update")
    eq(Macros:Reloads(), false, "and says beforehand that it reloads nothing")
    eq(Macros:Create(), nil, "no reload")
    eq(bodies().LT, Macros:Body("LT", true), "Life Tap's has the line")
    eq(bodies().DS, Macros:Body("DS", true), "Drain Soul's")
    eq(bodies().BoA, Macros:Body("BoA", true), "Bane of Agony's")
    eq(names(WoW.macroList.character), "SSF_LT SSF_DS SSF_BoA", "the same three macros, none made")
    eq(SSF.db.profile.macroWindowAfterReload, true, "the macro window owed is still the first Create's")
    eq(Macros:Pending(), nil, "nothing left to do")
    Macros:SetStopWand(false)
    eq(Macros:Pending(), "update", "off again: the click would take the line out")
    Macros:Create()
    eq(bodies().BoA, Macros:Body("BoA", false), "the line is gone")
    SSF.db.profile.macroWindowAfterReload = false
end)

test("a macro the player edited is never rewritten; the game's own line ends do not count as an edit", function()
    allMade()
    local edited = "#showtooltip\n/ssf delete\n/stopcasting\n/cast Spell 980"
    EditMacro(GetMacroIndexByName("SSF_BoA"), nil, nil, edited)
    EditMacro(GetMacroIndexByName("SSF_LT"), nil, nil, Macros:Body("LT", false) .. "\r\n ")
    Macros:SetStopWand(true)
    eq(Macros:Pending(), "update", "the other two still want updating")
    Macros:Create()
    eq(bodies().BoA, edited, "the edited one is left as it is")
    eq(bodies().LT, Macros:Body("LT", true), "one with a line end left on it is SSF's own: rewritten")
    eq(bodies().DS, Macros:Body("DS", true), "and so is the untouched one")
    eq(Macros:Pending(), nil, "only the edited one differs now: nothing to do")
    Macros:SetStopWand(false)
end)

test("one missing with the option on: made with the line, the others rewritten, then /reload", function()
    WoW.SetMacros({}, {})
    Macros:Create()
    table.remove(WoW.macroList.character, 2) -- SSF_DS gone: the two an older SSF made
    Macros:SetStopWand(true)
    eq(Macros:Pending(), "create", "a missing macro comes first")
    eq(Macros:Reloads(), true, "and the click says beforehand that it reloads")
    eq(Macros:Create(), "/reload", "a macro was made: reload")
    eq(bodies().DS, Macros:Body("DS", true), "the new one with the line")
    eq(bodies().LT, Macros:Body("LT", true), "and the two that were there too")
    eq(bodies().BoA, Macros:Body("BoA", true), "both")
    Macros:SetStopWand(false)
    SSF.db.profile.macroWindowAfterReload = false
end)

test("in combat a click rewrites nothing", function()
    allMade()
    Macros:SetStopWand(true)
    WoW.combat = true
    eq(Macros:Create(), nil, "nothing")
    eq(#WoW.blocked, 0, "no protected call made")
    eq(bodies().LT, Macros:Body("LT", false), "the macro is as it was")
    WoW.combat = false
    Macros:SetStopWand(false)
    SSF.db.profile.macroWindowAfterReload = false
end)

test("after Create's reload the macro window opens once, on the first of them", function()
    SSF.db.profile.macroWindowAfterReload = true
    Macros:Disable()
    Macros:Enable() -- the login after the reload
    WoW.FireEvent("LOADING_SCREEN_DISABLED")
    eq(WoW.macroWindow and WoW.macroWindow.selected, 1, "opened on SSF_LT")
    eq(SSF.db.profile.macroWindowAfterReload, false, "no longer owed")
    WoW.macroWindow = nil
    WoW.FireEvent("LOADING_SCREEN_DISABLED")
    eq(WoW.macroWindow, nil, "a later loading screen opens nothing")
end)

test("a burst of UPDATE_MACROS is one SSF_MACROS_CHANGED", function()
    local probe, heard = {}, 0
    LibStub("AceEvent-3.0"):Embed(probe)
    probe:RegisterMessage("SSF_MACROS_CHANGED", function() heard = heard + 1 end)
    for _ = 1, 5 do WoW.FireEvent("UPDATE_MACROS") end
    WoW.RunTimers()
    probe:UnregisterAllMessages()
    eq(heard, 1, "one message for the burst")
end)
