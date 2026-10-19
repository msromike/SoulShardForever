-- Soul Shard Forever (SSF). MIT, see LICENSE.
--
-- Window: SSF's own options window. Opens it, feeds it the options table, keeps it fresh
-- while shown, dresses its buttons and footer, styles its titles. The table itself is
-- Options'; this module reaches it only through AceConfigDialog / AceConfigRegistry by the
-- app name "SSF".
--
-- Layout: status line, then inline groups (Pause, Cap, Low shard glow, Bag count) and
-- Other, then a small version/credit line. Every toggle is full width, and a label that does
-- not fit wraps and grows its row (Widgets\SSFCentered.lua). The window sizes itself to the
-- content after every feed, width then height (Feed -> SSFWindow:FitWidth, FitToContent), so
-- no text is cut short and it never scrolls. No default size: the first feed lays out at
-- AceConfigDialog's own default and the fit sets both.
--
-- Public:  Open() (open only, never a toggle: /ssf, /ssf options, /ssf settings),
--          Toggle() (the minimap icon and broker click), Refresh().
-- Listens: SSF_OPTIONS_REBUILT (Options rebuilt the table: re-dress and refresh),
--          SSF_OPTIONS_CHANGED (redraw after a chat change), SSF_SHARD_DELETED and a
--          bucketed BAG_UPDATE (refresh the status line).
-- Saves:   the window position, profile.window (top, left and the screen size it was
--          saved on).

local ADDON = "SoulShardForever"
local APP = "SSF" -- the AceConfig app Options registers
local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Window = SSF:NewModule("Window", "AceEvent-3.0", "AceBucket-3.0", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

-- The window title and the group titles are in the warlock class color: nothing else in
-- the window uses it (gold is for control labels, white for option text, green and red
-- for state).
local function ClassColor()
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS.WARLOCK
    if c then return c.r, c.g, c.b end
    return 0.53, 0.53, 0.93
end

-- A faint dark strip behind every title (each group title, and the window title in its
-- header), so the class color reads on any scenery behind the window. One darkness for all.
local TITLE_BAND = 0.45 -- alpha of the black strip

-- the group strip's shape: the same art and insets as AceGUI's InlineGroup box (its
-- PaneBackdrop), so the strip has the box's width and rounded corners; both its fill and
-- its edge are the strip's black, so no frame line shows
local BAND_BACKDROP = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 3, right = 3, top = 5, bottom = 3 },
}

-- Blizzard's Key Bindings page, scrolled to SSF's section and opened expanded. There is no
-- function to expand a section, so the section's own flag (initializer.data.expanded) is
-- set first; tested in game, and a key bound there afterwards stuck through a reload with
-- nothing blocked. The section name is Bindings.xml's category. SSF's window closes first:
-- it draws above the settings panel.
local BINDING_SECTION = "Soul Shard Forever"

function Window:OpenKeyBindings()
    if self.window then self.window:Hide() end
    local id = Settings.KEYBINDINGS_CATEGORY_ID
    local category = id and Settings.GetCategory(id)
    local layout = category and SettingsPanel:GetLayout(category)
    for _, initializer in ipairs(layout and layout:GetInitializers() or {}) do
        if initializer.data and initializer.data.name == BINDING_SECTION then
            initializer.data.expanded = true
        end
    end
    Settings.OpenToCategory(id, BINDING_SECTION)
end

-- The window's own strings, outside the options table: the two bottom buttons and the footer.
-- Bottom right is Blizzard's own "Key Bindings" label (SETTINGS_KEYBINDINGS_LABEL, the key
-- binding page's own title, translated by the game); the X and Escape close the window.
function Window:DressWindow()
    self.window:SetActionButton(L["Delete Shard"], function() SSF:GetModule("Trimmer"):Delete() end)
    local label = SETTINGS_KEYBINDINGS_LABEL or KEY_BINDINGS or "Key Bindings"
    self.window:SetRightButton(label, function() Window:OpenKeyBindings() end)
    self.window:SetTitleColor(ClassColor()) -- "Soul Shard Forever" at the top, as the group titles
    self.window:SetTitleBand(TITLE_BAND)    -- the same dark strip behind it
    local version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
    self.window:SetFooter("v" .. version .. "  " .. L["Started as a fork of SoulSort by Anilusion."])
