-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Colors: every color SSF uses, and the helpers that paint text with them. The one state
-- scale for a shard count (Cap:State says which state a count is in):
--   low   red     below the low mark in use: you're running out, go farm
--   ok    green   from the low mark to the cap: fine
--   over  yellow  over the cap: excess, the next press trims one
--   paused white  stockpiling on purpose: no opinion until unpause
--   quiet  white  no Drain Soul yet, so no way to get a shard: no opinion until it's learned
-- One red everywhere (bag number, chat, tooltip), one green, one yellow; the green and the
-- yellow are the pure ones, as vivid as each other (the yellow was the label gold until
-- 1.9.1: Mike, 2026-10-22). Gold is the game's label color (NORMAL_FONT_COLOR): names
-- quoted in help lines, tooltip titles, the cap tick on the Low shard warn slider. White is
-- the neutral value color for settings. Green doubles as the branding accent on the login
-- line, by Mike's call. Grey never colors a state (it reads as "disabled"); the two greys
-- here are the tooltip's dim label and the chat command echo, which is meant to read as a
-- terminal prompt. Blue is the help "i" while help is on. Code is the macro text in the
-- welcome note's boxes, a pale blue-grey that reads as text to copy; Slate is those boxes'
-- edge. Black is every darkening layer (the title strips, the window's and the note's
-- shade, the macro boxes' fill, the counter's backing, the dimmed slider rail); each
-- layer's alpha is its owner's own number.
-- Every color is typed here once, as r, g, b; the hex an escape code takes is derived
-- (Color), so a change is one edit. Nothing outside this file types a color:
-- tools/check.py fails on any escape code, hex or r, g, b typed elsewhere.
--
-- Public:  Colors.RED, GREEN, YELLOW, GOLD, WHITE, DIM, ECHO, BLUE, CODE, SLATE, BLACK
--            -> { r, g, b, hex }
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

-- a color from its r, g, b (0 to 1), with the six hex digits a |cff escape code takes
local function Color(r, g, b)
    local function hex(v) return string.format("%02x", math.floor(v * 255 + 0.5)) end
    return { r, g, b, hex(r) .. hex(g) .. hex(b) }
end

Colors.RED    = Color(1, 0.25, 0.25)
Colors.GREEN  = Color(0, 1, 0)
Colors.YELLOW = Color(1, 1, 0)
Colors.GOLD   = Color(1, 0.82, 0)
Colors.WHITE  = Color(1, 1, 1)
Colors.DIM    = Color(0.8, 0.8, 0.8)
Colors.ECHO   = Color(0.5, 0.5, 0.5)
Colors.BLUE   = Color(0.35, 0.65, 1)
Colors.CODE   = Color(0.71, 0.80, 0.92)
Colors.SLATE  = Color(0.3, 0.33, 0.36)
Colors.BLACK  = Color(0, 0, 0)

-- the game's warlock purple, should RAID_CLASS_COLORS be missing
local WARLOCK = Color(0.53, 0.53, 0.93)

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
function Colors:Gold(text) return self:Paint(Colors.GOLD, text) end
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
    return WARLOCK[1], WARLOCK[2], WARLOCK[3]
end
