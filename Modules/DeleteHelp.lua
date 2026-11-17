-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- DeleteHelp: the text that teaches every way to delete a shard: a first paragraph (the
-- caller's own), the one-line lead-in, the two recommended macros, then what the Bane macro
-- is for and its warning. The Delete Shard tooltip and the welcome note both show it, each
-- with its own first paragraph.
-- Not a spec: the warning's last sentence, "SSF cannot delete a shard while in combat", is
-- player-facing text that is out of date on purpose. SSF does delete in combat (Trimmer);
-- the sentence changes with the full release of delete in combat, in vetted wording,
-- in all six languages. Do not change it, or build on it, before then.
--
-- Public:  Blocks(first) -> the content as a list, for the welcome note's layout:
--            { text } paragraphs and { text, macro = true } macros.
--          Text(first) -> the same blocks as one string, for the tooltip.
--          first is an already translated string.
-- Reads:   Macros:Body(key), Macros:SpellName(key).
-- Owns no state, no events, no frames. Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local DeleteHelp = SSF:NewModule("DeleteHelp")
local ADDON = ...
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)

function DeleteHelp:Blocks(first)
    local Macros = SSF:GetModule("Macros")
    local lifeTap, bane = Macros:SpellName("LT"), Macros:SpellName("BoA")
    -- What the Bane macro is for, then its warning. English names Bane itself in both:
    -- the first line takes only Life Tap's name (%s), the warning none. A translation takes
    -- the spell names: the first line both, positionally (%1$s Life Tap, %2$s Bane), the
    -- warning Bane's as %s. Extra arguments are ignored.
    return {
        { text = first },
        { text = L["In a macro, put /ssf delete on the line before the ability:"] },
        { text = Macros:Body("LT"), macro = true },
        { text = Macros:Body("BoA"), macro = true },
        { text = L["The Bane macro lets you delete on the move when you don't want to use %s."]:format(lifeTap, bane)
            .. " " .. L["Make sure you're not targeting an enemy with the Bane macro, because it puts you in combat. SSF cannot delete a shard while in combat."]:format(bane) },
    }
end

function DeleteHelp:Text(first)
    local parts = {}
    for _, block in ipairs(self:Blocks(first)) do parts[#parts + 1] = block.text end
    return table.concat(parts, "\n\n")
end
