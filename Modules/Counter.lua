-- Soul Shard Forever (SSF). GPLv3, see LICENSE.
--
-- Counter: one number on the far-left bag button (bag 4, CharacterBag3Slot), the total
-- shard count, centered on the button face. Shown only while the "Show shard count on
-- bag bar" option is on. If the far-left button is not shown (collapsed bag bar), it
-- anchors to the backpack button instead.
-- Look comes from the profile: font (a LibSharedMedia font name), size, color at or under
-- the cap, color over the cap. The size is shrunk if needed so the number never spills past
-- the button's edges; the button is the bound.
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
local MIN_SIZE = 6

local function Anchor()
    local farLeft = CharacterBag3Slot
    if farLeft and farLeft:IsShown() then return farLeft end
    return MainMenuBarBackpackButton
end

-- Applies the profile font at the profile size, then steps the size down until the number
-- fits inside the button face with the margin.
function Counter:Fit(parent)
    local p = SSF.db.profile
    local font = LSM:Fetch("font", p.counterFont)
    local size = p.counterSize
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
    local c = count > cap and p.counterOverColor or p.counterColor
    self.text:SetFont(LSM:Fetch("font", p.counterFont), p.counterSize, "OUTLINE") -- font before text
    self.text:SetText(count)
    self:Fit(parent)
    self.text:SetTextColor(c.r, c.g, c.b)
    self.text:Show()
end

function Counter:OnEnable()
    self:RegisterMessage("SSF_CAP_CHANGED", "Refresh")
    self:RegisterMessage("SSF_SHARD_DELETED", "Refresh")
    self:RegisterMessage("SSF_OPTIONS_CHANGED", "Refresh")
    self:RegisterBucketEvent({ "BAG_UPDATE", "BAG_CONTAINER_UPDATE" }, 0.5, "Refresh")
    self:Refresh()
end
