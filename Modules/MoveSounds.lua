-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- MoveSounds: whether the game's item sounds are heard around SSF's own shard moves. The
-- game plays an item's pickup and put-down sound on every move, and SSF moves shards from
-- code. Moving(kind, fn) is the one place that decides whether those sounds are heard, and
-- the one place that knows their file IDs (MOVE_FIRST to MOVE_LAST and MOVE_MORE: every
-- item pickup and put-down sound, the list Baganator's sort mutes; all of them, since a
-- SoulSort legacy move swaps another item).
-- The rule (Heard): a sort is never heard, at a press or when combat ends, or a sort at
-- the end of a fight would clink seconds after the last press with no clue it was SSF; a
-- delete is heard out of combat (the tink that says a shard went) and not in combat.
-- Heard decides only the game's item sounds around a move or a delete. SSF's own pause
-- sound is Sounds' (Play, PlayPause), which Heard does not touch: whether a paused press
-- plays it, and its silence in combat, is Trimmer's rule. So a "no SSF sounds at all"
-- option needs this module and Sounds both.
-- Not heard = the game's MuteSoundFile on every one of those files, fn, then
-- UnmuteSoundFile on every one: fn runs protected, so the sounds come back on even when a
-- move throws (the error is raised again afterwards, with where it happened added to its
-- text). A mute left on would silence item sounds for every addon, with nothing to tell
-- the player why. No call that asks whether a file is muted is known (neither function is
-- in the client's UI source or API docs), so if another addon keeps one of these files
-- muted on purpose, the unmute here turns it back on (Baganator's sort does the same). On
-- a client without the two functions fn just runs.
--
-- Public:  Moving(kind, fn) -- runs fn, which moves or deletes shards; kind is "sort" or
--            "delete" (Sorter and Trimmer hand their moves over and know nothing of the
--            rule). Returns nothing, heard or not.
-- Sends:   SSF_SOUNDS_MUTED (kind) and SSF_SOUNDS_UNMUTED (kind), around an fn that is not
--          heard (Debug records both; no other listener).
-- Reads:   Combat:Locked (a delete in combat is not heard). Owns no state, no frames.
-- Acts on: the game's sound: around a move that is not heard, mutes every item pick-up
--          and put-down sound, then unmutes them (MuteSoundFile, UnmuteSoundFile).
-- Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local MoveSounds = SSF:NewModule("MoveSounds", "AceEvent-3.0")

-- every item pickup and put-down sound, by file ID: one run of IDs, then the rest
local MOVE_FIRST, MOVE_LAST = 567542, 567577
local MOVE_MORE = { 2308876, 2308881, 2308889, 2308894, 2308901, 2308907, 2308914, 2308920, 2308925, 2308930, 2308935, 2308942, 2308948, 2308956, 2308962, 2308968, 2308974, 2308985, 2308992, 2309001, 2309006, 2309013, 2309025, 2309036, 2309051, 2309057, 2309070, 2309078, 2309089, 2309100, 2309109, 2309120, 2309126, 2309132, 2309137, 2309141 }

local function EachMoveSound(fn)
    for id = MOVE_FIRST, MOVE_LAST do fn(id) end
    for _, id in ipairs(MOVE_MORE) do fn(id) end
end

-- The rule: is a move of this kind heard? See the header.
local function Heard(kind)
    return kind == "delete" and not SSF:GetModule("Combat"):Locked()
end

function MoveSounds:Moving(kind, fn)
    if Heard(kind) or not (MuteSoundFile and UnmuteSoundFile) then
        fn()
        return
    end
    EachMoveSound(MuteSoundFile)
    self:SendMessage("SSF_SOUNDS_MUTED", kind)
    -- the handler adds where the error happened: raising it again from here would
    -- otherwise show only this line
    local okay, err = xpcall(fn, function(e) return tostring(e) .. "\n" .. debugstack(2) end)
    EachMoveSound(UnmuteSoundFile)
    self:SendMessage("SSF_SOUNDS_UNMUTED", kind)
    if not okay then error(err, 0) end
end