end

-- Group titles one font size up in SSF's own window, so the sections stand apart. The boxes
-- are AceGUI's stock InlineGroup, which AceConfigDialog builds and which every addon shares
-- through one pool. So each one gets its stock title font back (GameFontNormal, as the
-- widget creates it) through its OnRelease callback, which AceGUI fires as it takes the
-- box back; no other addon ever receives a restyled box. Blizzard's Interface Options
-- panel for SSF is not touched.
-- the strip SSF added to a shared box, keyed by the box's frame; reused if Ace hands SSF
-- the same box again, hidden whenever Ace takes it back
local bands = setmetatable({}, { __mode = "k" })

local function RestoreTitle(group)
    group.titletext:SetFontObject(GameFontNormal)
    group.titletext:SetTextColor(GameFontNormal:GetTextColor())
    local band = bands[group.frame]
    if band then band:Hide() end
end

-- across the title row, the same left and right edges as the box below it (Ace anchors the
-- box at 0 and -1)
local function NewBand(group)
    local band = CreateFrame("Frame", nil, group.frame, "BackdropTemplate")
    band:SetPoint("TOPLEFT", group.frame, "TOPLEFT", 0, 1)
    band:SetPoint("TOPRIGHT", group.frame, "TOPRIGHT", -1, 1)
    band:SetHeight(20)
    band:SetBackdrop(BAND_BACKDROP)
    bands[group.frame] = band
    return band
end

local function StyleTitle(group)
    group.titletext:SetFontObject(GameFontNormalLarge)
    group.titletext:SetTextColor(ClassColor())
    local band = bands[group.frame] or NewBand(group)
    -- one level under the group's own frame, so the title (a region of that frame) draws on
    -- top of the strip
    band:SetFrameLevel(math.max(0, group.frame:GetFrameLevel() - 1))
    band:SetBackdropColor(0, 0, 0, TITLE_BAND)
    band:SetBackdropBorderColor(0, 0, 0, TITLE_BAND)
    band:Show()
    group:SetCallback("OnRelease", RestoreTitle)
end

local function StyleGroupTitles(container)
    for _, child in ipairs(container.children) do
        if child.type == "InlineGroup" and child.titletext then StyleTitle(child) end
    end
end

-- AceConfigDialog rebuilds the window by itself after any setting change, through its own
-- Open(APP, window), without going through Feed (tested: the titles came back stock gold
-- after a click). A hook on Open styles the titles as soon as any Open of the window
-- returns, Feed's included, in the same frame, so the stock titles never draw. Re-hooked
-- when Open has been replaced: a newer AceConfigDialog loaded by another addon redefines it.
-- The container can be nil: Ace calls Open(APP) with none after a change made in Blizzard's
-- Interface Options panel, before our window may exist (nil == nil).
local function AfterDialogOpen(_, app, container)
    if app ~= APP or not container or container ~= Window.window then return end
    StyleGroupTitles(container.children[1]) -- the ScrollFrame AceConfigDialog puts in
end

local hookedOpen
local function HookDialogOpen()
    if AceConfigDialog.Open == hookedOpen then return end
    hooksecurefunc(AceConfigDialog, "Open", AfterDialogOpen)
    hookedOpen = AceConfigDialog.Open
end

-- Feed the table into the window, then size the window to it: the width first (every text
-- on one line, SSFWindow:FitWidth; the layout depends on the width, so a changed width is
-- fed again), then the height (SSFWindow:FitToContent).
function Window:Feed()
    HookDialogOpen()
    AceConfigDialog:Open(APP, self.window)
    if self.window:FitWidth() then AceConfigDialog:Open(APP, self.window) end
    self.window:FitToContent()
