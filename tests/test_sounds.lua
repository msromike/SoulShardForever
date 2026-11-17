-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_sounds: Moving, the one rule for whether a shard move is heard. A sort is never
-- heard; a delete is heard out of combat and not in it; and whatever the moves do, every
-- sound muted for them is back on afterwards, even when a move throws. And the pause
-- sound's notches: the curve pinned, the conversion of the two values saved before the
-- slider, and silence at notch 0.
-- Touches nothing else.

local Sounds = SSF:GetModule("Sounds")

local function mutedNow()
    local n = 0
    for _ in pairs(WoW.muted) do n = n + 1 end
    return n
end

-- runs Moving and returns how many sound files were muted while fn ran
local function mutedDuring(kind)
    local during
    Sounds:Moving(kind, function() during = mutedNow() end)
    return during
end

test("a sort is never heard: muted while it runs, back on after", function()
    eq(mutedNow(), 0, "nothing muted to begin with")
    eq(mutedDuring("sort"), 72, "out of combat: every item move sound muted")
    eq(mutedNow(), 0, "and all back on")
    WoW.combat = true
    eq(mutedDuring("sort"), 72, "in combat: the same")
    eq(mutedNow(), 0, "and all back on")
end)

test("a delete is heard out of combat and not in combat", function()
    eq(mutedDuring("delete"), 0, "out of combat: nothing muted, the tink plays")
    eq(select("#", Sounds:Moving("delete", function() return 1, 2 end)), 0, "heard: returns nothing")
    eq(select("#", Sounds:Moving("sort", function() return 1, 2 end)), 0, "muted: returns nothing")
    WoW.combat = true
    eq(mutedDuring("delete"), 72, "in combat: muted")
    eq(mutedNow(), 0, "and all back on")
end)

test("a move that throws still leaves every sound back on", function()
    local okay, err = pcall(Sounds.Moving, Sounds, "sort", function()
        eq(mutedNow(), 72, "muted when the move starts")
        error("the move broke", 0)
    end)
    eq(okay, false, "the error is not swallowed")
    ok(tostring(err):find("the move broke", 1, true) == 1, "and it is the move's own error, first")
    eq(mutedNow(), 0, "every sound is back on")
end)

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

-- The game does not start a sound kit again while it is still playing, so a quick second
-- press was silent. Play stops the one it started last before starting the next.
test("a second play cuts off the first, so a quick press is heard", function()
    local stopped, next = {}, 100
    local realPlay, realStop = C_Sound.PlaySound, StopSound
    C_Sound.PlaySound = function() next = next + 1 return true, next end
    StopSound = function(handle) stopped[#stopped + 1] = handle end
    local okay, err = pcall(function()
        Sounds:Play(Sounds:DefaultName(), 1)
        local before = #stopped
        Sounds:Play(Sounds:DefaultName(), 1)
        eq(#stopped, before + 1, "the second play stops one sound")
        eq(stopped[#stopped], 101, "the one the first play started")
        Sounds:Play(Sounds:DefaultName(), 1)
        eq(stopped[#stopped], 102, "and the third stops the second")
    end)
    C_Sound.PlaySound, StopSound = realPlay, realStop
    assert(okay, err)
end)

test("on a client without the mute functions the moves just run", function()
    local mute, unmute = MuteSoundFile, UnmuteSoundFile
    MuteSoundFile, UnmuteSoundFile = nil, nil
    local ran = false
    local okay, err = pcall(Sounds.Moving, Sounds, "sort", function() ran = true end)
    MuteSoundFile, UnmuteSoundFile = mute, unmute
    assert(okay, err)
    eq(ran, true, "the moves ran")
end)
