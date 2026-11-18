-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_movesounds: Moving, the one rule for whether a shard move is heard. A sort is never
-- heard; a delete is heard out of combat and not in it; and whatever the moves do, every
-- sound muted for them is back on afterwards, even when a move throws.
-- Touches nothing else.

local MoveSounds = SSF:GetModule("MoveSounds")

local function mutedNow()
    local n = 0
    for _ in pairs(WoW.muted) do n = n + 1 end
    return n
end

-- runs Moving and returns how many sound files were muted while fn ran
local function mutedDuring(kind)
    local during
    MoveSounds:Moving(kind, function() during = mutedNow() end)
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
    eq(select("#", MoveSounds:Moving("delete", function() return 1, 2 end)), 0, "heard: returns nothing")
    eq(select("#", MoveSounds:Moving("sort", function() return 1, 2 end)), 0, "muted: returns nothing")
    WoW.combat = true
    eq(mutedDuring("delete"), 72, "in combat: muted")
    eq(mutedNow(), 0, "and all back on")
end)

test("a move that throws still leaves every sound back on", function()
    local okay, err = pcall(MoveSounds.Moving, MoveSounds, "sort", function()
        eq(mutedNow(), 72, "muted when the move starts")
        error("the move broke", 0)
    end)
    eq(okay, false, "the error is not swallowed")
    ok(tostring(err):find("the move broke", 1, true) == 1, "and it is the move's own error, first")
    eq(mutedNow(), 0, "every sound is back on")
end)

test("on a client without the mute functions the moves just run", function()
    local mute, unmute = MuteSoundFile, UnmuteSoundFile
    MuteSoundFile, UnmuteSoundFile = nil, nil
    local ran = false
    local okay, err = pcall(MoveSounds.Moving, MoveSounds, "sort", function() ran = true end)
    MuteSoundFile, UnmuteSoundFile = mute, unmute
    assert(okay, err)
    eq(ran, true, "the moves ran")
end)
