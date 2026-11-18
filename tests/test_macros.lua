-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_macros: Macros, the two recommended macros. What Create writes and where (the
-- character's slots when both fit, else the account's, never split, else a red line and
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
    eq(Macros:Body("BoA"), "#showtooltip\n/ssf delete\n/cast Spell 980", "Bane of Agony")
    eq(Macros:BodyFor("Any Spell"), "#showtooltip\n/ssf delete\n/cast Any Spell", "the one template, for any spell's name")
    eq(Macros:Body("LT"), Macros:BodyFor(Macros:SpellName("LT")), "and the recommended macros are made from it")
    eq(table.concat(Macros:Names(), " "), "SSF_LT SSF_BoA", "found by these names")
end)

test("any spell's name comes from the game; a macro's own falls back to English", function()
    eq(Macros:SpellNameOf(1120), "Spell 1120", "Drain Soul, by id")
    local real = C_Spell.GetSpellName
    C_Spell.GetSpellName = function() return nil end
    local none, fallback = Macros:SpellNameOf(1120), Macros:SpellName("BoA")
    C_Spell.GetSpellName = real
    eq(none, nil, "no name from the game: nil")
    eq(fallback, "Bane of Agony", "the macro's own English name")
end)

test("both missing: both made in the character's slots, then /reload", function()
    WoW.SetMacros({}, {})
    eq(Macros:AnyMissing(), true, "missing to begin with")
    eq(Macros:Create(), "/reload", "hands back /reload for the note's button")
    eq(names(WoW.macroList.character), "SSF_LT SSF_BoA", "both in the character's slots")
    eq(#WoW.macroList.account, 0, "none in the account's")
    eq(WoW.macroList.character[1].body, Macros:Body("LT"), "with the text Body gives")
    eq(Macros:AnyMissing(), false, "nothing missing after")
    eq(SSF.db.profile.macroWindowAfterReload, true, "the macro window is owed after the reload")
end)

test("one missing: only that one is made", function()
    WoW.SetMacros({ "SSF_LT" }, {})
    eq(Macros:Create(), "/reload", "made one")
    eq(names(WoW.macroList.character), "SSF_BoA", "only Bane of Agony's")
    eq(names(WoW.macroList.account), "SSF_LT", "the one there stays where it is")
end)

test("the character's slots too full for both: both go to the account's, never split", function()
    WoW.SetMacros({}, filler(29)) -- one free character slot, two to make
    eq(Macros:Create(), "/reload", "made")
    eq(names(WoW.macroList.account), "SSF_LT SSF_BoA", "both in the account's slots")
    eq(#WoW.macroList.character, 29, "none in the one free character slot")
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
    WoW.SetMacros({}, { "Other", "SSF_LT", "SSF_BoA" })
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
