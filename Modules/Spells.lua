-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Spells: a spell's name as the game gives it, in the client's language. The one place SSF
-- asks the game for a spell's name: a macro's /cast line and a sentence that names a spell
-- both ask here, so no translation ever spells one out and a rename by the game reaches
-- every text. The spell ids themselves are Core's (SSF.SPELLS).
--
-- Public:  NameOf(id) -> the spell's name, or nil when the game has none.
-- Owns no state, no events, no frames. Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Spells = SSF:NewModule("Spells")

-- this client has no GetSpellInfo
function Spells:NameOf(id)
    return C_Spell.GetSpellName(id)
end
