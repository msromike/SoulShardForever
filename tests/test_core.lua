-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_core: the profile-key migration. The runner seeds a saved file with one profile under
-- the old AceDB 36 key ("Tester - PvE") and the stub makes AceDB 39 key the character
-- "Tester Hrodbar"; Core must copy the old profile into the new key at OnInitialize.
-- Touches nothing else.

local initial = WoW.initialProfile

test("AceDB 39 keys the character the Forever way", function()
    eq(initial.char, "Tester Hrodbar", "name and surname")
    eq(initial.profileKey, "Tester Hrodbar", "the character's own profile")
end)

test("the old profile came across: settings and the welcome mark", function()
    eq(initial.maxShards, 12, "cap")
    eq(initial.lowMark, 10, "low mark")
    eq(initial.welcomed, 10801, "welcome seen, no pop")
    eq(initial.pauseLog, true, "a boolean came too")
end)

test("the old profile is left in place, not deleted", function()
    ok(SoulShardForeverDB.profiles["Tester - PvE"] ~= nil, "still there")
    eq(SoulShardForeverDB.profiles["Tester - PvE"].maxShards, 12, "untouched")
end)
