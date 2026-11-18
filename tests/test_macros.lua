-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_macros: Macros, the three recommended macros. What Create writes and where (the
-- character's slots when all fit, else the account's, never split, else a red line and
-- nothing); that it hands back /reload and opens the macro window on the first of them
-- once after that reload; that with nothing missing it only shows them; that in combat it
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
    eq(Macros:AnyMissing(), true, "missing to begin with")
    eq(Macros:Create(), "/reload", "hands back /reload for the note's button")
    eq(names(WoW.macroList.character), "SSF_LT SSF_DS SSF_BoA", "all in the character's slots")
    eq(#WoW.macroList.account, 0, "none in the account's")
    eq(WoW.macroList.character[1].body, Macros:Body("LT"), "with the text Body gives")
    eq(Macros:AnyMissing(), false, "nothing missing after")
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
