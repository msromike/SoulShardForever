-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Tooltip: where every SSF tooltip sits and how it is shown. One anchor: above-right of
-- the cursor, ANCHOR_X px to its right. Two kinds share it: the ones SSF draws itself
-- (the window's bottom buttons and its help button, through Show/Hide), and the ones
-- AceConfigDialog draws for an option's help line, which it anchors ANCHOR_TOPRIGHT and
-- shares with every addon; those are re-anchored as they show, only while their owner sits
-- inside the frame handed to Attach (SSF's window). The minimap tooltip is LibDataBroker's
-- and the display addon's; its rows are Broker's.
--
-- Public:  Show(owner, title, text, titleGold) -- title in the label gold (true) or white;
--            text in white, one tooltip line per line of text, a blank line as a spacer
--            (handed over as one text the game sometimes drops a blank line)
--          Hide(owner) -- only if the tooltip is still the owner's
--          IsShownFor(owner) -> bool (the owner refreshes an open tooltip's text)
--          Attach(frame) -- option tooltips shown inside this frame get the anchor
-- Hooks:   AceConfigDialog.tooltip's OnShow (AceHook), attached by Attach, hooked again
--          if a newer AceConfigDialog loaded later replaced the tooltip frame.
-- Lib internals: AceConfigDialog.tooltip, the GameTooltip-like frame it shows help lines
--          in. An AceConfigDialog bump that renames it leaves option tooltips at the stock
--          anchor.
-- Reads:   Colors.YELLOW, Colors.WHITE. Owns no state beyond the attached frame.
-- Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Tooltip = SSF:NewModule("Tooltip", "AceHook-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local ANCHOR, ANCHOR_X, ANCHOR_Y = "ANCHOR_CURSOR_RIGHT", 60, 0

function Tooltip:Show(owner, title, text, titleGold)
    local Colors = SSF:GetModule("Colors")
    local c = titleGold and Colors.YELLOW or Colors.WHITE
    local w = Colors.WHITE
    GameTooltip:SetOwner(owner, ANCHOR, ANCHOR_X, ANCHOR_Y)
    GameTooltip:SetText(title or "", c[1], c[2], c[3], 1, true)
    for line in ((text or "") .. "\n"):gmatch("(.-)\n") do
        GameTooltip:AddLine(line == "" and " " or line, w[1], w[2], w[3], true) -- a long line wraps by itself
    end
    GameTooltip:Show()
end

function Tooltip:Hide(owner)
    if GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
end

function Tooltip:IsShownFor(owner)
    return GameTooltip:IsOwned(owner)
end

local function Inside(frame, within)
    while frame do
        if frame == within then return true end
        frame = frame:GetParent()
    end
    return false
end

function Tooltip:OnOptionTooltipShow(tooltip)
    if self.within and Inside(tooltip:GetOwner(), self.within) then
        tooltip:SetAnchorType(ANCHOR, ANCHOR_X, ANCHOR_Y)
    end
end

-- Attach once per AceConfigDialog tooltip frame: a newer AceConfigDialog loaded later by
-- another addon replaces the frame, and AceHook's Unhook on a secure script hook only drops
-- the handler, so the new hook lands on the new frame.
function Tooltip:Attach(frame)
    self.within = frame
    local tooltip = AceConfigDialog.tooltip
    if not tooltip or tooltip == self.hooked then return end
    if self.hooked and self:IsHooked(self.hooked, "OnShow") then self:Unhook(self.hooked, "OnShow") end
    self:SecureHookScript(tooltip, "OnShow", "OnOptionTooltipShow")
    self.hooked = tooltip
end
