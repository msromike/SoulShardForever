-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- SSFFrame: SSF's options window, an extension of AceGUI's stock Frame container. The stock
-- Frame is created through AceGUI:Create and kept for the addon's life (never released, so
-- it is never handed to another addon; it may itself have been another addon's released
-- Frame, whose parent, strata, title, status text, size, position and resize switch the
-- stock OnAcquire resets); SSF's parts are added on top of it, and the result is registered
-- as this type. Nothing the stock Frame does is written again here, but one fallback (the
-- stock Close's click, copied for the case the stock button is not found): the art, the
-- title, the drag, the status table, the content frame and the container plumbing are all
-- its own. Resize is off, through the stock Frame's own switch: the
-- window is sized to its content after every feed.
--
-- What SSF adds: an X close button top-right with an optional help button left of it
-- (SetHelpButton: Blizzard's "i", gold while off, blue while on), a black shade layer under
-- the content that makes the window a little darker than the bare art (SHADE, picked by
-- eye; the note beside gets the same SHADE through AttachTo), an optional note beside
-- the window (ShowSidePanel, the SSFSideNote widget), Escape closes it, a bottom row of
-- Close (far right, SetRightButton turns it into an action), an optional action button
-- (far left, SetActionButton), an optional middle button (SetMiddleButton) and a small
-- footer line under them (SetFooter); the buttons size to their text. A dark strip behind
-- the title text (SetTitleBand) across the header art's inner opening, and the title's
-- color (SetTitleColor). The window's width fits its content (FitWidth: every text on one
-- line, see there) and so does its height (FitToContent, called by the owner after each
-- AceConfigDialog:Open: measures the ScrollFrame AceConfigDialog adds and sets the height,
-- so no scrollbar shows, up to the screen's height minus SCREEN_MARGIN; past that the
-- ScrollFrame shows its own scrollbar). After a drag it fires "OnMoved"(top, left); the
-- owner keeps that across sessions and puts it in the status table before the next open.
-- It can be dragged partly off any edge, but never lost: the top edge (the title, the drag
-- handle) stays on screen, and at least GRAB pixels stay on screen sideways and from the
-- bottom (UpdateClamp).
--
-- Public:  the stock Frame's SetTitle, SetStatusTable, Show, Hide; FitWidth() -> changed,
--          FitToContent(), SetTitleColor(r, g, b), SetTitleBand(alpha),
--          SetActionButton(text, onClick, tipText), SetMiddleButton(...),
--          SetRightButton(text, onClick, tipText), SetHelpButton(onClick, isOn, tipText),
--          ShowSidePanel(title, body, note, opts) (opts as SSFSideNote:Show),
--          SetFooter(text). Callback: "OnMoved"(top, left).
-- Hooks:   AceHook, embedded on the widget: the stock title handle's OnMouseUp (to fire
--          OnMoved after the stock handler saved the position) and the frame's OnHide (to
--          close the note with the window). Both attach in the constructor.
-- Lib internals: three reaches past the stock Frame's public surface, each guarded so a
--          changed Frame leaves the stock piece in place rather than erroring: the status
--          strip hidden through statustext's parent; the stock Close button found among
--          the frame's children by its CLOSE text, hidden, and its OnClick reused for
--          SSF's X and Close; the title handle, titletext's parent, for the hook. Also
--          read: titletext and titlebg (the band's anchors, the title's color and width),
--          localstatus (the status fallback), status (the table AceConfigDialog hands over),
--          content (re-anchored for SSF's taller bottom row); FitWidth reads the fed
--          widgets' titletext, label, text, frame.label and frame.text, and AceGUI's layout
--          fields width, children, content.width and frame.width; FitToContent reads
--          children[1].content (the ScrollFrame's scroll child). An AceGUI bump that renames
--          titletext, titlebg, content or localstatus errors at the first open (they are
--          read bare); one that renames the rest shows as a window that no longer fits its
--          content.
-- Reads:   the Tooltip module at runtime for every tooltip it shows; Colors.BLACK for the
--          title band.
-- Exceptions: the frame gets a global name (FRAME_NAME) so UISpecialFrames can close it on
--          Escape; the stock Frame is unnamed and Escape has no other way in.
-- Touches nothing else.

local Type, Version = "SSFFrame", 2
local AceGUI = LibStub("AceGUI-3.0")
local AceHook = LibStub("AceHook-3.0")

local FRAME_NAME = "SSFOptionsWindow" -- global name so UISpecialFrames (Escape) can find it
local EDGE = 17                       -- the content's, buttons' and footer's inset from the sides
local TOP_INSET = 35                  -- the content's inset from the top (the title art)
local BOTTOM_INSET = 58               -- the content's inset from the bottom: the button row and the footer
local CHROME = TOP_INSET + BOTTOM_INSET
local STOCK_BOTTOM_INSET = 57         -- what the stock Frame's OnHeightSet takes off the height it records for its content
local DEFAULT_WIDTH, DEFAULT_HEIGHT = 420, 380 -- before the first fit
local BUTTON_PAD = 30                 -- a bottom button is its text plus this
local BUTTON_MIN = 80                 -- but never narrower than this
local BUTTON_HEIGHT = 22              -- the bottom row's buttons
local ROW_OFFSET = 30                 -- the bottom row's distance from the frame's bottom edge
local FOOTER_OFFSET = 12              -- the footer line's
local SCREEN_MARGIN = 40              -- the window is never taller or wider than the screen minus this
local BUTTON_GAP = 8                  -- px kept between the two bottom buttons
local X_INSET = 5                     -- the X sits this far in from the corner
local HELP_ART = 616343               -- Interface\Common\help-i: Blizzard's own help button, a gold "i"
local HELP_SIZE = 22                  -- the help button, square: the visible "i" circle, in px
local HELP_CROP = { 14 / 64, 49 / 64 } -- the circle's edges in the 64 px art (measured); the rest is transparent
local HELP_DROP = 6                   -- px below the X's middle, so the circle clears the frame's top border
local HELP_GAP = 4                    -- px between the circle and the X
local HELP_ON = { 0.35, 0.65, 1 }     -- the "i" while help is on: blue (the art greyed, then tinted); off it is its own gold
local SIDE_GAP = 8                    -- px between the window's right edge and the side note
local TITLE_CAP = 30                  -- each end cap of the header art (the stock Frame's titlebg_l, titlebg_r)
local BAND_REACH = 16                 -- px the title strip runs into each end cap, to the art's inner opening
local BAND_PAD = 3                    -- px of strip above and below the title text
-- px added to a measured width: AceGUI's Flow layout compares widths exactly, and frame
-- sizes come back with float error (measured in game: 255.0001 for 255), so a row measured
-- to the pixel could still wrap
local ROUNDING = 1
local GRAB = 60                       -- px of the window that always stay on screen
-- The dialog background art is black with some transparency, so tinting it does nothing;
-- a plain black layer under the content, inside the border, is what makes the window
-- read darker. Its alpha was picked by eye (Mike, 2026-10-20): 0.3 is "a little darker"
-- than the bare art, enough to read over bright scenery without going flat.
local SHADE = 0.3
local SHADE_INSET = 8                 -- the border's width: the layer stays inside it

-- every tooltip this window shows goes through the Tooltip module (the one anchor)
local function Tooltip() return LibStub("AceAddon-3.0"):GetAddon("SSF"):GetModule("Tooltip") end

-- the status table AceConfigDialog handed over, or the widget's own
local function Status(self) return self.status or self.localstatus end

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

-- only the circle of the help art: the button's box is the visible "i", nothing transparent around it
local function CropHelp(texture)
    local lo, hi = HELP_CROP[1], HELP_CROP[2]
    texture:SetTexCoord(lo, hi, lo, hi)
end

-- an open tooltip on the button takes its new text at once
local function RefreshTip(button)
    if Tooltip():IsShownFor(button) then button:GetScript("OnEnter")(button) end
end

-- A bottom button's help line: the same look and place as an option's tooltip (the button's
-- name in gold, the line in white, above-right of the cursor). No line, no tooltip: the
-- owner hands one over only while help is on.
local function ButtonTip_OnEnter(button)
    if not button.tipText then return end
    Tooltip():Show(button, button:GetText(), button.tipText, true)
end

local function ButtonTip_OnLeave(button)
    Tooltip():Hide(button)
end

local function SetButtonTip(button, tipText)
    button.tipText = tipText
    if tipText then RefreshTip(button) else Tooltip():Hide(button) end
end

-- the stock Close's click (sound, then hide), or the same by hand if the stock button was
-- not found
local function Close_OnClick(button)
    PlaySound(799) -- SOUNDKIT.GS_TITLE_OPTION_EXIT
    button.obj:Hide()
end

-- SSF's methods. The ones that share a name with a stock Frame method call the stock one
-- and add to it (self.stock.* is captured in the constructor); ApplyStatus seeds its
-- defaults first, the others call the stock one first.
local methods = {
    ["OnAcquire"] = function(self)
        self.stock.OnAcquire(self)
        self:EnableResize(false) -- the stock OnAcquire turns it on; the window is sized to its content
    end,

    ["OnWidthSet"] = function(self, width)
        self.stock.OnWidthSet(self, width)
        UpdateClamp(self)
        if self.sidenote:IsShown() then self.sidenote:Layout(width) end
    end,

    -- the stock OnHeightSet records content.height as the height less STOCK_BOTTOM_INSET;
    -- SSF hands it the height less the extra its taller bottom row adds, which leaves the
    -- recorded number 35 px over the anchored content (CHROME inside). Nothing reads it:
    -- FitToContent measures the ScrollFrame's child
    ["OnHeightSet"] = function(self, height)
        self.stock.OnHeightSet(self, height - (BOTTOM_INSET - STOCK_BOTTOM_INSET))
        UpdateClamp(self)
    end,

    -- the window's own height after its layout: CHROME around the content
    ["LayoutFinished"] = function(self, _, height)
        if height then self:SetHeight(height + CHROME) end
    end,

    -- the stock defaults (700 x 500) are a status table's fallback; SSF's window starts
    -- smaller, and the first fit sets both
    ["ApplyStatus"] = function(self)
        local status = Status(self)
        status.width = status.width or DEFAULT_WIDTH
        status.height = status.height or DEFAULT_HEIGHT
        self.stock.ApplyStatus(self)
    end,

    -- Size the window to what AceConfigDialog fed in. It wraps the root group in a ScrollFrame
    -- that fills the content, so LayoutFinished above only ever echoes our own height back;
    -- the real content height is the ScrollFrame's scroll child, measured here after
    -- AceConfigDialog:Open returns (its layout runs inside Open). Saved to the status table
    -- so the next ApplyStatus starts at this size. The view then equals the content, so the
    -- ScrollFrame never shows its bar, up to the screen cap below.
    ["FitToContent"] = function(self)
        local scroll = self.children[1]
        if not (scroll and scroll.content) then return end
        local height = scroll.content:GetHeight() + CHROME
        -- never taller than the screen: past that the ScrollFrame scrolls
        height = math.min(height, UIParent:GetHeight() - SCREEN_MARGIN)
        self:SetHeight(height)
        Status(self).height = height
    end,

    -- Size the window's width to what AceConfigDialog fed in: the width at which every text
    -- shows on one line, never "..." and never wrapped, up to the screen's width minus
    -- SCREEN_MARGIN. Measured from the widgets after AceConfigDialog:Open returns, so the
    -- owner styles its titles first. Each piece sets a window width it needs:
    --   a full-width widget grows 1:1 with the window, so it needs the window wider by
    --     whatever its text lacks (MinWidth() for SSF's widgets; for stock ones, each of its
    --     title, label and text strings on one line), or allows it narrower by its slack;
    --   widgets sharing a row (not full width) need the row's total width;
    --   the window's own title, bottom buttons and footer.
    -- Saved to the status table, so the next ApplyStatus starts at this width. Returns true
    -- when the width changed: the owner feeds again, since the layout depends on the width.
    ["FitWidth"] = function(self)
        local width = self.frame:GetWidth() or 0
        local need = 0
        local function Need(n) if n > need then need = n end end
        local function Text(fs) -- a string on one line: the window width it needs
            if type(fs) == "table" and fs.GetObjectType and fs:GetObjectType() == "FontString" then
                Need(width + (fs:GetUnboundedStringWidth() or 0) - (fs:GetWidth() or 0))
            end
        end
        local function Visit(widget)
            if widget.width == "fill" then
                if widget.MinWidth then
                    Need(width + widget:MinWidth() - (widget.frame.width or widget.frame:GetWidth() or 0))
                else
                    Text(widget.titletext)
                    Text(widget.label)
                    Text(widget.text)
                    Text(widget.frame.label)
                    Text(widget.frame.text)
                end
            end
            if not widget.children then return end
            local content, run = widget.content, 0
            local avail = content and (content.width or content:GetWidth()) or 0
            for _, child in ipairs(widget.children) do
                if child.width == "fill" then
                    run = 0
                else -- shares a row with its neighbours: the row's total
                    run = run + (child.frame.width or child.frame:GetWidth() or 0)
                    Need(width + run - avail)
                end
                Visit(child)
            end
        end
        for _, child in ipairs(self.children) do Visit(child) end

        -- the title in its header art (the stock SetTitle sized the middle piece to the
        -- text), which must stay clear of the X and the help button on its right (both
        -- sides kept equal: the title is centered)
        local clear = (self.xbutton:GetWidth() or 0) + X_INSET
        if self.helpbutton:IsShown() then clear = clear + HELP_GAP + self.helpbutton:GetWidth() end
        Need((self.titlebg:GetWidth() or 0) + 2 * TITLE_CAP + 2 * clear)
        -- the bottom row: the buttons, EDGE px in from each side, and the footer under them
        local close = self.closebutton:GetWidth() or 0
        local action = self.actionbutton:IsShown() and (self.actionbutton:GetWidth() or 0) or 0
        if self.middlebutton:IsShown() then
            -- centered, so each side needs room for the wider of the two outer buttons
            Need(2 * EDGE + 2 * math.max(close, action) + 2 * BUTTON_GAP + (self.middlebutton:GetWidth() or 0))
        elseif action > 0 then
            Need(2 * EDGE + close + BUTTON_GAP + action)
        else
            Need(2 * EDGE + close)
        end
        Text(self.footer)

        local new = math.min(need + ROUNDING, UIParent:GetWidth() - SCREEN_MARGIN)
        if math.abs(new - width) < ROUNDING then return false end
        self:SetWidth(new)
        Status(self).width = new
        return true
    end,

    -- the title text's color (private widget, never pooled across addons: nothing to reset);
    -- kept for the side note's title too
    ["SetTitleColor"] = function(self, r, g, b)
        self.titletext:SetTextColor(r, g, b)
        self.titleColor = { r, g, b }
    end,

    -- a black strip behind the title text inside the header art; alpha 0 = none
    ["SetTitleBand"] = function(self, alpha)
        local black = LibStub("AceAddon-3.0"):GetAddon("SSF"):GetModule("Colors").BLACK
        self.titleband:SetColorTexture(black[1], black[2], black[3], alpha or 0)
    end,

    -- the bottom-left button, sized to its text; nil text hides it. tipText: its help line
    -- (ButtonTip), nil for none
    ["SetActionButton"] = function(self, text, onClick, tipText)
        if not text then self.actionbutton:Hide() return end
        FitButton(self.actionbutton, text)
        self.actionbutton:SetScript("OnClick", onClick)
        SetButtonTip(self.actionbutton, tipText)
        self.actionbutton:Show()
    end,

    -- the bottom-middle button, centered between the other two, sized to its text; nil text
    -- hides it. tipText: as SetActionButton
    ["SetMiddleButton"] = function(self, text, onClick, tipText)
        if not text then self.middlebutton:Hide() return end
        FitButton(self.middlebutton, text)
        self.middlebutton:SetScript("OnClick", onClick)
        SetButtonTip(self.middlebutton, tipText)
        self.middlebutton:Show()
    end,

    -- turns the bottom-right button into an action button, sized to its text; the X and
    -- Escape still close the window. tipText: as SetActionButton
    ["SetRightButton"] = function(self, text, onClick, tipText)
        FitButton(self.closebutton, text)
        self.closebutton:SetScript("OnClick", onClick)
        SetButtonTip(self.closebutton, tipText)
    end,

    -- The help button left of the X: what a click does, whether help is on (blue) or off (gold), and
    -- its own tooltip (always shown on hover). The owner calls it again after every toggle;
    -- an open tooltip takes the new text at once. Never called: the button stays hidden.
    ["SetHelpButton"] = function(self, onClick, isOn, tipText)
        local button = self.helpbutton
        button.tipText = tipText
        button:SetScript("OnClick", onClick)
        local art = button:GetNormalTexture()
        art:SetDesaturated(isOn)
        if isOn then art:SetVertexColor(unpack(HELP_ON)) else art:SetVertexColor(1, 1, 1) end
        button:Show()
        RefreshTip(button)
    end,

    -- The note beside the window (SSFSideNote:Show). Too near the screen's right edge for
    -- it, the window goes to the center of the screen; that goes in the status table, so
    -- the next ApplyStatus keeps it this session (a drag still saves the window's spot).
    ["ShowSidePanel"] = function(self, titleText, bodyText, noteText, opts)
        local width = self.sidenote:Show(titleText, bodyText, noteText, opts, self.titleColor)
        local frame = self.frame
        if (frame:GetRight() or 0) + SIDE_GAP + width > UIParent:GetRight() then
            local status = Status(self)
            status.top, status.left = nil, nil -- ApplyStatus: no spot is the center
            self:ApplyStatus()
        end
    end,

    -- the small line across the bottom, under the button row
    ["SetFooter"] = function(self, text)
        self.footer:SetText(text or "")
    end,
}

-- The stock pieces SSF replaces (see the header's Lib internals). Each returns quietly when
-- the stock Frame no longer looks the way this was written for; the stock piece then stays.
local function HideStatusBar(self)
    local bar = self.statustext and self.statustext:GetParent()
    if bar and bar ~= self.frame then bar:Hide() end
end

-- hides the stock Close and keeps its click handler for SSF's own close buttons
local function TakeStockClose(self)
    for _, child in ipairs({ self.frame:GetChildren() }) do
        if child:GetObjectType() == "Button" and child.GetText and child:GetText() == CLOSE then
            child:Hide()
            return child:GetScript("OnClick")
        end
    end
end

local function HookTitleHandle(self)
    local handle = self.titletext and self.titletext:GetParent()
    if not handle or handle == self.frame then return end
    -- after the stock handler saved the position into the status table
    self:SecureHookScript(handle, "OnMouseUp", function()
        local status = Status(self)
        self:Fire("OnMoved", status.top, status.left) -- the owner saves it across sessions
    end)
    return handle
end

local function Constructor()
    -- the stock Frame, held for life: never released, so never pooled to another addon
    local self = AceGUI:Create("Frame")
    local frame = self.frame
    self.type = Type
    self.stock = {
        OnAcquire = self.OnAcquire, OnWidthSet = self.OnWidthSet, OnHeightSet = self.OnHeightSet,
        ApplyStatus = self.ApplyStatus,
    }
    for method, func in pairs(methods) do self[method] = func end
    AceHook:Embed(self)

    frame:SetBackdropColor(1, 1, 1, 1) -- the dialog art untinted (the stock Frame tints it black)
    local shade = frame:CreateTexture(nil, "BACKGROUND", nil, 1) -- above the art, below the border
    shade:SetPoint("TOPLEFT", SHADE_INSET, -SHADE_INSET)
    shade:SetPoint("BOTTOMRIGHT", -SHADE_INSET, SHADE_INSET)
    shade:SetColorTexture(0, 0, 0, SHADE)
    frame:SetClampedToScreen(true) -- with UpdateClamp's insets: hangs off an edge, never lost
    _G[FRAME_NAME] = frame
    tinsert(UISpecialFrames, FRAME_NAME) -- Escape closes it

    HideStatusBar(self)
    local closeClick = TakeStockClose(self) or Close_OnClick
    local handle = HookTitleHandle(self) or frame

    -- SSF's content insets: clear of its bottom row and footer
    local content = self.content
    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", EDGE, -TOP_INSET)
    content:SetPoint("BOTTOMRIGHT", -EDGE, BOTTOM_INSET)

    local xbutton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    xbutton:SetPoint("TOPRIGHT", -X_INSET, -X_INSET)
    xbutton:SetScript("OnClick", closeClick)
    xbutton.obj = self

    -- the help button, left of the X; gold while help is off, blue while on (SetHelpButton)
    local helpbutton = CreateFrame("Button", nil, frame)
    helpbutton:SetSize(HELP_SIZE, HELP_SIZE)
    helpbutton:SetPoint("RIGHT", xbutton, "LEFT", -HELP_GAP, -HELP_DROP)
    helpbutton:SetNormalTexture(HELP_ART)
    helpbutton:SetHighlightTexture(HELP_ART, "ADD")
    CropHelp(helpbutton:GetNormalTexture())
    CropHelp(helpbutton:GetHighlightTexture())
    helpbutton:SetScript("OnEnter", function(button) Tooltip():Show(button, button.tipText) end)
    helpbutton:SetScript("OnLeave", function(button) Tooltip():Hide(button) end)
    helpbutton:Hide()

    -- the note beside the window, closed with the window: only when the window itself
    -- hides. OnHide also fires when the whole UI hides around a loading screen, and the
    -- window comes back from that.
    local sidenote = AceGUI:Create("SSFSideNote")
    sidenote:AttachTo(frame, SIDE_GAP, SHADE) -- the note takes the window's shade: one number
    self:SecureHookScript(frame, "OnHide", function(f)
        if f:IsShown() or not sidenote:IsShown() then return end
        sidenote:Close()
    end)

    -- bottom: a button row (action far left, Close far right), then the footer line centered
    -- along the bottom edge under it
    local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footer:SetPoint("BOTTOMLEFT", EDGE, FOOTER_OFFSET)
    footer:SetPoint("BOTTOMRIGHT", -EDGE, FOOTER_OFFSET)
    footer:SetJustifyH("CENTER")
    footer:SetWordWrap(false)

    local function RowButton(point, x)
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetPoint(point, x, ROW_OFFSET)
        button:SetHeight(BUTTON_HEIGHT)
        button:SetScript("OnEnter", ButtonTip_OnEnter)
        button:SetScript("OnLeave", ButtonTip_OnLeave)
        button.obj = self
        return button
    end
    local closebutton = RowButton("BOTTOMRIGHT", -EDGE)
    closebutton:SetScript("OnClick", closeClick)
    FitButton(closebutton, CLOSE)
    local actionbutton = RowButton("BOTTOMLEFT", EDGE)
    actionbutton:Hide()
    local middlebutton = RowButton("BOTTOM", 0)
    middlebutton:Hide()

    -- SetTitleBand's strip: on the title handle, so above the header art; BACKGROUND, so
    -- under the title text. Across the art's inner opening: BAND_REACH px into each end cap
    -- (the caps hang off the middle piece, titlebg), BAND_PAD px above and below the text.
    local titleband = handle:CreateTexture(nil, "BACKGROUND")
    titleband:SetPoint("TOP", self.titletext, "TOP", 0, BAND_PAD)
    titleband:SetPoint("BOTTOM", self.titletext, "BOTTOM", 0, -BAND_PAD)
    titleband:SetPoint("LEFT", self.titlebg, "LEFT", -BAND_REACH, 0)
    titleband:SetPoint("RIGHT", self.titlebg, "RIGHT", BAND_REACH, 0)
    titleband:SetColorTexture(0, 0, 0, 0)

    self.titleband = titleband
    self.actionbutton = actionbutton
    self.middlebutton = middlebutton
    self.closebutton = closebutton
    self.xbutton = xbutton
    self.helpbutton = helpbutton
    self.sidenote = sidenote
    self.footer = footer
    return self
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
