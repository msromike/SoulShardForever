-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Sounds: SSF's sounds in LibSharedMedia's "sound" list, and playing one by its LSM name.
-- The sounds are Blizzard's own game files, registered by file ID: nothing is bundled.
--   SSF: Bag thunk   file 567559 / sound kit 1200   PutDownBag, the sound of a bag
--                                                    dropped where it can't go; the
--                                                    default pause sound.
-- Registering through LSM is the plumbing for a sound dropdown (AceGUI's LSM30_Sound
-- widget, bundled), which also lists sounds other addons registered.
--
-- Volume: SSF's own sounds play through their sound kit with C_Sound.PlaySound, which
-- takes a per-play volume (Forever's volumeOverride, tested in game). A sound another
-- addon registered is a file only; PlaySoundFile has no volume, so it plays at full.
--
-- Takes:   Sounds:Play(name, volume) -- an LSM sound name, usually profile.pauseSoundName,
--          and a volume 0-1 (nil = full). A name LSM no longer knows (a sound pack
--          removed) falls back to the default.
-- Channel: an LSM file plays on SFX; an own sound kit plays with C_Sound's default
-- sub-type, as tested in game.
-- Owns no state, no events, no frames.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Sounds = SSF:NewModule("Sounds")
local LSM = LibStub("LibSharedMedia-3.0")

local DEFAULT = "SSF: Bag thunk"
-- SSF's own sounds: LSM name -> { file ID for LSM, sound kit ID for volume }
local OWN = {
    [DEFAULT] = { file = 567559, kit = 1200 },
}

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
