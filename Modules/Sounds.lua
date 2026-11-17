-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Sounds: SSF's sounds in LibSharedMedia's "sound" list, playing one by its LSM name, what
-- a volume level means, and whether the game's item sounds are heard around SSF's own
-- shard moves (Moving). The sounds are Blizzard's own game files, registered by file
-- ID: nothing is bundled.
--   SSF: Bag thunk   file 567559 / sound kit 1200   PutDownBag, the sound of a bag
--                                                    dropped where it can't go; the
--                                                    default pause sound.
-- Registering through LSM is the plumbing for a sound dropdown (AceGUI's LSM30_Sound
-- widget, bundled), which also lists sounds other addons registered.
--
-- Volume: SSF's own sounds play through their sound kit with C_Sound.PlaySound, which
-- takes a per-play volume (Forever's volumeOverride, tested in game). A sound another
-- addon registered is a file only; PlaySoundFile has no volume, so it plays at full.
-- Busy: the game does not start a sound kit again while it is still playing (measured in
-- game: the bag thunk is refused for about 0.7 s, and stopping it first changes nothing),
-- so a press inside that time is silent. Busy() is true from an own sound's start until
-- the game's SOUNDKIT_FINISHED for it, and SSF_SOUND_BUSY says when it changes; the
-- window greys the pause sound slider's "-" and "+" meanwhile, so every click that can
-- be made is heard. If the game never sends the finish, Busy stays true until the next
-- own sound ends.
-- Notches: the pause sound's loudness is one saved number, profile.pauseSoundLevel, the
-- place on the window's slider: 0, 0.25, 0.5, 0.75 or 1 (shown as 0 to 100%). 0 is off.
-- VOLUMES is the one curve from a notch to the volume played: each notch about half the
-- one above it (about 6 dB), so the steps sound even to the ear (tested by ear against
-- evenly spaced volumes). What is saved is the notch, never the volume, so the curve can
-- be retuned without touching anyone's setting; tests/test_sounds.lua pins it so that a
-- retune is deliberate.
-- Before the slider the profile held two values, pauseSound (on/off) and pauseSoundVolume
-- (one of four volumes: 1, 0.5, 0.25, 0.12). LevelFromOld is the one conversion, used by
-- Core once at load: off is notch 0, on is the notch that plays the same volume.
--
-- Channel: an LSM file plays on SFX; an own sound kit plays with C_Sound's default
-- sub-type, as tested in game.
--
-- Moving shards: the game plays an item's pickup and put-down sound on every move, and SSF
-- moves shards from code. Moving(kind, fn) is the one place that decides whether those
-- sounds are heard, and the one place that knows their file IDs (MOVE_FIRST to MOVE_LAST
-- and MOVE_MORE: every item pickup and put-down sound, the list Baganator's sort mutes;
-- all of them, since a SoulSort legacy move swaps another item). The rule (Heard): a sort
-- is never heard, at a press or when combat ends, or a sort at the end of a fight would
-- clink seconds after the last press with no clue it was SSF; a delete is heard out of
-- combat (the tink that says a shard went) and not in combat. Heard decides only the
-- game's item sounds around a move or a delete. SSF's own pause sound is played through
-- Play (PlayPause), which Heard does not touch: whether a paused press plays it, and its
-- silence in combat, is Trimmer's rule, and the options' previews play it on purpose. So
-- a "no SSF sounds at all" option needs Heard and Play both, not Heard alone. Not
-- heard = the game's MuteSoundFile on every one of those files, fn, then UnmuteSoundFile on
-- every one: fn runs protected, so the sounds come back on even when a move throws (the
-- error is raised again afterwards, with where it happened added to its text). A mute
-- left on would silence item sounds for every addon, with nothing to tell the player why.
-- No call that asks whether a file is muted is known (neither function is in the client's
-- UI source or API docs), so if another addon keeps one of these files muted on purpose,
-- the unmute here turns it back on (Baganator's sort does the same). On a client without
-- the two functions fn just runs.
--
-- Public:  Moving(kind, fn) -- runs fn, which moves or deletes shards; kind is "sort" or
--            "delete" (Sorter and Trimmer hand their moves over and know nothing of the
--            rule). Returns nothing, heard or not.
--          Play(name, volume) -- an LSM sound name and a volume 0-1 (nil = full). A name
--            LSM no longer knows (a sound pack removed) falls back to the default; a nil
--            name plays nothing (LSM:IsValid is true for nil).
--          PlayPause() -- the pause sound at the saved notch (profile.pauseSoundName,
--            pauseSoundLevel), nothing at notch 0: a paused press out of combat (Trimmer
--            decides when) and the slider's preview.
--          Busy() -> true while an own sound plays (a play asked for now would be silent).
--          DefaultName() -> the default sound's LSM name (Core's profile default).
--          LevelStep() -> the distance between two notches (the slider's step; its scale
--            is 0 to 1); LevelVolume(level) -> the volume a notch plays, 0 for notch 0 (a
--            number between two notches plays as the nearest);
--            LevelFromOld(on, volume) -> the notch for the two values saved before the
--            slider (volume nil = the old default, full; a volume that was no level = full,
--            the old rule).
-- Listens: SOUNDKIT_FINISHED (the own sound playing has ended).
-- Sends:   SSF_SOUNDS_MUTED (kind) and SSF_SOUNDS_UNMUTED (kind), around an fn that is not
--          heard; SSF_SOUND_PLAYED (the LSM name) from every Play (Debug records all
--          three; no other listener); SSF_SOUND_BUSY (true or false) when an own sound
--          starts and when it ends (Window redraws).
-- Reads:  Combat:Locked (a delete in combat is not heard); profile.pauseSoundName,
--          pauseSoundLevel. Owns the handle of its own sound while it plays; no frames.
-- Acts on: the game's sound: plays one (PlaySound for SSF's own, at the volume given;
--          PlaySoundFile for any other LSM sound), and around a move that is not heard
--          mutes every item pick-up and put-down sound, then unmutes them (MuteSoundFile,
--          UnmuteSoundFile). LibSharedMedia's "sound" list, which every addon shares:
--          SSF's sounds are added to it at enable.
-- Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Sounds = SSF:NewModule("Sounds", "AceEvent-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

local DEFAULT = "SSF: Bag thunk"
-- SSF's own sounds: LSM name -> { file ID for LSM, sound kit ID for volume }
local OWN = {
    [DEFAULT] = { file = 567559, kit = 1200 },
}

-- the volume each notch plays, quietest first: notch 0 (off) to notch 1 (full)
local VOLUMES = { 0, 0.12, 0.25, 0.5, 1 }
local STEPS = #VOLUMES - 1 -- the slider's scale is 0 to 1, in this many steps

function Sounds:DefaultName() return DEFAULT end

function Sounds:LevelStep() return 1 / STEPS end

function Sounds:LevelVolume(level)
    local index = math.floor((tonumber(level) or 0) * STEPS + 0.5) + 1
    return VOLUMES[math.max(1, math.min(#VOLUMES, index))]
end

function Sounds:LevelFromOld(on, volume)
    if not on then return 0 end
    for index, v in ipairs(VOLUMES) do
        if v == volume and index > 1 then return (index - 1) / STEPS end
    end
    return 1
end

-- Setup in OnEnable (Core's warlock gate): on another class the sound stays unregistered.
function Sounds:OnEnable()
    for name, sound in pairs(OWN) do
        LSM:Register("sound", name, sound.file)
    end
    self:RegisterEvent("SOUNDKIT_FINISHED", "OnSoundFinished")
end

local playing -- the handle of SSF's own sound while it plays, or nil

function Sounds:Busy() return playing ~= nil end

function Sounds:OnSoundFinished(_, handle)
    if handle ~= playing then return end
    playing = nil
    self:SendMessage("SSF_SOUND_BUSY", false)
end

function Sounds:Play(name, volume)
    if not LSM:IsValid("sound", name) then name = DEFAULT end
    self:SendMessage("SSF_SOUND_PLAYED", name)
    local own = OWN[name]
    if own then
        -- the sub-type left nil (its default), exactly as tested in game; the fourth
        -- argument asks for SOUNDKIT_FINISHED when it ends. The game answers nothing when
        -- it refuses the play (the same kit still playing), and then nothing changes here.
        local started, handle = C_Sound.PlaySound(own.kit, nil, false, true, nil, volume or 1)
        if started then
            playing = handle
            self:SendMessage("SSF_SOUND_BUSY", true)
        end
        return
    end
    local file = LSM:Fetch("sound", name, true)
    if file then PlaySoundFile(file, "SFX") end
end

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

function Sounds:Moving(kind, fn)
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

function Sounds:PlayPause()
    local p = SSF.db.profile
    local volume = self:LevelVolume(p.pauseSoundLevel)
    if volume > 0 then self:Play(p.pauseSoundName, volume) end
end
