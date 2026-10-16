-- Soul Shard Forever (SSF). MIT, see LICENSE.
--
-- Counter: one number, the total shard count, centered on one bag button. Shown only while
-- the "Show shard count on bag bar" option is on. Where it sits (Anchor):
--   "Show on soul bag when equipped" ticked and a soul bag equipped: that soul bag's button,
--     the reagent slot first, then bag 4 down to bag 1. The bag's slot does not matter.
--   otherwise: the far-left bag button (bag 4, CharacterBag3Slot), or the backpack button
--     when that one is not shown (collapsed bag bar).
-- LowGlow sits on the same button.
-- On a soul bag button the game draws its own number (CharacterReagentBag0SlotCount on the
-- reagent slot). While the counter sits on a soul bag button, that number is set to alpha 0
-- (alpha, because the game calls Show() on it by itself); it is set back to 1 the moment the
-- counter leaves that button or the option is turned off. Bag 4 and the backpack are never
-- touched.
-- Font is the profile's LibSharedMedia font name. Size is the largest that fits inside the
-- button face with a margin; the button is the bound. Colorized by default on the one state
-- scale (red below the low mark, green in range, yellow over the cap; see StateColor);
-- white when the "Colorize" option is off.
--
-- The FontString is raw: AceGUI builds widgets inside its own windows and cannot draw on a
-- Blizzard button. This and DeleteButton are the two frames in SSF not built by Ace.
--
-- Listens: bucketed BAG_UPDATE, SSF_CAP_CHANGED, SSF_SHARD_DELETED, SSF_OPTIONS_CHANGED.
-- Touches nothing else; reads Bags and Cap through their public methods only.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Counter = SSF:NewModule("Counter", "AceEvent-3.0", "AceBucket-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

local MARGIN = 2 -- px kept between the number and the button edge
local MAX_SIZE, MIN_SIZE = 48, 6
-- The one state scale for a shard count, used everywhere a count is shown (bag button,
-- status line, broker text, tooltip):
--   below the low mark (zero included)  red     you're running out, go farm
--   low mark up to the cap              green   fine
--   over the cap                        yellow  excess, the next press trims one
-- White when the colorize option is off. No grey: grey reads as "disabled".
local RED, GREEN, YELLOW = { 1, 0.25, 0.25, "ff4040" }, { 0, 1, 0, "00ff00" }, { 1, 0.82, 0, "ffd100" }
local WHITE = { 1, 1, 1, "ffffff" }

-- r, g, b, hex for a count against the cap and the low mark, honoring the colorize option.
function Counter:StateColor(count, cap)
    local c = WHITE
    if SSF.db.profile.counterColorize then
        -- over the cap wins: with a low mark set above the cap, "too many" is the true state
        if count > cap then c = YELLOW
        elseif count < SSF.db.profile.lowMark then c = RED
        else c = GREEN end
    end
    return c[1], c[2], c[3], c[4]
end

-- The bag bar button for an equipped bag: bags 1-4 are CharacterBag0Slot-CharacterBag3Slot,
-- the reagent slot is CharacterReagentBag0Slot.
local function BagButton(bag)
    if bag == Enum.BagIndex.ReagentBag then return CharacterReagentBag0Slot end
    return _G["CharacterBag" .. (bag - 1) .. "Slot"]
end

-- The first equipped soul bag's button, if it is shown: the reagent slot first, then bag 4
-- down to bag 1 (the backpack is never a soul bag). Nil when there is none.
function Counter:SoulBagButton()
    local Bags = SSF:GetModule("Bags")
    local function Try(bag)
        if not Bags:IsSoulBag(bag) then return nil end
        local button = BagButton(bag)
        if button and button:IsShown() then return button end
    end
    local button = Try(Enum.BagIndex.ReagentBag)
    if button then return button end
    for bag = NUM_BAG_SLOTS, 1, -1 do
        button = Try(bag)
        if button then return button end
    end
end

-- The button the counter (and LowGlow) sits on, and true when it is a soul bag's button.
-- A soul bag only while the counter and "Show on soul bag" are both on; otherwise the
-- far-left bag button, or the backpack when the bag bar is collapsed.
function Counter:Anchor()
    local p = SSF.db.profile
    if p.counter and p.counterSoulBag then
        local soulBag = self:SoulBagButton()
        if soulBag then return soulBag, true end
    end
    local farLeft = CharacterBag3Slot
    if farLeft and farLeft:IsShown() then return farLeft, false end
    return MainMenuBarBackpackButton, false
end
local function Anchor() return Counter:Anchor() end

-- The game's own number on a bag button (the ItemButton's Count text), or nil.
local function GameCount(button)
    return button and (button.Count or _G[(button:GetName() or "") .. "Count"]) or nil
end

-- Hides the game's own number on `button` (a soul bag button the counter sits on), and
-- gives back the one hidden before if it was on another button. Nil gives it back only.
function Counter:HideGameCount(button)
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

-- Applies the profile font at MAX_SIZE, then steps the size down until the number fits
-- inside the button face with the margin.
function Counter:Fit(parent)
    local font = LSM:Fetch("font", SSF.db.profile.counterFont)
    local size = MAX_SIZE
    local maxW, maxH = parent:GetWidth() - MARGIN * 2, parent:GetHeight() - MARGIN * 2
    self.text:SetFont(font, size, "OUTLINE")
    while size > MIN_SIZE and (self.text:GetStringWidth() > maxW or self.text:GetStringHeight() > maxH) do
        size = size - 1
        self.text:SetFont(font, size, "OUTLINE")
    end
end

function Counter:Refresh()
    local p = SSF.db.profile
    if not p.counter then
        self:HideGameCount(nil) -- count off: the game's number is always back
        if self.text then self.text:Hide() end
        return
    end
    local parent, onSoulBag = Anchor()
    -- only a soul bag button loses the game's number; bag 4 and the backpack keep theirs
    self:HideGameCount(onSoulBag and parent or nil)
    if not parent then return end
    if not self.text then
        self.text = parent:CreateFontString(nil, "OVERLAY")
    end
    if self.text:GetParent() ~= parent then
        self.text:SetParent(parent)
    end
    self.text:ClearAllPoints()
    self.text:SetPoint("CENTER", parent, "CENTER", 0, 0)

    local count, cap = SSF:GetModule("Bags"):Count(), SSF:GetModule("Cap"):Get()
    self.text:SetFont(LSM:Fetch("font", p.counterFont), MAX_SIZE, "OUTLINE") -- font before text
    self.text:SetText(count)
    self:Fit(parent)
    local r, g, b = self:StateColor(count, cap)
    self.text:SetTextColor(r, g, b)
    self.text:Show()
end

function Counter:OnEnable()
    self:RegisterMessage("SSF_CAP_CHANGED", "Refresh")
    self:RegisterMessage("SSF_SHARD_DELETED", "Refresh")
    self:RegisterMessage("SSF_OPTIONS_CHANGED", "Refresh")
    self:RegisterBucketEvent({ "BAG_UPDATE", "BAG_CONTAINER_UPDATE" }, 0.5, "Refresh")
    self:Refresh()
end
