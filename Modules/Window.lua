-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Window: SSF's own options window. Opens it, feeds it the options table, keeps it fresh
-- while shown, dresses its buttons and footer, styles its titles. The table itself is
-- Options'; this module reaches it only through AceConfigDialog / AceConfigRegistry by the
-- app name "SSF". Tooltips are the Tooltip module's: the window hands it its frame.
--
-- Layout: the count with Delete Shard beside it, then inline groups (Pause, Cap, Low shard
-- warning, Bag count) and Other, then a small version/credit line. Toggles are full width
-- except Play pause sound, which shares its row with the volume dropdown; a label that
-- does not fit (the window is capped at the screen's width) wraps and grows its row
-- (Widgets\SSFCentered.lua). The window sizes itself to the content after every feed,
-- width then height (Feed -> SSFFrame:FitWidth, FitToContent), so no text is cut short and
-- it never scrolls short of the screen's height. No default size: the first
-- feed lays out at AceConfigDialog's own default and the fit sets both.
--
-- Public:  Open() (open only, never a toggle: /ssf, /ssf options, /ssf settings; does
--          nothing in a fight, see InFight), Toggle() (the minimap icon and broker click),
--          Refresh(), Feed() (also by name through a timer), DressWindow(),
--          ShowNote(title, body, note, opts) (open with a note beside it: Welcome's; opts
--          as SSFSideNote:Show), InFight() (the one combat test the window and the
--          welcome share), OpenKeyBindings() (the bottom-right button).
-- Listens: SSF_OPTIONS_REBUILT (Options rebuilt the table: re-dress and refresh),
--          SSF_MACROS_CHANGED (re-dress: "Create macros" shows or hides),
--          SSF_OPTIONS_CHANGED (redraw after a chat change), SSF_SHARD_DELETED,
--          SSF_BAGS_CHANGED and SSF_QUIET_ENDED (refresh the count row), PLAYER_REGEN_DISABLED (a fight
--          starts: the window closes, and nothing opens it until the fight is over; it
--          does not reopen by itself).
-- Hooks:   AceConfigDialog.Open (AceHook), to style the group titles after every rebuild;
--          attached at the first Feed, and again if a newer AceConfigDialog loaded later
--          replaced Open.
-- Sends:   SSF_SHOW_WELCOME ("Create macros" clicked, out of a fight), SSF_WINDOW_OPENED
--          (after every open).
-- Lib internals: the InlineGroup widgets AceConfigDialog builds (their type, titletext
--          and frame, for the title style and strip), the window's first child, the
--          ScrollFrame AceConfigDialog adds (children[1]) and its children list, and the
--          window widget's frame (for IsShown and Tooltip:Attach), and the top and left
--          keys of AceConfigDialog's status table (AceGUI Frame's position fields, written
--          before an open). BAND_BACKDROP is a copy
--          of the InlineGroup's own PaneBackdrop, which AceGUI keeps local. An AceGUI bump
--          that changes those shows up as stock gold titles with no strip, or a strip of
--          a different shape.
-- Reads:   Macros:AnyMissing() for the "Create macros" button, Options.APP and
--          Options:IsHelpOn/ToggleHelp, KeyBindings:Open, Colors:Class/Gold and
--          Colors.BLACK, Tooltip:Attach, SSF.VERSION, the BINDING_NAME_* labels KeyBindings
--          sets; profile.window (the saved spot, at Open).
-- Saves:   the window position, profile.window (top, left and the screen size it was
--          saved on).
-- Exceptions: the title strip behind each group title is a raw frame: AceConfigDialog
--          hardcodes the InlineGroup widget, so there is no Ace way to add one. One of the
--          three raw frames in SSF (DeleteButton's named button and Counter's FontString
--          are the others).
-- Touches nothing else.

