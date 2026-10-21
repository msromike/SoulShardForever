-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Sounds: SSF's sounds in LibSharedMedia's "sound" list, playing one by its LSM name, and
-- what a volume level means. The sounds are Blizzard's own game files, registered by file
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
-- Levels: each one half the one before, about 6 dB apart, so the steps sound even to the
-- ear (tested by ear against evenly spaced levels). The key is what the dropdown stores;
-- the volume goes into profile.pauseSoundVolume. (A fifth level, 0.06, was too faint to
-- be useful and was dropped in 1.8.1.)
--
-- Public:  Play(name, volume) -- an LSM sound name and a volume 0-1 (nil = full). A name
--            LSM no longer knows (a sound pack removed) falls back to the default.
--          PlayPause() -- the pause sound at the saved level (profile.pauseSoundName,
--            pauseSoundVolume): every paused press and the options previews.
--          LevelKeys() -> the keys in dropdown order; LevelVolume(key) -> volume;
--          LevelKey(volume) -> key ("full" for an unknown volume); IsLevel(volume).
-- Channel: an LSM file plays on SFX; an own sound kit plays with C_Sound's default
--          sub-type, as tested in game.
-- Reads:   profile.pauseSoundName, pauseSoundVolume. Owns no state, no events, no frames.
-- Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Sounds = SSF:NewModule("Sounds")
local LSM = LibStub("LibSharedMedia-3.0")

local DEFAULT = "SSF: Bag thunk"
-- SSF's own sounds: LSM name -> { file ID for LSM, sound kit ID for volume }
local OWN = {
    [DEFAULT] = { file = 567559, kit = 1200 },
}

local LEVELS = {
    { key = "full", volume = 1 },
    { key = "loud", volume = 0.5 },
    { key = "medium", volume = 0.25 },
    { key = "quiet", volume = 0.12 },
}

function Sounds:LevelKeys()
    local keys = {}
    for i, level in ipairs(LEVELS) do keys[i] = level.key end
    return keys
end

function Sounds:LevelVolume(key)
    for _, level in ipairs(LEVELS) do
        if level.key == key then return level.volume end
    end
    return 1
end

function Sounds:LevelKey(volume)
    for _, level in ipairs(LEVELS) do
        if level.volume == volume then return level.key end
    end
    return "full"
end

function Sounds:IsLevel(volume)
    for _, level in ipairs(LEVELS) do
        if level.volume == volume then return true end
    end
    return false
end

-- Setup in OnEnable, as every module: the warlock gate leaves it unregistered elsewhere.
function Sounds:OnEnable()
    for name, sound in pairs(OWN) do
        LSM:Register("sound", name, sound.file)
    end
end

function Sounds:Play(name, volume)
    if not LSM:IsValid("sound", name) then name = DEFAULT end
    local own = OWN[name]
    if own then
        -- the sub-type left nil (its default), exactly as tested in game
        C_Sound.PlaySound(own.kit, nil, false, false, nil, volume or 1)
        return
    end
    local file = LSM:Fetch("sound", name, true)
    if file then PlaySoundFile(file, "SFX") end
end

function Sounds:PlayPause()
    local p = SSF.db.profile
    self:Play(p.pauseSoundName, p.pauseSoundVolume)
end
