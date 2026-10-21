-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- LowGlow: while the count is in the "low" state (Cap:State: below the low mark in use),
-- the bag button the counter sits on gets a running border (LibCustomGlow's pixel glow)
-- on its own edge, in the same red the number shows, three pixels thick, moving slowly. Not
-- the game's proc glow: that one is sized 40% past the button, spills onto the bags beside
-- it, is gold while the number is red, and says "press this" (Amelia, Mike, 2026-10-21).
-- The border stays on until the count is back at the mark, so a glance at the bag bar says
-- "go farm shards". Part of the bag display: it runs only while "Show shard count on bag
-- bar" is on (a glow with no number explains nothing; Counter sends no button then), and
-- is off via the "Glow bag button when low" option under it.
--
-- Listens: SSF_COUNTER_UPDATED (button or nil, count): Counter sends it after every refresh,
--          which covers bag, cap, delete and option changes; nothing else is needed.
-- Reads:   Cap:State(count), Colors.RED; profile.lowGlow. Asks Counter:Refresh() once at
--          enable, so the first state is heard (Counter enables first and had already sent it).
-- Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local LowGlow = SSF:NewModule("LowGlow", "AceEvent-3.0")
local LCG = LibStub("LibCustomGlow-1.0")

-- the pixel glow: LINES segments running round the button edge once every PERIOD seconds,
-- THICKNESS px, no offset past the edge, no dark backing strip behind the lines
local LINES = 8
local PERIOD = 3       -- seconds per lap (the library takes a frequency, 1 / PERIOD)
local THICKNESS = 3    -- 2 was too quiet on the bag bar (Mike, 2026-10-21)
local KEY = "SSF"

local function Start(button)
    local c = SSF:GetModule("Colors").RED
    LCG.PixelGlow_Start(button, { c[1], c[2], c[3], 1 }, LINES, 1 / PERIOD, nil, THICKNESS, 0, 0, false, KEY)
end

function LowGlow:OnCounterUpdated(_, button, count)
    local low = button and SSF.db.profile.lowGlow and SSF:GetModule("Cap"):State(count) == "low"

    -- the anchor can change (bag bar collapsed): stop the old button before starting a new one
    if self.button and (self.button ~= button or not low) then
        LCG.PixelGlow_Stop(self.button, KEY)
        self.button = nil
    end
    if low and self.button ~= button then
        Start(button)
        self.button = button
    end
end

function LowGlow:OnEnable()
    self:RegisterMessage("SSF_COUNTER_UPDATED", "OnCounterUpdated")
    SSF:GetModule("Counter"):Refresh()
end
