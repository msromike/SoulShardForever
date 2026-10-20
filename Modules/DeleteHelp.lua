-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- DeleteHelp: the text that teaches every way to delete a shard: a first paragraph (the
-- caller's own), the two recommended macros and when to use the Bane one. The Delete Shard
-- tooltip and the welcome note both show it, each with its own first paragraph.
--
-- Public:  Text(first) -> the whole block; first is an already translated string.
-- Reads:   Macros:Body(key), Macros:SpellName(key). Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local DeleteHelp = SSF:NewModule("DeleteHelp")
local L = LibStub("AceLocale-3.0"):GetLocale("SoulShardForever")

function DeleteHelp:Text(first)
    local Macros = SSF:GetModule("Macros")
    local lifeTap, bane = Macros:SpellName("LT"), Macros:SpellName("BoA")
    -- English names "Bane" itself and takes only Life Tap's name (%s); a translation names
    -- both, positionally (%1$s Life Tap, %2$s Bane). Extra arguments are ignored.
    return first
        .. "\n\n" .. L["In a macro, put /ssf delete on the line before the ability:"]
        .. "\n\n" .. Macros:Body("LT")
        .. "\n\n" .. Macros:Body("BoA")
        .. "\n\n" .. L["The Bane macro lets you delete on the move when you don't want to use %s."]:format(lifeTap, bane)
        .. " " .. L["Make sure you're not targeting an enemy with the Bane macro. Otherwise it won't delete because you'll be in combat before the delete fires."]:format(bane)
end
