-- Soul Shard Forever (SSF). MIT, see LICENSE.
--
-- SSFDropdownItemTip: an AceGUI dropdown item. The stock Dropdown-Item-Toggle with a
-- tooltip per choice: hovering a line shows GameTooltip to its right, leaving it or closing
-- the list hides it. Used from the options table as `itemControl = "SSFDropdownItemTip"` on
-- a select entry; the entry's `arg` maps each value to its tooltip text. AceConfigRegistry
-- rejects unknown option keys, so the text rides in `arg`, which accepts any value.
-- The dropdown sets item.userdata.obj (itself) and item.userdata.value; AceConfigDialog puts
-- the option table in the dropdown's "option" user data.
-- Built from the stock Toggle's own constructor, re-typed so it pools under this type. The
-- hooks sit on the frame, which the pullout's SetOnEnter and AceGUI's release leave alone.

local Type, Version = "SSFDropdownItemTip", 1
local AceGUI = LibStub("AceGUI-3.0")

local function ShowTip(frame)
    local item = frame.obj
    local text = item.userdata.obj:GetUserData("option").arg[item.userdata.value]
    GameTooltip:SetOwner(frame, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("TOPLEFT", frame, "TOPRIGHT") -- level with the hovered line
    local r, g, b = HIGHLIGHT_FONT_COLOR:GetRGB() -- the game's white, not the default gold
    GameTooltip:SetText(text, r, g, b, nil, true)
    GameTooltip:Show()
end

local function HideTip(frame)
    if GameTooltip:IsOwned(frame) then GameTooltip:Hide() end
end

local function Constructor()
    local item = AceGUI.WidgetRegistry["Dropdown-Item-Toggle"]()
    item.type = Type
    item.frame:HookScript("OnEnter", ShowTip)
    item.frame:HookScript("OnLeave", HideTip)
    item.frame:HookScript("OnHide", HideTip)
    return item
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
