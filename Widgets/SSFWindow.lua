-- Soul Shard Forever (SSF). MIT, see LICENSE.
--
-- SSFWindow: an AceGUI container, SSF's own options window. Adapted from AceGUI's Frame
-- container (Libs/AceGUI-3.0/widgets/AceGUIContainer-Frame.lua, Copyright (c) 2007, Ace3
-- Development Team, BSD-style license) the same way KeyCheckClear's window was.
-- Differences from Frame: an X close button top-right, no status bar, Escape closes it,
-- and a bottom row of Close (far right, SetCloseText), an optional action button (far left,
-- SetActionButton) and a small footer line between them (SetFooter). Both buttons size to
-- their text. The window sizes to its content: FitToContent, called by the owner after each
-- AceConfigDialog:Open, measures the ScrollFrame AceConfigDialog adds and sets the height,
-- so no scrollbar shows, up to the screen's height minus SCREEN_MARGIN. Past that the
-- window stops growing and the ScrollFrame shows its own scrollbar (a small screen or a
-- large UI scale).
-- After a drag it fires "OnMoved"(top, left); the owner keeps that across sessions and
-- puts it in the status table before the next open, which places the window there.
-- It can be dragged partly off any edge, but never lost: the top edge (the title, the drag
-- handle) stays on screen, and at least GRAB pixels of it stay on screen sideways and
-- from the bottom (UpdateClamp, clamp rect insets sized to the window).
-- AceConfigDialog feeds the options table into it: Options:Open() passes this container
-- to AceConfigDialog:Open(appName, container). Private type; nothing here is shared with
-- other addons through AceGUI's widget pool.

local Type, Version = "SSFWindow", 2
local AceGUI = LibStub("AceGUI-3.0")

local FRAME_NAME = "SSFOptionsWindow" -- global name so UISpecialFrames (Escape) can find it
local CHROME = 93                     -- the content's top (35) and bottom (58) insets
local BUTTON_PAD = 30                 -- a bottom button is its text plus this
local BUTTON_MIN = 80                 -- but never narrower than this
local SCREEN_MARGIN = 40              -- the window is never taller than the screen minus this
local GRAB = 60                       -- px of the window that always stay on screen

-- The frame may hang off the left, right and bottom edges, but keeps GRAB px on screen;
-- the top edge stays on screen, so the title bar can always be grabbed. Clamp rect insets
-- shrink the area the game keeps on screen: positive left/bottom and negative right move
-- those edges inward. Called whenever the size changes.
local function UpdateClamp(self)
    local frame = self.frame
    local w, h = frame:GetWidth() or 0, frame:GetHeight() or 0
    local x = math.max(0, w - GRAB)
    local y = math.max(0, h - GRAB)
    frame:SetClampRectInsets(x, -x, 0, y)
end

local function FitButton(button, text)
    button:SetText(text)
    button:SetWidth(math.max(BUTTON_MIN, (button:GetFontString():GetStringWidth() or 0) + BUTTON_PAD))
