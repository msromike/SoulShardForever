-- Soul Shard Forever (SSF). MIT, see LICENSE.
--
-- SSFWindow: an AceGUI container, SSF's own options window. Adapted from AceGUI's Frame
-- container (Libs/AceGUI-3.0/widgets/AceGUIContainer-Frame.lua, Copyright (c) 2007, Ace3
-- Development Team, BSD-style license) the same way KeyCheckClear's window was.
-- Differences from Frame: an X close button top-right, no status bar, a centered Close
-- button, Escape closes it, and the window is exactly as tall as its content.
-- AceConfigDialog feeds the options table into it: Options:Open() passes this container
-- to AceConfigDialog:Open(appName, container). Private type; nothing here is shared with
-- other addons through AceGUI's widget pool.

local Type, Version = "SSFWindow", 1
local AceGUI = LibStub("AceGUI-3.0")

local FRAME_NAME = "SSFOptionsWindow" -- global name so UISpecialFrames (Escape) can find it

local function Close_OnClick(frame)
    PlaySound(799) -- SOUNDKIT.GS_TITLE_OPTION_EXIT
    frame.obj:Hide()
end

local function Frame_OnShow(frame) frame.obj:Fire("OnShow") end
local function Frame_OnClose(frame) frame.obj:Fire("OnClose") end
local function Frame_OnMouseDown() AceGUI:ClearFocus() end

local function Title_OnMouseDown(frame)
    frame:GetParent():StartMoving()
    AceGUI:ClearFocus()
end

local function Mover_OnMouseUp(mover)
    local frame = mover:GetParent()
    frame:StopMovingOrSizing()
    local self = frame.obj
    local status = self.status or self.localstatus
    status.width = frame:GetWidth()
    status.height = frame:GetHeight()
    status.top = frame:GetTop()
    status.left = frame:GetLeft()
end

local methods = {
    ["OnAcquire"] = function(self)
        self.frame:SetParent(UIParent)
        self.frame:SetFrameStrata("FULLSCREEN_DIALOG")
        self.frame:SetFrameLevel(100)
        self:SetTitle()
        self:ApplyStatus()
        self:Show()
    end,

    ["OnRelease"] = function(self)
        self.status = nil
        wipe(self.localstatus)
    end,

    ["OnWidthSet"] = function(self, width)
        local content = self.content
        local contentwidth = width - 34
        if contentwidth < 0 then contentwidth = 0 end
        content:SetWidth(contentwidth)
        content.width = contentwidth
    end,

    ["OnHeightSet"] = function(self, height)
        local content = self.content
        local contentheight = height - 79
        if contentheight < 0 then contentheight = 0 end
        content:SetHeight(contentheight)
        content.height = contentheight
    end,

    -- the window is exactly as tall as its content: 79 = the content's top and bottom insets
    ["LayoutFinished"] = function(self, _, height)
        if height then self:SetHeight(height + 79) end
    end,

    ["SetTitle"] = function(self, title)
        self.titletext:SetText(title)
        self.titlebg:SetWidth((self.titletext:GetWidth() or 0) + 10)
    end,

    ["Hide"] = function(self) self.frame:Hide() end,
    ["Show"] = function(self) self.frame:Show() end,

    ["SetStatusTable"] = function(self, status)
        assert(type(status) == "table")
        self.status = status
        self:ApplyStatus()
    end,

    ["ApplyStatus"] = function(self)
        local status = self.status or self.localstatus
        local frame = self.frame
        self:SetWidth(status.width or 420)
        self:SetHeight(status.height or 380)
        frame:ClearAllPoints()
        if status.top and status.left then
            frame:SetPoint("TOP", UIParent, "BOTTOM", 0, status.top)
            frame:SetPoint("LEFT", UIParent, "LEFT", status.left, 0)
        else
            frame:SetPoint("CENTER")
        end
    end,
}

local FrameBackdrop = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
}

local function Constructor()
    local frame = CreateFrame("Frame", FRAME_NAME, UIParent, "BackdropTemplate")
    frame:Hide()
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(100)
    frame:SetBackdrop(FrameBackdrop)
    frame:SetToplevel(true)
    frame:SetScript("OnShow", Frame_OnShow)
    frame:SetScript("OnHide", Frame_OnClose)
    frame:SetScript("OnMouseDown", Frame_OnMouseDown)
    tinsert(UISpecialFrames, FRAME_NAME) -- Escape closes it

    local xbutton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    xbutton:SetPoint("TOPRIGHT", -5, -5)
    xbutton:SetScript("OnClick", Close_OnClick)

    local closebutton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closebutton:SetScript("OnClick", Close_OnClick)
    closebutton:SetPoint("BOTTOM", 0, 17)
    closebutton:SetHeight(22)
    closebutton:SetWidth(100)
    closebutton:SetText(CLOSE)

    local titlebg = frame:CreateTexture(nil, "OVERLAY")
    titlebg:SetTexture(131080) -- Interface\\DialogFrame\\UI-DialogBox-Header
    titlebg:SetTexCoord(0.31, 0.67, 0, 0.63)
    titlebg:SetPoint("TOP", 0, 12)
    titlebg:SetWidth(100)
    titlebg:SetHeight(40)

    local title = CreateFrame("Frame", nil, frame)
    title:EnableMouse(true)
    title:SetScript("OnMouseDown", Title_OnMouseDown)
    title:SetScript("OnMouseUp", Mover_OnMouseUp)
    title:SetAllPoints(titlebg)

    local titletext = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titletext:SetPoint("TOP", titlebg, "TOP", 0, -14)

    local titlebg_l = frame:CreateTexture(nil, "OVERLAY")
    titlebg_l:SetTexture(131080)
    titlebg_l:SetTexCoord(0.21, 0.31, 0, 0.63)
    titlebg_l:SetPoint("RIGHT", titlebg, "LEFT")
    titlebg_l:SetWidth(30)
    titlebg_l:SetHeight(40)

    local titlebg_r = frame:CreateTexture(nil, "OVERLAY")
    titlebg_r:SetTexture(131080)
    titlebg_r:SetTexCoord(0.67, 0.77, 0, 0.63)
    titlebg_r:SetPoint("LEFT", titlebg, "RIGHT")
    titlebg_r:SetWidth(30)
    titlebg_r:SetHeight(40)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 17, -35)
    content:SetPoint("BOTTOMRIGHT", -17, 44)

    local widget = {
        localstatus = {},
        titletext   = titletext,
        titlebg     = titlebg,
        content     = content,
        frame       = frame,
        type        = Type,
    }
    for method, func in pairs(methods) do
        widget[method] = func
    end
    xbutton.obj, closebutton.obj = widget, widget

    return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
