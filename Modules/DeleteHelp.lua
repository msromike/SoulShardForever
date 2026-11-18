-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- DeleteHelp: the text that teaches every way to delete a shard: a first paragraph (the
-- caller's own), the one-line lead-in, then the recommended macros (Macros' list, in its
-- order). The Delete Shard tooltip and the welcome note both show it, each with its own
-- first paragraph.
-- What the player types or copies is in the code color (Colors): the command in the
-- lead-in, and in the tooltip's one string the macros. The welcome note draws a macro
-- in its own box, in that color, so a block's text carries none.
--
-- Public:  Blocks(first) -> the content as a list, for the welcome note's layout:
--            { text } paragraphs and { text, macro = true } macros.
--          Text(first) -> the same blocks as one string, for the tooltip.
--          first is an already translated string.
-- Reads:   Macros:Keys(), Macros:Body(key); Colors:Commands, Colors:Code.
-- Owns no state, no events, no frames. Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local DeleteHelp = SSF:NewModule("DeleteHelp")
local ADDON = ...
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)

function DeleteHelp:Blocks(first)
    local Macros, Colors = SSF:GetModule("Macros"), SSF:GetModule("Colors")
    local blocks = {
        { text = first },
        { text = Colors:Commands(L["In a macro, put /ssf delete on the line before the ability:"]) },
    }
    for _, key in ipairs(Macros:Keys()) do
        blocks[#blocks + 1] = { text = Macros:Body(key), macro = true }
    end
    return blocks
end

function DeleteHelp:Text(first)
    local Colors = SSF:GetModule("Colors")
    local parts = {}
    for _, block in ipairs(self:Blocks(first)) do
        parts[#parts + 1] = block.macro and Colors:Code(block.text) or block.text
    end
    return table.concat(parts, "\n\n")
end
