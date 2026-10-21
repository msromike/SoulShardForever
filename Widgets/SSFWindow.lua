-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- SSFWindow: an AceGUI container, SSF's own options window. Adapted from AceGUI's Frame
-- container (Libs/AceGUI-3.0/widgets/AceGUIContainer-Frame.lua, Copyright (c) 2007, Ace3
-- Development Team, BSD-style license) the same way KeyCheckClear's window was.
-- Differences from Frame: an X close button top-right with an optional help button left of
-- it (SetHelpButton: Blizzard's "i", gold while off, blue while on), an optional note on its
-- right edge (ShowSidePanel), no status bar, Escape closes it,
-- and a bottom row of Close (far right, SetCloseText), an optional action button (far left,
-- SetActionButton), an optional middle button (SetMiddleButton) and a small footer line under
-- them (SetFooter). The buttons size to
-- their text. The window's width fits its content (FitWidth: every text on one line, see
-- there). Its height too: FitToContent, called by the owner after each
-- AceConfigDialog:Open, measures the ScrollFrame AceConfigDialog adds and sets the height,
-- so no scrollbar shows, up to the screen's height minus SCREEN_MARGIN. Past that the
-- window stops growing and the ScrollFrame shows its own scrollbar (a small screen or a
-- large UI scale).
-- After a drag it fires "OnMoved"(top, left); the owner keeps that across sessions and
-- puts it in the status table before the next open, which places the window there.
-- It can be dragged partly off any edge, but never lost: the top edge (the title, the drag
-- handle) stays on screen, and at least GRAB pixels of it stay on screen sideways and
-- from the bottom (UpdateClamp, clamp rect insets sized to the window).
-- AceConfigDialog feeds the options table into it: Window:Open() passes this container
-- to AceConfigDialog:Open(appName, container). Private type; nothing here is shared with
-- other addons through AceGUI's widget pool.

local Type, Version = "SSFWindow", 3
local AceGUI = LibStub("AceGUI-3.0")

local FRAME_NAME = "SSFOptionsWindow" -- global name so UISpecialFrames (Escape) can find it
local CHROME = 93                     -- the content's top (35) and bottom (58) insets
local BUTTON_PAD = 30                 -- a bottom button is its text plus this
local BUTTON_MIN = 80                 -- but never narrower than this
local SCREEN_MARGIN = 40              -- the window is never taller or wider than the screen minus this
local BUTTON_GAP = 8                  -- px kept between the two bottom buttons
local EDGE = 17                       -- the content's, buttons' and footer's inset from the sides
local HELP_ART = 616343               -- Interface\Common\help-i: Blizzard's own help button, a gold "i"
local HELP_SIZE = 22                  -- the help button, square: the visible "i" circle, in px
local HELP_CROP = { 14 / 64, 49 / 64 } -- the circle's edges in the 64 px art (measured); the rest is transparent
local HELP_DROP = 6                   -- px below the X's middle, so the circle clears the frame's top border
local HELP_GAP = 4                    -- px between the circle and the X
local SIDE_PAD = 14                   -- the side panel's inset from its border, top and bottom
local SIDE_TEXT_PAD = 24              -- the side panel's text inset from its sides
local SIDE_WIDTH = 0.86               -- the side panel's width, as a share of the window's
local SIDE_GAP = 8                    -- px between the window's right edge and the side panel
local SIDE_ROW_GAP = 8                -- px between the side panel's title, divider, arrow row and text
local MACRO_INDENT = 16               -- a macro box's inset from the paragraphs' left edge
local MACRO_PAD = 6                   -- a macro's text inset inside its box
local MACRO_TEXT = { 0.71, 0.80, 0.92 } -- a macro's text: pale blue-grey, so it reads as code to copy
local SIDE_BUTTON_EDGE = 12           -- the panel button's end caps: its width is its text plus this
local SIDE_ICON = 20                  -- the side panel's copy of the "i"; the arrow is as tall
local SIDE_ICON_GAP = 6               -- px between the arrow and the "i"
local ARROW_ART = 131906              -- Interface\Glues\Login\UI-BackArrow: a gold arrow pointing left
local ARROW_CROP = { 2 / 64, 1, 10 / 64, 50 / 64 } -- the arrow in its 64 px art (measured): 62 x 40
local HELP_ON = { 0.35, 0.65, 1 }     -- the "i" while help is on: blue (the art greyed, then tinted); off it is its own gold
-- every tooltip this window shows goes through the Tooltip module (the one anchor)
local function Tooltip() return LibStub("AceAddon-3.0"):GetAddon("SSF"):GetModule("Tooltip") end
local TITLE_CAP = 30                  -- each end cap of the header art (titlebg_l, titlebg_r)
-- px added to a measured width: AceGUI's Flow layout compares widths exactly, and frame
-- sizes come back with float error (measured in game: 255.0001 for 255), so a row measured
-- to the pixel could still wrap
local ROUNDING = 1
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
    if not button.tipHooked then
        button:HookScript("OnEnter", ButtonTip_OnEnter)
        button:HookScript("OnLeave", ButtonTip_OnLeave)
        button.tipHooked = true
    end
    if GameTooltip:IsOwned(button) then
        if tipText then ButtonTip_OnEnter(button) else Tooltip():Hide(button) end
    end
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

