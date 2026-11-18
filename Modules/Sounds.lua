-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Sounds: SSF's own sounds: in LibSharedMedia's "sound" list, playing one by its LSM
-- name, and what a volume level means. The sounds are Blizzard's own game files,
-- registered by file ID: nothing is bundled. (Whether the game's item sounds are heard
-- around a shard move is MoveSounds' job.)
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
-- Whether a paused press plays the pause sound, and its silence in combat, is Trimmer's
-- rule; the options' previews play it on purpose.
--
-- Public:  Play(name, volume) -- an LSM sound name and a volume 0-1 (nil = full). A name
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
-- Sends:   SSF_SOUND_PLAYED (the LSM name) from every Play (Debug records it; no other
--          listener); SSF_SOUND_BUSY (true or false) when an own sound
--          starts and when it ends (Window redraws).
-- Reads:   profile.pauseSoundName, pauseSoundLevel. Owns the handle of its own sound while it plays; no frames.
-- Acts on: the game's sound: plays one (PlaySound for SSF's own, at the volume given;
--          PlaySoundFile for any other LSM sound). LibSharedMedia's "sound" list, which every addon shares:
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

function Sounds:PlayPause()
    local p = SSF.db.profile
    local volume = self:LevelVolume(p.pauseSoundLevel)
    if volume > 0 then self:Play(p.pauseSoundName, volume) end
end