end

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
    self:Fire("OnMoved", status.top, status.left) -- the owner saves it across sessions
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
        UpdateClamp(self)
    end,

    ["OnHeightSet"] = function(self, height)
        local content = self.content
        local contentheight = height - CHROME
        if contentheight < 0 then contentheight = 0 end
        content:SetHeight(contentheight)
        content.height = contentheight
        UpdateClamp(self)
    end,

    ["LayoutFinished"] = function(self, _, height)
        if height then self:SetHeight(height + CHROME) end
        -- every rebuild ends here, including the ones AceConfigDialog does by itself after
        -- a setting changes; the owner restyles on it
        self:Fire("OnLayoutFinished")
    end,

    -- Size the window to what AceConfigDialog fed in. It wraps the root group in a ScrollFrame
    -- that fills the content, so LayoutFinished above only ever echoes our own height back;
    -- the real content height is the ScrollFrame's scroll child, measured here after
    -- AceConfigDialog:Open returns (its layout runs inside Open). Saved to the status table
    -- so the next ApplyStatus starts at this size. The view then always equals the content,
    -- so the ScrollFrame never shows its bar.
    ["FitToContent"] = function(self)
        local scroll = self.children[1]
        if not (scroll and scroll.content) then return end
        local height = scroll.content:GetHeight() + CHROME
        -- never taller than the screen: past that the ScrollFrame scrolls
        height = math.min(height, UIParent:GetHeight() - SCREEN_MARGIN)
        self:SetHeight(height)
        local status = self.status or self.localstatus
        status.height = height
    end,

    ["SetTitle"] = function(self, title)
        self.titletext:SetText(title)
        self.titlebg:SetWidth((self.titletext:GetWidth() or 0) + 10)
    end,

    -- the title text's color (private widget, never pooled across addons: nothing to reset)
    ["SetTitleColor"] = function(self, r, g, b)
        self.titletext:SetTextColor(r, g, b)
    end,

    -- a black strip behind the title text inside the header art; alpha 0 = none
    ["SetTitleBand"] = function(self, alpha)
        self.titleband:SetColorTexture(0, 0, 0, alpha or 0)
    end,

    ["Hide"] = function(self) self.frame:Hide() end,
    ["Show"] = function(self) self.frame:Show() end,

    -- the bottom-left button, sized to its text; nil text hides it
    ["SetActionButton"] = function(self, text, onClick)
        if not text then self.actionbutton:Hide() return end
        FitButton(self.actionbutton, text)
        self.actionbutton:SetScript("OnClick", onClick)
        self.actionbutton:Show()
    end,

    -- the bottom-right button's text (Blizzard's CLOSE until set), sized to its text
    ["SetCloseText"] = function(self, text)
        FitButton(self.closebutton, text or CLOSE)
    end,

    -- turns the bottom-right button into an action button, sized to its text; the X and
    -- Escape still close the window
    ["SetRightButton"] = function(self, text, onClick)
        FitButton(self.closebutton, text)
        self.closebutton:SetScript("OnClick", onClick)
    end,

    -- the small line between the two bottom buttons
    ["SetFooter"] = function(self, text)
        self.footer:SetText(text or "")
    end,

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
    frame:SetClampedToScreen(true) -- with UpdateClamp's insets: hangs off an edge, never lost
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

    -- bottom: a button row (action far left, Close far right), then the footer line centered
    -- along the bottom edge under it
    local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footer:SetPoint("BOTTOMLEFT", 17, 12)
    footer:SetPoint("BOTTOMRIGHT", -17, 12)
    footer:SetJustifyH("CENTER")
    footer:SetWordWrap(false)

    local closebutton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closebutton:SetScript("OnClick", Close_OnClick)
    closebutton:SetPoint("BOTTOMRIGHT", -17, 30)
    closebutton:SetHeight(22)
    FitButton(closebutton, CLOSE)

    local actionbutton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    actionbutton:SetPoint("BOTTOMLEFT", 17, 30)
    actionbutton:SetHeight(22)
    actionbutton:Hide()

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

    -- SetTitleBand's strip: on the title frame, so above the header art; BACKGROUND, so
    -- under the title text; a few px around the text
    local titleband = title:CreateTexture(nil, "BACKGROUND")
    titleband:SetPoint("TOPLEFT", titletext, "TOPLEFT", -8, 3)
    titleband:SetPoint("BOTTOMRIGHT", titletext, "BOTTOMRIGHT", 8, -3)
    titleband:SetColorTexture(0, 0, 0, 0)

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
    content:SetPoint("BOTTOMRIGHT", -17, 58) -- clear of the button row and the footer

    local widget = {
        localstatus  = {},
        titletext    = titletext,
        titleband    = titleband,
        titlebg      = titlebg,
        content      = content,
        actionbutton = actionbutton,
        closebutton  = closebutton,
        footer       = footer,
        frame        = frame,
        type         = Type,
    }
    for method, func in pairs(methods) do
        widget[method] = func
    end
    xbutton.obj, closebutton.obj = widget, widget

    return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
