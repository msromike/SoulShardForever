-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_sounds: the pause sound. Its notches: the curve pinned, the conversion of the two
-- values saved before the slider, and silence at notch 0. And Busy: an own sound from its
-- start until the game says it ended.
-- Touches nothing else.

local Sounds = SSF:GetModule("Sounds")

-- WHY THIS IS PINNED: the profile saves the slider's notch (profile.pauseSoundLevel), and
-- this curve is what each notch sounds like. Changing a number below changes how loud the
-- pause sound is for every player on that notch, so a retune has to be deliberate.
test("the curve from a notch to its volume is pinned", function()
    eq(Sounds:LevelStep(), 0.25, "five notches on a scale of 0 to 1")
    local curve = { [0] = 0, [0.25] = 0.12, [0.5] = 0.25, [0.75] = 0.5, [1] = 1 }
    for level, volume in pairs(curve) do
        eq(Sounds:LevelVolume(level), volume, "notch " .. level)
    end
    eq(Sounds:LevelVolume(0.6), 0.25, "a number between two notches plays as the nearest")
    eq(Sounds:LevelVolume(7), 1, "past the top is the top")
    eq(Sounds:LevelVolume(-1), 0, "below the bottom is off")
    eq(Sounds:LevelVolume(nil), 0, "nothing saved is off")
end)

-- The two values saved before the slider, and the notch each pair becomes. On keeps the
-- volume the player hears; off is notch 0 whatever volume was picked.
test("the old on/off and volume become the notch that sounds the same", function()
    eq(Sounds:LevelFromOld(true, 1), 1, "on, Full")
    eq(Sounds:LevelFromOld(true, 0.5), 0.75, "on, Loud")
    eq(Sounds:LevelFromOld(true, 0.25), 0.5, "on, Medium")
    eq(Sounds:LevelFromOld(true, 0.12), 0.25, "on, Quiet")
    eq(Sounds:LevelFromOld(true, nil), 1, "on, volume never changed: it was the default, Full")
    eq(Sounds:LevelFromOld(true, 0.06), 1, "on, a volume that was no level: Full, the old rule")
    eq(Sounds:LevelFromOld(true, 0), 1, "on, a zero volume was never a level either")
    eq(Sounds:LevelFromOld(false, 0.5), 0, "off, a volume picked: off")
    eq(Sounds:LevelFromOld(nil, 0.25), 0, "never switched on (the old default), a volume picked: off")
    for name, old in pairs({ Full = 1, Loud = 0.5, Medium = 0.25, Quiet = 0.12 }) do -- the four old volumes
        eq(Sounds:LevelVolume(Sounds:LevelFromOld(true, old)), old, "the volume heard is unchanged at " .. name)
    end
end)

test("the pause sound plays at its notch and not at all at notch 0", function()
    local profile = SSF.db.profile
    local kept = profile.pauseSoundLevel
    local played = {}
    local real = C_Sound.PlaySound
    C_Sound.PlaySound = function(_, _, _, _, _, volume) played[#played + 1] = volume end
    local okay, err = pcall(function()
        profile.pauseSoundLevel = 0
        Sounds:PlayPause()
        eq(#played, 0, "notch 0: nothing played")
        profile.pauseSoundLevel = 0.5
        Sounds:PlayPause()
        eq(#played, 1, "notch 0.5: played once")
        eq(played[1], 0.25, "at that notch's volume")
    end)
    C_Sound.PlaySound = real
    profile.pauseSoundLevel = kept
    assert(okay, err)
end)

-- The game refuses to start a sound kit again while it plays (it answers nothing), so a
-- press then is silent. Busy is what the window greys the slider's "-" and "+" on.
test("an own sound is busy from its start until the game says it ended", function()
    local said = {}
    local listener = {}
    LibStub("AceEvent-3.0"):Embed(listener)
    listener:RegisterMessage("SSF_SOUND_BUSY", function(_, busy) said[#said + 1] = busy end)
    local real = C_Sound.PlaySound
    local answer = function() return true, 7 end
    C_Sound.PlaySound = function(...) return answer(...) end
    local okay, err = pcall(function()
        eq(Sounds:Busy(), false, "nothing playing to begin with")
        Sounds:Play(Sounds:DefaultName(), 1)
        eq(Sounds:Busy(), true, "started: busy")
        eq(#said, 1, "and said so once")
        eq(said[1], true, "as busy")
        answer = function() end -- the game refuses a play while the kit is still playing
        Sounds:Play(Sounds:DefaultName(), 1)
        eq(#said, 1, "a refused play says nothing")
        WoW.FireEvent("SOUNDKIT_FINISHED", 99)
        eq(Sounds:Busy(), true, "another sound ending changes nothing")
        WoW.FireEvent("SOUNDKIT_FINISHED", 7)
        eq(Sounds:Busy(), false, "its own sound ended: free")
        eq(said[2], false, "and said so")
        Sounds:Play(Sounds:DefaultName(), 1)
        eq(Sounds:Busy(), false, "a play the game refuses outright never makes it busy")
    end)
    C_Sound.PlaySound = real
    listener:UnregisterAllMessages()
    WoW.FireEvent("SOUNDKIT_FINISHED", 7)
    assert(okay, err)
end)