local ADDON = ...
local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Window = SSF:NewModule("Window", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local APP = SSF:GetModule("Options").APP -- the AceConfig app Options registers

-- the window exists and is on screen
local function IsShown(self) return self.window ~= nil and self.window.frame:IsShown() end

-- The window title and the group titles are in the warlock class color: nothing else in
-- the window uses it (gold is for control labels, white for option text, green and red
-- for state).
local function ClassColor() return SSF:GetModule("Colors"):Class() end
local function Gold(text) return SSF:GetModule("Colors"):Gold(text) end

-- In a fight: the combat lockdown, or already flagged in combat (PLAYER_REGEN_DISABLED fires
-- as the fight starts, before the lockdown itself is on). Welcome asks this too.
function Window:InFight() return InCombatLockdown() or UnitAffectingCombat("player") end

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

-- Blizzard's Key Bindings page on SSF's section (KeyBindings). SSF's window closes first:
-- it draws above the settings panel.
function Window:OpenKeyBindings()
    if self.window then self.window:Hide() end
    SSF:GetModule("KeyBindings"):Open()
end

-- The window's own strings, outside the options table: the two bottom buttons and the footer.
-- Bottom right is the Keybindings button; the X and Escape close the window. Each bottom
-- button gets its help line only while help is on, like every option.
function Window:DressWindow()
    local Options = SSF:GetModule("Options")
    local on = Options:IsHelpOn()

    -- Delete Shard sits beside the count at the top (Options' deletebutton); the middle
    -- slot stays empty
    self.window:SetMiddleButton(nil)

    -- "Create macros" far left, while either macro is missing, across from Key Bindings: it
    -- opens the welcome note (Welcome listens), whose button makes them. Never calls
    -- Welcome, so nothing loops.
    local createText = SSF:GetModule("Macros"):AnyMissing() and L["Create macros"] or nil
    self.window:SetActionButton(createText, function()
        if not Window:InFight() then Window:SendMessage("SSF_SHOW_WELCOME") end
    end, on and L["Opens the welcome screen to create the recommended macros."] or nil)

    -- SSF's own label, so it follows the Language setting like everything else in the
    -- window (Blizzard's words begin on Blizzard's screen, once the button is clicked);
    -- the two binding names in gold, as they look on the key bindings page (KeyBindings
    -- keeps the labels in the current language)
    local bindTip = on and L["Opens WoW's key bindings menu to bind %s and %s."]
        :format(Gold(BINDING_NAME_SSF_DELETE), Gold(BINDING_NAME_SSF_PAUSE)) or nil
    self.window:SetRightButton(L["Keybindings"], function() Window:OpenKeyBindings() end, bindTip)

    self.window:SetTitleColor(ClassColor()) -- "Soul Shards Forever" at the top, as the group titles
    self.window:SetTitleBand(TITLE_BAND)    -- the same dark strip behind it
    -- the help button: toggles help mode (Options), blue while on, its tooltip says which
    self.window:SetHelpButton(function() Options:ToggleHelp() end, on,
        on and L["Help ON: Click to hide tooltip help."]
        or L["Help OFF: Click to show tooltip help when you hover over an option."])
    self.window:SetFooter("v" .. SSF.VERSION .. "  " .. L["Started as a fork of SoulSort by Anilusion."])
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
    local black = SSF:GetModule("Colors").BLACK
    band:SetBackdropColor(black[1], black[2], black[3], TITLE_BAND)
    band:SetBackdropBorderColor(black[1], black[2], black[3], TITLE_BAND)
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
-- after a click). A secure hook on Open styles the titles as soon as any Open of the
-- window returns, Feed's included, in the same frame, so the stock titles never draw.
-- Not the window's own OnLayoutFinished: AceConfigDialog adds its ScrollFrame to the window
-- first, which lays the window out while the ScrollFrame is still empty, then fills the
-- ScrollFrame and lays out only that (tested: no styling at all).
-- The container can be nil (an Open of AceConfigDialog's own frame passes none), and so
-- can Window.window before its first open: without the guard, nil == nil would pass.
local function AfterDialogOpen(_, app, container)
    if app ~= APP or not container or container ~= Window.window then return end
    StyleGroupTitles(container.children[1]) -- the ScrollFrame AceConfigDialog puts in
end

-- Hooked again when Open has been replaced: a newer AceConfigDialog loaded later by
-- another addon redefines it, and the secure hook goes with the old function. AceHook's
-- Unhook on a secure hook only drops the handler, it never puts an old function back, so
-- the new hook lands on the new Open.
local hookedOpen
local function HookDialogOpen()
    if AceConfigDialog.Open == hookedOpen then return end
    if Window:IsHooked(AceConfigDialog, "Open") then Window:Unhook(AceConfigDialog, "Open") end
    Window:SecureHook(AceConfigDialog, "Open", AfterDialogOpen)
    hookedOpen = AceConfigDialog.Open
end

-- Feed the table into the window, then size the window to it: the width first (every text
-- on one line, SSFFrame:FitWidth; the layout depends on the width, so a changed width is
-- fed again), then the height (SSFFrame:FitToContent). The Tooltip module re-anchors
-- AceConfigDialog's option tooltips while they are shown inside this window's frame.
function Window:Feed()
    HookDialogOpen()
    SSF:GetModule("Tooltip"):Attach(self.window.frame)
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
    if IsShown(self) then self:Feed() end
end

-- A chat command changed a setting: redraw so an open window shows it. Only for "chat":
-- a GUI change sends the same message on every slider drag tick (see Refresh).
function Window:OnOptionsChanged(_, _, source)
    if source == "chat" then self:Refresh() end
end

-- The window's own strings or buttons may have changed: Options built and re-registered
-- the table (a Language change or a help toggle), or the player's macros changed ("Create
-- macros" shows or hides). Re-dress an existing window, then redraw.
function Window:Redress()
    if self.window then self:DressWindow() end
    self:Refresh()
end

-- The small standalone window: minimap click, /ssf, /ssf options, /ssf settings. Our own
-- SSFFrame container (AceGUI's Frame with SSF's X, bottom row and side note, sized to
-- content), created once and
-- re-fed on every open.
-- The minimap icon and broker click: close the window if it is showing, else open it.
function Window:Toggle()
    if IsShown(self) then
        self.window:Hide()
    else
        self:Open()
    end
end

function Window:Open()
    if self:InFight() then return end -- the window stays shut for the whole fight
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
        self.window = LibStub("AceGUI-3.0"):Create("SSFFrame")
        self.window:SetCallback("OnMoved", function(_, _, top, left)
            local window = SSF.db.profile.window
            window.top, window.left = top, left
            -- the screen size the spot belongs to (see Open)
            window.width, window.height = UIParent:GetWidth(), UIParent:GetHeight()
        end)
        -- bottom row: Create macros far left while shown, Key Bindings far right, the
        -- version and credit under them
        self:DressWindow()
        -- The first open of a session measures before every text size is settled (the
        -- window has not been drawn yet), which leaves a gap above the buttons. Feed again
        -- a tick later (a zero timer, AceTimer's 0.01 s floor), after the first draw, so the
        -- fit is measured on settled sizes.
        self:ScheduleTimer("Feed", 0)
    end
    self:Feed()
    self:SendMessage("SSF_WINDOW_OPENED") -- Welcome brings back a note still owed
end

-- Open the window with a note beside it (SSFFrame:ShowSidePanel). Welcome fills it.
function Window:ShowNote(titleText, bodyText, noteText, opts)
    if self:InFight() then return end -- no window in a fight, so no note either
    self:Open()
    self.window:ShowSidePanel(titleText, bodyText, noteText, opts)
end

-- A fight started: the window closes (the note beside it with it). It does not reopen by
-- itself afterwards.
function Window:PLAYER_REGEN_DISABLED()
    if IsShown(self) then self.window:Hide() end
end

-- Setup lives in OnEnable, not OnInitialize: Core's warlock gate switches modules off
-- before OnEnable, so other classes never get the window.
function Window:OnEnable()
    self:RegisterMessage("SSF_OPTIONS_REBUILT", "Redress")
    self:RegisterMessage("SSF_SHARD_DELETED", "Refresh")
    self:RegisterMessage("SSF_OPTIONS_CHANGED", "OnOptionsChanged")
    self:RegisterMessage("SSF_MACROS_CHANGED", "Redress")
    self:RegisterMessage("SSF_BAGS_CHANGED", "Refresh")
    self:RegisterMessage("SSF_QUIET_ENDED", "Refresh")
    -- a fight closes the window (and Open refuses until it's over)
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
end
