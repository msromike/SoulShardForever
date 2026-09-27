-- Soul Shard Forever (SSF). MIT, see LICENSE.
--
-- Counter: one number on the far-left bag button (bag 4, CharacterBag3Slot), the total
-- shard count, centered on the button face. Shown only while the "Show shard count on
-- bag bar" option is on. If the far-left button is not shown (collapsed bag bar), it
-- anchors to the backpack button instead.
-- Font is the profile's LibSharedMedia font name. Size is the largest that fits inside the
-- button face with a margin; the button is the bound. Colorized by default: grey at zero,
-- green at or under the cap, yellow over it; white when the "Colorize" option is off.
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
-- State colors: zero / at or under the cap / over the cap; white when colorizing is off.
-- Shared with the options window's status line through Counter:StateColor.
local GREY, GREEN, YELLOW = { 0.6, 0.6, 0.6, "999999" }, { 0, 1, 0, "00ff00" }, { 1, 0.82, 0, "ffd100" }
local WHITE = { 1, 1, 1, "ffffff" }

-- r, g, b, hex for a count against a cap, honoring the colorize option.
function Counter:StateColor(count, cap)
    local c = WHITE
    if SSF.db.profile.counterColorize then
        c = count == 0 and GREY or count > cap and YELLOW or GREEN
    end
    return c[1], c[2], c[3], c[4]
end

-- The button the counter (and LowGlow) sits on: the far-left bag button, or the backpack
-- when the bag bar is collapsed.
function Counter:Anchor()
    local farLeft = CharacterBag3Slot
    if farLeft and farLeft:IsShown() then return farLeft end
    return MainMenuBarBackpackButton
end
local function Anchor() return Counter:Anchor() end

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
        if self.text then self.text:Hide() end
        return
    end
    local parent = Anchor()
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
