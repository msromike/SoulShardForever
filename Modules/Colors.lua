-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Colors: every color SSF uses, and the helpers that paint text with them. The one state
-- scale for a shard count (Cap:State says which state a count is in):
--   low   red     below the low mark in use: you're running out, go farm
--   ok    green   from the low mark to the cap: fine
--   over  yellow  over the cap: excess, the next press trims one
--   paused white  stockpiling on purpose: no opinion until unpause
--   quiet  white  no Drain Soul yet, so no way to get a shard: no opinion until it's learned
-- One red everywhere (bag number, chat, tooltip), one green, one yellow. The yellow is
-- also the game's label gold (NORMAL_FONT_COLOR), used for names quoted in help lines.
-- White is the neutral value color for settings. Green doubles as the branding accent on
-- the login line, by Mike's call. Grey never colors a state (it reads as "disabled"); the
-- two greys here are the tooltip's dim label and the chat command echo, which is meant to
-- read as a terminal prompt. Black is the title strips' color (their alpha is Window's).
--
-- Public:  Colors.RED, GREEN, YELLOW, WHITE, DIM, ECHO, BLACK -> { r, g, b, hex }
--          Colors:ForState(state) -> r, g, b, hex for "low" / "ok" / "over" / "paused" /
--            "quiet"
--          Colors:Paint(color, text) -> text wrapped in the color's escape codes
--          Colors:PaintState(state, text) -> text in the state's color
--          Colors:Value(v) -> v in white (a setting's value)
--          Colors:Accent(v) -> v in green (branding)
--          Colors:OnOff(b) -> green ON / red OFF
--          Colors:State(text, good) -> text in green (good) or red
--          Colors:Gold(text) -> text in the label gold
--          Colors:Echo(text) -> text in the command echo grey
--          Colors:Class() -> r, g, b of the warlock class color (titles only)
-- Reads:   L for ON and OFF. Owns no state, no events, no frames.
-- Touches nothing else.

local ADDON = ...
local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Colors = SSF:NewModule("Colors")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)

Colors.RED    = { 1, 0.25, 0.25, "ff4040" }
Colors.GREEN  = { 0, 1, 0, "00ff00" }
Colors.YELLOW = { 1, 0.82, 0, "ffd100" }
Colors.WHITE  = { 1, 1, 1, "ffffff" }
Colors.DIM    = { 0.8, 0.8, 0.8, "cccccc" }
Colors.ECHO   = { 0.5, 0.5, 0.5, "808080" }
Colors.BLACK  = { 0, 0, 0, "000000" }

local BY_STATE = { low = Colors.RED, ok = Colors.GREEN, over = Colors.YELLOW, paused = Colors.WHITE,
    quiet = Colors.WHITE }

function Colors:ForState(state)
    local c = BY_STATE[state] or Colors.WHITE
    return c[1], c[2], c[3], c[4]
end

function Colors:Paint(color, text)
    return "|cff" .. color[4] .. tostring(text) .. "|r"
end

function Colors:PaintState(state, text)
    return self:Paint(BY_STATE[state] or Colors.WHITE, text)
end

function Colors:Value(v) return self:Paint(Colors.WHITE, v) end
function Colors:Accent(v) return self:Paint(Colors.GREEN, v) end
function Colors:Gold(text) return self:Paint(Colors.YELLOW, text) end
function Colors:Echo(text) return self:Paint(Colors.ECHO, text) end

function Colors:OnOff(b)
    return b and self:Paint(Colors.GREEN, L["ON"]) or self:Paint(Colors.RED, L["OFF"])
end

function Colors:State(text, good)
    return self:Paint(good and Colors.GREEN or Colors.RED, text)
end

-- r, g, b of the warlock class color: the window title (and the side note's, which copies
-- it), its group titles, the minimap tooltip title, and nothing else
function Colors:Class()
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS.WARLOCK
    if c then return c.r, c.g, c.b end
    return 0.53, 0.53, 0.93
end
