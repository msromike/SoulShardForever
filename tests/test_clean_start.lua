-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_clean_start: the runner's promise that every test starts from the same place. The
-- first test leaves behind everything a test can leave in the fake game; the second must
-- find none of it. They run in this order (one file, top to bottom).
-- Touches nothing else.

test("a test that leaves the fake game dirty", function()
    WoW.combat, WoW.channel = true, "Drain Soul"
    DEFAULT_CHAT_FRAME:AddMessage("a line")
    MuteSoundFile(12345)
    WoW.SetMacros({}, { "Other" })
    WoW.combat = false -- the macro window opens only out of combat
    ShowMacroFrame()
    WoW.combat = true
    SSF.db.profile.maxShards = 3
    ok(true, "dirtied")
end)

test("the next test starts clean", function()
    eq(WoW.combat, false, "no combat")
    eq(WoW.channel, nil, "no channel")
    eq(#WoW.chat, 0, "an empty chat")
    eq(next(WoW.muted), nil, "no sound muted")
    eq(GetMacroIndexByName("SSF_LT"), 1, "SSF's macros are back")
    eq(GetMacroIndexByName("Other"), 0, "and no other")
    eq(WoW.macroWindow, nil, "no macro window")
    eq(#WoW.blocked, 0, "nothing refused")
    ok(SSF.db.profile.maxShards ~= 3, "the profile as it was")
end)