end

-- Keep the status line and the AutoMax state fresh while a window is open.
-- NOT on SSF_CAP_CHANGED: AceConfigDialog calls the slider's set on every drag tick, and a
-- rebuild from inside that loop recreates the slider under the mouse. AceConfig already
-- refreshes after a release or a button click; the bag bucket covers everything else.
-- NotifyChange covers the Interface Options panel; the standalone window is our own
-- container, which AceConfigDialog does not track, so it is re-fed here while shown.
function Window:Refresh()
    AceConfigRegistry:NotifyChange(APP)
    if self.window and self.window.frame:IsShown() then
        self:Feed()
    end
end

-- A chat command changed a setting: redraw so an open window shows it. Only for "chat":
-- a GUI change sends the same message on every slider drag tick (see Refresh).
function Window:OnOptionsChanged(_, _, source)
    if source == "chat" then self:Refresh() end
end

-- Options built and re-registered the table (a Language change): the window's own strings
-- are reset too, then everything is redrawn.
function Window:OnOptionsRebuilt()
    if self.window then self:DressWindow() end
    self:Refresh()
end

-- The small standalone window: minimap click, /ssf, /ssf options, /ssf settings. Our own
-- SSFWindow container (X button, no status bar, sized to content), created once and
-- re-fed on every open.
-- The minimap icon and broker click: close the window if it is showing, else open it.
function Window:Toggle()
    if self.window and self.window.frame:IsShown() then
        self.window:Hide()
    else
        self:Open()
    end
end

function Window:Open()
    -- the saved position goes into AceConfigDialog's status table, which Feed hands to the
    -- window; a drag saves it back (OnMoved below)
    local saved, status = SSF.db.profile.window, AceConfigDialog:GetStatusTable(APP)
    if saved.top and saved.left then
        -- The spot is in UI units, which change meaning with the UI scale or the
        -- resolution, and the clamp only acts on a drag. So the spot is used only on the
        -- same screen size it was saved on; otherwise the window opens centered and the
        -- next drag saves a new spot.
        local w, h = UIParent:GetWidth(), UIParent:GetHeight()
        if saved.width and saved.height
           and math.abs(saved.width - w) < 1 and math.abs(saved.height - h) < 1 then
            status.top, status.left = saved.top, saved.left
        else
            status.top, status.left = nil, nil
        end
    else
        status.top, status.left = nil, nil -- never dragged: centered
    end
    if not self.window then
        self.window = LibStub("AceGUI-3.0"):Create("SSFWindow")
        self.window:SetCallback("OnMoved", function(_, _, top, left)
            local window = SSF.db.profile.window
            window.top, window.left = top, left
            -- the screen size the spot belongs to (see Open)
            window.width, window.height = UIParent:GetWidth(), UIParent:GetHeight()
        end)
        -- bottom row: Delete Shard far left, version and credit in the middle, Close far right
        self:DressWindow()
        -- The first open of a session measures before every text size is settled (the
        -- window has not been drawn yet), which leaves a gap above the buttons. Feed again
        -- one frame later, after the first draw, so the fit is measured on settled sizes.
        self:ScheduleTimer("Feed", 0)
    end
    self:Feed()
end

-- Setup lives in OnEnable, not OnInitialize: Core's warlock gate switches modules off
-- before OnEnable, so other classes never get the window.
function Window:OnEnable()
    SSF.db.profile.window.open = nil -- left over from a dropped reopen-after-reload try

    self:RegisterMessage("SSF_OPTIONS_REBUILT", "OnOptionsRebuilt")
    self:RegisterMessage("SSF_SHARD_DELETED", "Refresh")
    self:RegisterMessage("SSF_OPTIONS_CHANGED", "OnOptionsChanged")
    self:RegisterBucketEvent({ "BAG_UPDATE", "BAG_CONTAINER_UPDATE" }, 0.5, "Refresh")
end