-- The side panel's width: SIDE_WIDTH of the window's, so its paragraphs keep a comfortable
-- line length, but never so narrow that the centered title runs into the X in the top-right
-- corner (the X's width on both sides). Its text wraps inside SIDE_TEXT_PAD. Run when the
-- panel shows and whenever the window's width changes (the first open re-fits the window a
-- frame later). Returns the width.
local function LayoutSidePanel(self)
    local panel = self.sidepanel
    local clearX = 2 * (panel.close:GetWidth() or 0)
    local width = math.floor(math.max((self.frame:GetWidth() or 0) * SIDE_WIDTH,
        clearX + (panel.title:GetUnboundedStringWidth() or 0)))
    panel:SetWidth(width)
    panel.title:SetWidth(width - 2 * SIDE_PAD)
    panel.divider:SetWidth(width - 2 * SIDE_PAD)
    for _, text in ipairs({ panel.body, panel.note, panel.buttonNote }) do
        text:SetWidth(width - 2 * SIDE_TEXT_PAD)
    end
    panel:Fit()
    return width
end

-- The side panel's blocks: a paragraph is a left-justified FontString; a macro is its text
-- in a dark box, indented. Made on first use and kept for the next ShowSidePanel.
local MACRO_BACKDROP = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeSize = 1,
}

local function Paragraph(panel, i)
    local text = panel.paragraphs[i]
    if not text then
        text = panel.textlayer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetJustifyH("LEFT")
        text:SetWordWrap(true)
        panel.paragraphs[i] = text
    end
    return text
end

local function MacroBox(panel, i)
    local box = panel.macros[i]
    if not box then
        box = CreateFrame("Frame", nil, panel.textlayer, "BackdropTemplate")
        box:SetBackdrop(MACRO_BACKDROP)
        box:SetBackdropColor(0, 0, 0, 0.6)
        box:SetBackdropBorderColor(0.3, 0.33, 0.36, 1)
        box.text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        box.text:SetJustifyH("LEFT")
        box.text:SetTextColor(unpack(MACRO_TEXT))
        box.text:SetPoint("TOPLEFT", MACRO_PAD, -MACRO_PAD)
        box.isMacro = true
        panel.macros[i] = box
    end
    return box
end

