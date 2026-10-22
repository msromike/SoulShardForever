-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Counter: one number, the total shard count, centered on one bag button. Shown only while
-- the "Show shard count on bag bar" option is on. Where it sits (Anchor):
--   "Show on soul bag when equipped" ticked and a soul bag equipped: that soul bag's button,
--     if shown, the reagent slot first, then bag 4 down to bag 1. The bag's slot does not
--     matter.
--   otherwise: the far-left bag button (bag 4, CharacterBag3Slot), or the backpack button
--     should that one be hidden (a fallback only: this client has no bag bar collapse,
--     checked in game 2026-10-21; a bar addon could hide it).
-- LowGlow sits on the same button: after every refresh the button and the count go out as
-- SSF_COUNTER_UPDATED, so the glow never reads the bags or the anchor itself.
-- On a soul bag button the game draws its own number (CharacterReagentBag0SlotCount on the
-- reagent slot). While the counter sits on a soul bag button, that number is set to alpha 0
-- (alpha, because the game calls Show() on it by itself); it is set back to 1 the moment the
-- counter leaves that button or the option is turned off. Bag 4 as the far-left fallback and
-- the backpack are never touched.
-- Font is the profile's LibSharedMedia font name (Arial Narrow by default: its digits have
-- air between them). Size is the largest that fits inside the button face with 15% of
-- the face kept clear on each side, the outline counted, between MIN_SIZE and MAX_SIZE.
-- The old two-pixel margin let the number fill the face edge to edge and hide the bag
-- (Mike, 2026-10-21). Colored on the one state scale (Cap:State, Colors:ForState) when
-- "Colorize" is on; white when off, and white while paused or quiet (State answers
-- "paused" or "quiet").
--
-- Public:  Refresh() (LowGlow asks it once at enable, to hear the first state).
-- Listens: SSF_BAGS_CHANGED, SSF_CAP_CHANGED, SSF_SHARD_DELETED, SSF_OPTIONS_CHANGED,
--          SSF_QUIET_ENDED.
-- Sends:   SSF_COUNTER_UPDATED (button or nil, count) after every refresh.
-- Reads:   Bags:Count(), Bags:SoulBags(), Cap:State(), Colors; profile.counter,
--          counterSoulBag, counterFont, counterColorize.
-- Exceptions: the FontString is raw: AceGUI builds widgets inside its own windows and
--          cannot draw on a Blizzard button. One of the three raw frames in SSF
--          (DeleteButton's named button and Window's title strips are the others).
-- Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Counter = SSF:NewModule("Counter", "AceEvent-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

local MARGIN = 0.15 -- of the face kept clear on each side of the number (so it takes 70%);
                    -- tuned by eye for Arial Narrow, the default; another font is the player's pick
local OUTLINE = 1  -- px the OUTLINE flag draws round each glyph; GetStringWidth leaves it out
local MAX_SIZE, MIN_SIZE = 48, 6

-- The bag bar button for an equipped bag: bags 1-4 are CharacterBag0Slot-CharacterBag3Slot,
-- the reagent slot is CharacterReagentBag0Slot.
local function BagButton(bag)
    if bag == Enum.BagIndex.ReagentBag then return CharacterReagentBag0Slot end
    return _G["CharacterBag" .. (bag - 1) .. "Slot"]
end

-- The first equipped soul bag's button, if it is shown: the reagent slot first, then bag 4
-- down to bag 1 (Bags:SoulBags walked backwards). Nil when there is none.
local function SoulBagButton()
    local soulBags = SSF:GetModule("Bags"):SoulBags()
    for i = #soulBags, 1, -1 do
        local button = BagButton(soulBags[i])
        if button and button:IsShown() then return button end
    end
end

-- The button the counter (and LowGlow) sits on, and true when it is a soul bag's button.
-- A soul bag only while the counter and "Show on soul bag" are both on; otherwise the
-- far-left bag button, or the backpack should that button be hidden (see the header).
local function Anchor()
    local p = SSF.db.profile
    if p.counter and p.counterSoulBag then
        local soulBag = SoulBagButton()
        if soulBag then return soulBag, true end
    end
    local farLeft = CharacterBag3Slot
    if farLeft and farLeft:IsShown() then return farLeft, false end
    return MainMenuBarBackpackButton, false
end

-- The game's own number on a bag button (the ItemButton's Count text), or nil.
local function GameCount(button)
    return button and (button.Count or _G[(button:GetName() or "") .. "Count"]) or nil
end

-- Hides the game's own number on `button` (a soul bag button the counter sits on), and
-- gives back the one hidden before if it was on another button. Nil gives it back only.
local function HideGameCount(self, button)
    local text = GameCount(button)
    if self.hiddenCount and self.hiddenCount ~= text then
        self.hiddenCount:SetAlpha(1)
        self.hiddenCount = nil
    end
    if text then
        text:SetAlpha(0)
        self.hiddenCount = text
    end
end

-- Sets the number in the profile font at MAX_SIZE (the FontString needs a font before any
-- text), then steps the size down until it, outline included, fits inside the button face
-- with the margin.
local function Fit(self, parent, count)
    local font = LSM:Fetch("font", SSF.db.profile.counterFont)
    local size = MAX_SIZE
    local maxW, maxH = parent:GetWidth() * (1 - MARGIN * 2), parent:GetHeight() * (1 - MARGIN * 2)
    self.text:SetFont(font, size, "OUTLINE")
    self.text:SetText(count)
    while size > MIN_SIZE and (self.text:GetStringWidth() + OUTLINE * 2 > maxW
            or self.text:GetStringHeight() + OUTLINE * 2 > maxH) do
        size = size - 1
        self.text:SetFont(font, size, "OUTLINE")
    end
end

function Counter:Refresh()
    local p = SSF.db.profile
    local count = SSF:GetModule("Bags"):Count()
    if not p.counter then
        HideGameCount(self, nil) -- count off: the game's number is always back
        if self.text then self.text:Hide() end
        self:SendMessage("SSF_COUNTER_UPDATED", nil, count)
        return
    end
    local parent, onSoulBag = Anchor()
    -- only a soul bag button loses the game's number; the far-left fallback and the backpack keep theirs
    HideGameCount(self, onSoulBag and parent or nil)
    if not parent then
        self:SendMessage("SSF_COUNTER_UPDATED", nil, count)
        return
    end
    if not self.text then
        self.text = parent:CreateFontString(nil, "OVERLAY")
    end
    if self.text:GetParent() ~= parent then
        self.text:SetParent(parent)
    end
    self.text:ClearAllPoints()
    self.text:SetPoint("CENTER", parent, "CENTER", 0, 0)

    Fit(self, parent, count)
    -- the one place the colorize option applies
    local Colors = SSF:GetModule("Colors")
    local r, g, b = Colors.WHITE[1], Colors.WHITE[2], Colors.WHITE[3]
    if p.counterColorize then r, g, b = Colors:ForState(SSF:GetModule("Cap"):State(count)) end
    self.text:SetTextColor(r, g, b)
    self.text:Show()
    self:SendMessage("SSF_COUNTER_UPDATED", parent, count)
end

function Counter:OnEnable()
    self:RegisterMessage("SSF_BAGS_CHANGED", "Refresh")
    self:RegisterMessage("SSF_CAP_CHANGED", "Refresh")
    self:RegisterMessage("SSF_SHARD_DELETED", "Refresh")
    self:RegisterMessage("SSF_OPTIONS_CHANGED", "Refresh")
    self:RegisterMessage("SSF_QUIET_ENDED", "Refresh")
    self:Refresh()
end
