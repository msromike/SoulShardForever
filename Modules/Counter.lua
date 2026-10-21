-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Counter: one number, the total shard count, centered on one bag button. Shown only while
-- the "Show shard count on bag bar" option is on. Where it sits (Anchor):
--   "Show on soul bag when equipped" ticked and a soul bag equipped: that soul bag's button,
--     the reagent slot first, then bag 4 down to bag 1. The bag's slot does not matter.
--   otherwise: the far-left bag button (bag 4, CharacterBag3Slot), or the backpack button
--     when that one is not shown (collapsed bag bar).
-- LowGlow sits on the same button: after every refresh the button and the count go out as
-- SSF_COUNTER_UPDATED, so the glow never reads the bags or the anchor itself.
-- On a soul bag button the game draws its own number (CharacterReagentBag0SlotCount on the
-- reagent slot). While the counter sits on a soul bag button, that number is set to alpha 0
-- (alpha, because the game calls Show() on it by itself); it is set back to 1 the moment the
-- counter leaves that button or the option is turned off. Bag 4 and the backpack are never
-- touched.
-- Font is the profile's LibSharedMedia font name. Size is the largest that fits inside the
-- button face with a margin; the button is the bound. Colored on the one state scale
-- (Cap:State, Colors:ForState) when "Colorize" is on; white when off.
--
-- Public:  Anchor() -> button, onSoulBag; SoulBagButton(); Refresh().
-- Listens: SSF_BAGS_CHANGED, SSF_CAP_CHANGED, SSF_SHARD_DELETED, SSF_OPTIONS_CHANGED.
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

local MARGIN = 2 -- px kept between the number and the button edge
local MAX_SIZE, MIN_SIZE = 48, 6

-- The bag bar button for an equipped bag: bags 1-4 are CharacterBag0Slot-CharacterBag3Slot,
-- the reagent slot is CharacterReagentBag0Slot.
local function BagButton(bag)
    if bag == Enum.BagIndex.ReagentBag then return CharacterReagentBag0Slot end
    return _G["CharacterBag" .. (bag - 1) .. "Slot"]
end

-- The first equipped soul bag's button, if it is shown: the reagent slot first, then bag 4
-- down to bag 1 (Bags:SoulBags walked backwards). Nil when there is none.
function Counter:SoulBagButton()
    local soulBags = SSF:GetModule("Bags"):SoulBags()
    for i = #soulBags, 1, -1 do
        local button = BagButton(soulBags[i])
        if button and button:IsShown() then return button end
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

-- Sets the number in the profile font at MAX_SIZE (the FontString needs a font before any
-- text), then steps the size down until it fits inside the button face with the margin.
function Counter:Fit(parent, count)
    local font = LSM:Fetch("font", SSF.db.profile.counterFont)
    local size = MAX_SIZE
    local maxW, maxH = parent:GetWidth() - MARGIN * 2, parent:GetHeight() - MARGIN * 2
    self.text:SetFont(font, size, "OUTLINE")
    self.text:SetText(count)
    while size > MIN_SIZE and (self.text:GetStringWidth() > maxW or self.text:GetStringHeight() > maxH) do
        size = size - 1
        self.text:SetFont(font, size, "OUTLINE")
    end
end

function Counter:Refresh()
    local p = SSF.db.profile
    local count = SSF:GetModule("Bags"):Count()
    if not p.counter then
        self:HideGameCount(nil) -- count off: the game's number is always back
        if self.text then self.text:Hide() end
        self:SendMessage("SSF_COUNTER_UPDATED", nil, count)
        return
    end
    local parent, onSoulBag = self:Anchor()
    -- only a soul bag button loses the game's number; bag 4 and the backpack keep theirs
    self:HideGameCount(onSoulBag and parent or nil)
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

    self:Fit(parent, count)
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
    self:Refresh()
end