-- a macro box sized to its text: its widest line, unwrapped, and every line, plus the inset
local function SizeMacroBox(box)
    local text, widest = box.text:GetText() or "", 0
    for line in text:gmatch("[^\n]+") do
        box.text:SetText(line)
        widest = math.max(widest, box.text:GetUnboundedStringWidth() or 0)
    end
    box.text:SetText(text)
    box:SetSize(widest + 2 * MACRO_PAD, (box.text:GetStringHeight() or 0) + 2 * MACRO_PAD)
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
        if self.sidepanel:IsShown() then LayoutSidePanel(self) end
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
        -- a setting changes
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

        -- the title in its header art, which must stay clear of the X and the help button on
        -- its right (both sides kept equal: the title is centered)
        local x = self.xbutton
        local clear = (x:GetWidth() or 0) + 5 -- the X sits 5 px in from the corner
        if self.helpbutton:IsShown() then clear = clear + HELP_GAP + self.helpbutton:GetWidth() end
        clear = 2 * clear
        -- (the header's middle is the text plus 10, as SetTitle sizes it)
        Need((self.titletext:GetUnboundedStringWidth() or 0) + 10 + 2 * TITLE_CAP + clear)
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
        local status = self.status or self.localstatus
        status.width = new
        return true
    end,

    ["SetTitle"] = function(self, title)
        self.titletext:SetText(title)
        self.titlebg:SetWidth((self.titletext:GetWidth() or 0) + 10)
    end,

    -- the title text's color (private widget, never pooled across addons: nothing to reset);
    -- kept for the side panel's title too
    ["SetTitleColor"] = function(self, r, g, b)
        self.titletext:SetTextColor(r, g, b)
        self.titleColor = { r, g, b }
    end,

    -- a black strip behind the title text inside the header art; alpha 0 = none
    ["SetTitleBand"] = function(self, alpha)
        self.titleband:SetColorTexture(0, 0, 0, alpha or 0)
    end,

    ["Hide"] = function(self) self.frame:Hide() end,
    ["Show"] = function(self) self.frame:Show() end,

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

    -- the bottom-right button's text (Blizzard's CLOSE until set), sized to its text
    ["SetCloseText"] = function(self, text)
        FitButton(self.closebutton, text or CLOSE)
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
        if GameTooltip:IsOwned(button) then button:GetScript("OnEnter")(button) end
    end,

    -- A note beside the window's top-right corner, SIDE_GAP px out (the first-load welcome).
    -- Top to bottom: the title, the arrow row, bodyText (gold), opts.blocks, opts.buttonNote,
    -- the button, then noteText (gold) last. opts, all optional: blocks (a list of
    -- { text } paragraphs, left-justified, and { text, macro = true } macros, each in its own
    -- box), button and onClick (a button as wide as its text), buttonNote (a small line just
    -- above the button: what a click does, read before the click), buttonDisabled (greys the
    -- button out), onClose (called once when the note closes, by its X or the window
    -- closing). Too near the screen's right edge for it, the window goes to the center of
    -- the screen; that goes in the status table, so the next ApplyStatus keeps it this
    -- session (a drag still saves the window's spot). It closes with the window and stays
    -- closed.
    ["ShowSidePanel"] = function(self, titleText, bodyText, noteText, opts)
        opts = opts or {}
        local panel, frame = self.sidepanel, self.frame
        panel.title:SetText(titleText)
        if self.titleColor then panel.title:SetTextColor(unpack(self.titleColor)) end
        panel.body:SetText(bodyText)
        panel.note:SetText(noteText or "")
        -- the blocks in order; spares left from a longer list stay hidden
        wipe(panel.items)
        local p, m = 0, 0
        for _, block in ipairs(opts.blocks or {}) do
            local item
            if block.macro then
                m = m + 1
                item = MacroBox(panel, m)
                item.text:SetText(block.text)
            else
                p = p + 1
                item = Paragraph(panel, p)
                item:SetText(block.text)
            end
            item:Show()
            panel.items[#panel.items + 1] = item
        end
        for i = p + 1, #panel.paragraphs do panel.paragraphs[i]:Hide() end
        for i = m + 1, #panel.macros do panel.macros[i]:Hide() end
        if opts.button then
            -- as wide as its text plus a space each side: it reads as a button, not a bar
            local button = panel.button
            button:SetText(" " .. opts.button .. " ")
            button:SetWidth((button:GetFontString():GetStringWidth() or 0) + SIDE_BUTTON_EDGE)
            button:SetScript("OnClick", opts.onClick)
            button:SetEnabled(not opts.buttonDisabled)
        end
        panel.button:SetShown(opts.button ~= nil)
        panel.buttonNote:SetText(opts.buttonNote or "")
        panel.buttonNote:SetShown(opts.button ~= nil and opts.buttonNote ~= nil)
        panel.onClose = opts.onClose
        local width = LayoutSidePanel(self)
        panel:SetFrameLevel(frame:GetFrameLevel() + 20) -- above the window and its widgets
        panel.textlayer:SetFrameLevel(panel:GetFrameLevel() + 20) -- the text above the backdrop
        -- no room on the right: the window goes to the center of the screen (the window
        -- itself, the note beside it as usual)
        if (frame:GetRight() or 0) + SIDE_GAP + width > UIParent:GetRight() then
            local status = self.status or self.localstatus
            status.top, status.left = nil, nil -- ApplyStatus: no spot is the center
            self:ApplyStatus()
        end
        panel:Show()
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

    -- the help button, left of the X; gold while help is off, blue while on (SetHelpButton)
    local helpbutton = CreateFrame("Button", nil, frame)
    helpbutton:SetSize(HELP_SIZE, HELP_SIZE)
    helpbutton:SetPoint("RIGHT", xbutton, "LEFT", -HELP_GAP, -HELP_DROP)
    helpbutton:SetNormalTexture(HELP_ART)
    helpbutton:SetHighlightTexture(HELP_ART, "ADD")
    -- only the circle: the button's box is the visible "i", nothing transparent around it
    local lo, hi = HELP_CROP[1], HELP_CROP[2]
    helpbutton:GetNormalTexture():SetTexCoord(lo, hi, lo, hi)
    helpbutton:GetHighlightTexture():SetTexCoord(lo, hi, lo, hi)
    helpbutton:SetScript("OnEnter", function(button) Tooltip():Show(button, button.tipText) end)
    helpbutton:SetScript("OnLeave", function(button) Tooltip():Hide(button) end)
    helpbutton:Hide()

    -- the side panel (ShowSidePanel): the window's own background and a tooltip-weight border,
    -- SIDE_GAP px right of the window, tops level; hidden whenever the window closes
    local sidepanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    sidepanel:SetPoint("TOPLEFT", frame, "TOPRIGHT", SIDE_GAP, 0)
    sidepanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    -- top to bottom: a title (the window's title color), a divider, an arrow pointing left
    -- at the help button beside a copy of its "i", the body line in gold (all anchored,
    -- centered), then placed by Fit: the blocks (paragraphs left-justified, macros in
    -- boxes), the button's note, the button and the gold note line (centered).
    -- Everything sits on its own layer, raised above the panel when it shows.
    local layer = CreateFrame("Frame", nil, sidepanel)
    layer:SetAllPoints()
    sidepanel.textlayer = layer
    sidepanel.items, sidepanel.paragraphs, sidepanel.macros = {}, {}, {}

    local title = layer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -SIDE_PAD)
    title:SetJustifyH("CENTER")
    sidepanel.title = title

    local divider = layer:CreateTexture(nil, "OVERLAY")
    divider:SetColorTexture(1, 1, 1, 0.25)
    divider:SetHeight(1)
    divider:SetPoint("TOP", title, "BOTTOM", 0, -SIDE_ROW_GAP)
    sidepanel.divider = divider

    -- the "i" centered on the panel, the arrow left of it pointing at the real one
    local icon = layer:CreateTexture(nil, "OVERLAY")
    icon:SetTexture(HELP_ART)
    icon:SetTexCoord(HELP_CROP[1], HELP_CROP[2], HELP_CROP[1], HELP_CROP[2])
    icon:SetSize(SIDE_ICON, SIDE_ICON)
    icon:SetPoint("TOP", divider, "BOTTOM", 0, -SIDE_ROW_GAP)
    local arrow = layer:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture(ARROW_ART)
    arrow:SetTexCoord(unpack(ARROW_CROP))
    arrow:SetSize(SIDE_ICON * 62 / 40, SIDE_ICON) -- the art's own shape
    arrow:SetPoint("RIGHT", icon, "LEFT", -SIDE_ICON_GAP, 0)

    -- in gold: the pointer at the help button, and a divider between it and the text below
    local body = layer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    body:SetPoint("TOP", icon, "BOTTOM", 0, -SIDE_ROW_GAP)
    body:SetJustifyH("CENTER")
    body:SetWordWrap(true)
    sidepanel.body = body

    -- in gold so it stands out (the one-time notice), last on the panel
    local note = layer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    note:SetJustifyH("CENTER")
    note:SetWordWrap(true)
    sidepanel.note = note

    -- the optional button, as wide as its text (ShowSidePanel)
    local button = CreateFrame("Button", nil, layer, "UIPanelButtonTemplate")
    button:SetHeight(22)
    button:Hide()
    sidepanel.button = button

    -- the optional small line just above the button: what a click does
    local buttonNote = layer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    buttonNote:SetJustifyH("CENTER")
    buttonNote:SetWordWrap(true)
    buttonNote:Hide()
    sidepanel.buttonNote = buttonNote

    -- Lays out everything under the body line, top to bottom, SIDE_ROW_GAP apart, and fits
    -- the height to it. Run when the text is set and again each time it shows (the welcome
    -- waits for the loading screen to go, so the fonts measure true).
    function sidepanel:Fit()
        local inner = (self:GetWidth() or 0) - 2 * SIDE_TEXT_PAD
        -- the anchored rows: title, divider, arrow row, body
        local y = SIDE_PAD + self.title:GetStringHeight() + SIDE_ROW_GAP + 1 + SIDE_ROW_GAP
            + SIDE_ICON + SIDE_ROW_GAP + self.body:GetStringHeight()
        local function Place(region, height, x)
            y = y + SIDE_ROW_GAP
            region:ClearAllPoints()
            if x then
                region:SetPoint("TOPLEFT", self.textlayer, "TOPLEFT", x, -y)
            else
                region:SetPoint("TOP", self.textlayer, "TOP", 0, -y) -- centered
            end
            y = y + height
        end
        for _, item in ipairs(self.items) do
            if item.isMacro then
                SizeMacroBox(item)
                Place(item, item:GetHeight(), SIDE_TEXT_PAD + MACRO_INDENT)
            else
                item:SetWidth(inner)
                Place(item, item:GetStringHeight(), SIDE_TEXT_PAD)
            end
        end
        if self.buttonNote:IsShown() then Place(self.buttonNote, self.buttonNote:GetStringHeight()) end
        if self.button:IsShown() then Place(self.button, self.button:GetHeight()) end
        if (self.note:GetText() or "") ~= "" then Place(self.note, self.note:GetStringHeight()) end
        self:SetHeight(y + SIDE_PAD)
    end
    sidepanel:SetScript("OnShow", sidepanel.Fit)
    sidepanel:Hide()

    -- closes the note and tells its owner once (ShowSidePanel's opts.onClose), whatever
    -- closed it: its X, or the window closing (X, Escape, Close, or a fight)
    local function CloseSidePanel()
        sidepanel:Hide()
        local onClose = sidepanel.onClose
        sidepanel.onClose = nil
        if onClose then onClose() end
    end
    -- its own X, the one players expect: closes the note, the window stays
    local sideclose = CreateFrame("Button", nil, layer, "UIPanelCloseButton")
    sideclose:SetPoint("TOPRIGHT", 0, 0)
    sideclose:SetScript("OnClick", CloseSidePanel)
    sidepanel.close = sideclose
    -- closed with the window too: only when the window itself hides. OnHide also fires when
    -- the whole UI hides around a loading screen, and the window comes back from that.
    frame:HookScript("OnHide", function(f)
        if f:IsShown() or not sidepanel:IsShown() then return end
        CloseSidePanel()
    end)

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

    local middlebutton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    middlebutton:SetPoint("BOTTOM", 0, 30)
    middlebutton:SetHeight(22)
    middlebutton:Hide()

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
        middlebutton = middlebutton,
        closebutton  = closebutton,
        xbutton      = xbutton,
        helpbutton   = helpbutton,
        sidepanel    = sidepanel,
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
