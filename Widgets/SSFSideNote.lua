-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- SSFSideNote: the note beside the options window's top-right corner (the first-load
-- welcome). An AceGUI widget SSFFrame creates once and attaches to its frame, out by the
-- gap it passes to AttachTo, tops level. Top to bottom: a title (the window's title color),
-- a divider, an arrow pointing left at the window's help button beside a copy of its "i", a
-- body line in gold and a divider, then the optional lead (a line, gold unless its text
-- carries its own color, with its own divider
-- under it: the two show together or not at all, so dividers never double), then the blocks
-- (paragraphs left-justified, macros each in a dark box), a small note
-- above the button, the button, and a gold note line last. Its width is SIDE_WIDTH of the
-- window's, never so narrow that the centered title runs into its X. It closes by its own X
-- or when the window closes (SSFFrame tells it), and tells its owner once either way.
--
-- Public:  AttachTo(frame, gap, look) -- the window's frame; called once by SSFFrame. look:
--            what the note copies from the window so the two panels read as one, each a
--            number the window owns: shade (its SHADE, laid as black inside the note's
--            border), helpArt and helpCrop (its help button's art and crop, for the copy
--            of the "i"), buttonHeight (its bottom buttons').
--          Show(title, body, note, opts, titleColor) -- opts, all optional: lead (the gold
--            line under the body's divider, with its own divider), blocks (a list
--            of { text } paragraphs and { text, macro = true } macros), button and onClick
--            (a button as wide as its text), buttonNote (a small line just above the
--            button: what a click does), buttonDisabled (greys the button), onClose
--            (called once when the note closes). titleColor: { r, g, b } or nil.
--          Layout(windowWidth) -> the note's width; SSFFrame calls it when the window's
--            width changes.
--          Close() -- hide and tell the owner once. IsShown() -> bool.
-- Reads:   Colors.CODE (macro text), SLATE (a macro box's edge), WHITE (the dividers) and
--          BLACK (a macro box's fill, the shade). Owns no state beyond the shown texts, the
--          onClose and its owner frame (AttachTo).
-- Touches nothing else.

local Type, Version = "SSFSideNote", 2
local AceGUI = LibStub("AceGUI-3.0")

-- SSF's colors (the addon is loaded by the time a widget is made)
local function Colors() return LibStub("AceAddon-3.0"):GetAddon("SSF"):GetModule("Colors") end

local SIDE_PAD = 14                   -- the panel's inset from its border, top and bottom; the title's and divider's sides too
local SIDE_TEXT_PAD = 24              -- the text inset from its sides
local SIDE_WIDTH = 0.86               -- the panel's width, as a share of the window's
local SIDE_ROW_GAP = 8                -- px between the title, divider, arrow row and text
local MACRO_INDENT = 16               -- a macro box's inset from the paragraphs' left edge
local MACRO_PAD = 6                   -- a macro's text inset inside its box
local MACRO_FILL = 0.6                -- alpha of the black filling a macro box
local DIVIDER = 0.25                  -- alpha of a divider's white: a rule, not a bar
local SIDE_BUTTON_EDGE = 12           -- the button's end caps: its width is its text plus this
local SIDE_ICON = 20                  -- the copy of the "i"; the arrow is as tall
local SIDE_ICON_GAP = 6               -- px between the arrow and the "i"
local ARROW_ART = 131906              -- Interface\Glues\Login\UI-BackArrow: a gold arrow pointing left
local ARROW_CROP = { 2 / 64, 1, 10 / 64, 50 / 64 } -- the arrow in its 64 px art (measured)
local ARROW_ASPECT = (ARROW_CROP[2] - ARROW_CROP[1]) / (ARROW_CROP[4] - ARROW_CROP[3]) -- the arrow's own shape
local LEVEL_ABOVE = 20                -- frame levels above the window, so the note draws over its widgets

local PANEL_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", -- the window's own background
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",       -- a tooltip-weight border
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local MACRO_BACKDROP = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeSize = 1,
}

-- a divider: a 1 px white line at DIVIDER alpha; the width is Layout's
local function Divider(layer)
    local white = Colors().WHITE
    local divider = layer:CreateTexture(nil, "OVERLAY")
    divider:SetColorTexture(white[1], white[2], white[3], DIVIDER)
    divider:SetHeight(1)
    return divider
end

-- The blocks: a paragraph is a left-justified FontString; a macro is its text in a dark
-- box, indented. Made on first use and kept for the next Show.
local function Paragraph(self, i)
    local text = self.paragraphs[i]
    if not text then
        text = self.layer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetJustifyH("LEFT")
        text:SetWordWrap(true)
        self.paragraphs[i] = text
    end
    return text
end

local function MacroBox(self, i)
    local box = self.macros[i]
    if not box then
        box = CreateFrame("Frame", nil, self.layer, "BackdropTemplate")
        local black, slate, code = Colors().BLACK, Colors().SLATE, Colors().CODE
        box:SetBackdrop(MACRO_BACKDROP)
        box:SetBackdropColor(black[1], black[2], black[3], MACRO_FILL)
        box:SetBackdropBorderColor(slate[1], slate[2], slate[3], 1)
        box.text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        box.text:SetJustifyH("LEFT")
        box.text:SetTextColor(code[1], code[2], code[3]) -- reads as text to copy
        box.text:SetPoint("TOPLEFT", MACRO_PAD, -MACRO_PAD)
        box.isMacro = true
        self.macros[i] = box
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

-- Lays out everything under the body line, top to bottom, SIDE_ROW_GAP apart, and fits the
-- height to it. Run when the text is set and again each time it shows (the welcome waits
-- for the loading screen to go, so the fonts measure true).
local function Fit(self)
    local inner = (self.frame:GetWidth() or 0) - 2 * SIDE_TEXT_PAD
    -- the anchored rows: title, divider, arrow row, body
    local y = SIDE_PAD + self.title:GetStringHeight() + SIDE_ROW_GAP + 1 + SIDE_ROW_GAP
        + SIDE_ICON + SIDE_ROW_GAP + self.body:GetStringHeight()
    local function Place(region, height, x)
        y = y + SIDE_ROW_GAP
        region:ClearAllPoints()
        if x then
            region:SetPoint("TOPLEFT", self.layer, "TOPLEFT", x, -y)
        else
            region:SetPoint("TOP", self.layer, "TOP", 0, -y) -- centered
        end
        y = y + height
    end
    Place(self.bodyDivider, 1)
    if self.lead:IsShown() then -- the lead and its divider, together
        Place(self.lead, self.lead:GetStringHeight())
        Place(self.leadDivider, 1)
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
    self.frame:SetHeight(y + SIDE_PAD)
end

local methods = {
    ["OnAcquire"] = function() end, -- created once by SSFFrame and never released

    ["AttachTo"] = function(self, frame, gap, look)
        self.owner = frame
        local black = Colors().BLACK
        self.shade:SetColorTexture(black[1], black[2], black[3], look.shade or 0)
        self.icon:SetTexture(look.helpArt)
        self.icon:SetTexCoord(look.helpCrop[1], look.helpCrop[2], look.helpCrop[1], look.helpCrop[2])
        self.button:SetHeight(look.buttonHeight)
        self.frame:SetParent(frame)
        self.frame:ClearAllPoints()
        self.frame:SetPoint("TOPLEFT", frame, "TOPRIGHT", gap, 0)
    end,

    ["Layout"] = function(self, windowWidth)
        local clearX = 2 * (self.close:GetWidth() or 0)
        local width = math.floor(math.max((windowWidth or 0) * SIDE_WIDTH,
            clearX + (self.title:GetUnboundedStringWidth() or 0)))
        self.frame:SetWidth(width)
        self.title:SetWidth(width - 2 * SIDE_PAD)
        for _, divider in ipairs({ self.divider, self.bodyDivider, self.leadDivider }) do
            divider:SetWidth(width - 2 * SIDE_PAD)
        end
        for _, text in ipairs({ self.body, self.lead, self.note, self.buttonNote }) do
            text:SetWidth(width - 2 * SIDE_TEXT_PAD)
        end
        Fit(self)
        return width
    end,

    ["Show"] = function(self, titleText, bodyText, noteText, opts, titleColor)
        opts = opts or {}
        self.title:SetText(titleText)
        if titleColor then self.title:SetTextColor(unpack(titleColor)) end
        self.body:SetText(bodyText)
        self.lead:SetText(opts.lead or "")
        self.lead:SetShown(opts.lead ~= nil)
        self.leadDivider:SetShown(opts.lead ~= nil)
        self.note:SetText(noteText or "")
        -- the blocks in order; spares left from a longer list stay hidden
        wipe(self.items)
        local p, m = 0, 0
        for _, block in ipairs(opts.blocks or {}) do
            local item
            if block.macro then
                m = m + 1
                item = MacroBox(self, m)
                item.text:SetText(block.text)
            else
                p = p + 1
                item = Paragraph(self, p)
                item:SetText(block.text)
            end
            item:Show()
            self.items[#self.items + 1] = item
        end
        for i = p + 1, #self.paragraphs do self.paragraphs[i]:Hide() end
        for i = m + 1, #self.macros do self.macros[i]:Hide() end
        if opts.button then
            -- as wide as its text plus a space each side: it reads as a button, not a bar
            local button = self.button
            button:SetText(" " .. opts.button .. " ")
            button:SetWidth((button:GetFontString():GetStringWidth() or 0) + SIDE_BUTTON_EDGE)
            button:SetScript("OnClick", opts.onClick)
            button:SetEnabled(not opts.buttonDisabled)
        end
        self.button:SetShown(opts.button ~= nil)
        self.buttonNote:SetText(opts.buttonNote or "")
        self.buttonNote:SetShown(opts.button ~= nil and opts.buttonNote ~= nil)
        self.onClose = opts.onClose
        local width = self:Layout(self.owner and self.owner:GetWidth())
        if self.owner then
            self.frame:SetFrameLevel(self.owner:GetFrameLevel() + LEVEL_ABOVE) -- above the window and its widgets
            self.layer:SetFrameLevel(self.frame:GetFrameLevel() + LEVEL_ABOVE)  -- the text above the backdrop
        end
        self.frame:Show()
        return width
    end,

    ["IsShown"] = function(self) return self.frame:IsShown() end,

    -- closes the note and tells its owner once, whatever closed it: its X, or the window
    -- closing (X, Escape, Close, or a fight)
    ["Close"] = function(self)
        self.frame:Hide()
        local onClose = self.onClose
        self.onClose = nil
        if onClose then onClose() end
    end,
}

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetBackdrop(PANEL_BACKDROP)
    frame:Hide()
    local widget = { frame = frame, type = Type, items = {}, paragraphs = {}, macros = {} }

    -- the shade: above the art, below the border, inside the border's insets (AttachTo colors it)
    local inset = PANEL_BACKDROP.insets.left
    local shade = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    shade:SetPoint("TOPLEFT", inset, -inset)
    shade:SetPoint("BOTTOMRIGHT", -inset, inset)
    widget.shade = shade

    -- everything sits on its own layer, raised above the panel when it shows
    local layer = CreateFrame("Frame", nil, frame)
    layer:SetAllPoints()
    widget.layer = layer

    local title = layer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -SIDE_PAD)
    title:SetJustifyH("CENTER")
    widget.title = title

    local divider = Divider(layer)
    divider:SetPoint("TOP", title, "BOTTOM", 0, -SIDE_ROW_GAP)
    widget.divider = divider

    -- the "i" centered on the panel (its art is the window's, set by AttachTo), the arrow
    -- left of it pointing at the real one
    local icon = layer:CreateTexture(nil, "OVERLAY")
    icon:SetSize(SIDE_ICON, SIDE_ICON)
    icon:SetPoint("TOP", divider, "BOTTOM", 0, -SIDE_ROW_GAP)
    widget.icon = icon
    local arrow = layer:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture(ARROW_ART)
    arrow:SetTexCoord(unpack(ARROW_CROP))
    arrow:SetSize(SIDE_ICON * ARROW_ASPECT, SIDE_ICON)
    arrow:SetPoint("RIGHT", icon, "LEFT", -SIDE_ICON_GAP, 0)

    -- in gold: the pointer at the help button
    local body = layer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    body:SetPoint("TOP", icon, "BOTTOM", 0, -SIDE_ROW_GAP)
    body:SetJustifyH("CENTER")
    body:SetWordWrap(true)
    widget.body = body
    widget.bodyDivider = Divider(layer) -- placed by Fit, as are the lead and its divider

    -- the optional lead in gold, and its own divider (Show shows them together)
    local lead = layer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lead:SetJustifyH("CENTER")
    lead:SetWordWrap(true)
    widget.lead = lead
    widget.leadDivider = Divider(layer)

    -- in gold so it stands out (the one-time notice), last on the panel
    local note = layer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    note:SetJustifyH("CENTER")
    note:SetWordWrap(true)
    widget.note = note

    -- the optional button, as wide as its text (Show), as tall as the window's (AttachTo)
    local button = CreateFrame("Button", nil, layer, "UIPanelButtonTemplate")
    button:Hide()
    widget.button = button

    -- the optional small line just above the button: what a click does
    local buttonNote = layer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    buttonNote:SetJustifyH("CENTER")
    buttonNote:SetWordWrap(true)
    buttonNote:Hide()
    widget.buttonNote = buttonNote

    -- its own X, the one players expect: closes the note, the window stays
    local close = CreateFrame("Button", nil, layer, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() widget:Close() end)
    widget.close = close

    frame:SetScript("OnShow", function() Fit(widget) end)

    for method, func in pairs(methods) do widget[method] = func end
    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
