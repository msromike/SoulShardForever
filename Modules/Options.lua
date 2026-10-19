-- Soul Shard Forever (SSF). MIT, see LICENSE.
--
-- Options: the one settings table. AceConfigCmd turns it into the /ssf commands, AceConfigDialog
-- turns the same table into the options window and the Interface Options entry, AceTab
-- completes the command words. Keys are the slash words; GUI-only entries carry cmdHidden.
-- Modules that show state (Counter, Broker) listen for SSF_OPTIONS_CHANGED.
--
-- Window layout: status line, then inline groups (Pause, Cap, Low shard glow, Bag count) and
-- Other, then a small version/credit line. Every toggle is full width, and a label that does
-- not fit wraps and grows its row (Widgets\SSFCentered.lua). The window sizes itself to the
-- content after every feed (Feed -> SSFWindow:FitToContent), so it never scrolls.
-- Chat commands live at the root of the table (AceConfigCmd keys) and are hidden from the
-- window; their GUI twins live inside the groups.
--
-- Pause: the "pause" setting (/ssf pause, the checkbox in the cap group) stops every press
-- from moving or deleting (Trimmer reads profile.paused). Options:TogglePause() is the
-- key binding's entry (Bindings.xml SSF_PAUSE); it goes through the chat command's own
-- path, so it applies, redraws an open window and prints the same echo. A bare /ssf opens
-- the window and prints PauseText ("SSF actions - ON/OFF") on its own line above StatusText.
--
-- Stateful settings (cap, announce, pause) are defined once through the Settings module, which
-- returns the GUI control and the chat command for each; see Modules\Settings.lua for the
-- chat rule (naked = report, with value = apply and echo). Adding one = one Define() call.
--
-- Language (in Other, GUI-only): the strings in this table are read from L when it is built,
-- so a change goes Core:ApplyLanguage -> Options:Rebuild, which builds and re-registers the
-- table and re-feeds the open window. Everything else reads L live.

local ADDON, NS = ...            -- the folder: TOC metadata and the locale; NS.locales for the Language list
local APP = "SSF"                -- the AceConfig app: every line AceConfigCmd prints is prefixed with it
local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Options = SSF:NewModule("Options", "AceEvent-3.0", "AceBucket-3.0", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigCmd = LibStub("AceConfigCmd-3.0")
local AceTab = LibStub("AceTab-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

local function Cap() return SSF:GetModule("Cap") end
local function Bags() return SSF:GetModule("Bags") end

local function Value(v) return SSF:GetModule("Settings"):Value(v) end

-- The one count/cap wording, used by the window and the announce line. The count takes
-- the one state color (Counter:StateColor: red / green / yellow, or white when colorizing
-- is off) so the window shows the effect of a cap change without looking at the bag; the
-- cap is a setting, so it gets the neutral value color. Both arguments are optional: the
-- Trimmer passes the count it knows right after a delete, when the bags still show the
-- deleted shard until the server confirms.
function Options:StatusText(count, cap)
    count, cap = count or Bags():Count(), cap or Cap():Get()
    local _, _, _, hex = SSF:GetModule("Counter"):StateColor(count, cap)
    return L["Soul Shards: %s (cap %s)"]:format("|cff" .. hex .. count .. "|r", Value(cap))
end

-- The first line of a bare /ssf: "SSF actions - ON" (green) while presses work,
-- "- OFF" (red) while paused.
function Options:PauseText()
    local on = not SSF.db.profile.paused
    return L["SSF actions"] .. " - " .. SSF:GetModule("Settings"):OnOff(on)
end

-- The pause key binding (Bindings.xml SSF_PAUSE). Same path as "/ssf pause on|off".
function Options:TogglePause()
    self.pauseCmd.set(nil, SSF.db.profile.paused and "off" or "on")
end

local function changed(key)
    Options:SendMessage("SSF_OPTIONS_CHANGED", key)
end

-- a full-width, GUI-only, tooltip-free checkbox, indented 10px inside its group unless
-- `control` names another dialogControl (see Widgets\SSFCentered.lua). `indent` is the
-- SSFIndentCheckBox level (2 = 20px), passed as the option's `arg`; nil is level 1.
local function Toggle(order, name, get, set, disabled, control, indent)
    return {
        type = "toggle", order = order, width = "full",
        cmdHidden = true, descStyle = "hidden", dialogControl = control or "SSFIndentCheckBox",
        name = name, get = get, set = set, disabled = disabled, arg = indent,
    }
end

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

-- an entry with a narrower width than its builder gave it, so a second control fits on its row
local function Width(entry, width)
    entry.width = width
    return entry
end

-- Pause sound volume levels: each one half the one before, about 6 dB apart, so the steps
-- sound even to the ear (tested by ear against evenly spaced levels). Keys are what the
-- dropdown stores; the volume goes into profile.pauseSoundVolume.
-- (A fifth level, 0.06, was too faint to be useful and was dropped.)
local VOLUME_ORDER = { "full", "loud", "medium", "quiet" }
local VOLUMES = { full = 1, loud = 0.5, medium = 0.25, quiet = 0.12 }

local function VolumeKey(volume)
    for key, value in pairs(VOLUMES) do
        if value == volume then return key end
    end
    return "full"
end

local function BuildTable()
    local Settings = SSF:GetModule("Settings")

    local setmaxGui, setmaxCmd = Settings:Define("setmax", {
        order = 1, kind = "range",
        name = L["Shards to keep"],
        desc = L["The cap. Shards over this number are deleted one per press."],
        min = Cap().MIN, max = Cap().MAX, step = 1,
        get = function() return Cap():Get() end,
        extra = function() return L["(in bags: %s)"]:format(Value(Bags():Count())) end,
        apply = function(value)
            SSF.db.profile.autoMax = false
            Cap():SetManual(value)
        end,
        -- greyed in the GUI while AutoMax binds to a soul bag; the chat form always works
        disabled = function() return Cap():IsAuto() end,
    })

    local announceGui, announceCmd = Settings:Define("announce", {
        order = 1, kind = "toggle",
        name = L["Announce deletions in chat"],
        desc = L["One chat line per deleted shard, for addons that watch chat."],
        get = function() return SSF.db.profile.announce end,
        apply = function(value) SSF.db.profile.announce = value end,
    })
    announceGui.order = 2 -- GUI only: Other is minimap, announce, How shards move, language; the chat order stays
    announceGui.width = "full"
    announceGui.dialogControl = "SSFIndentCheckBox"

    local pauseGui, pauseCmd = Settings:Define("pause", {
        order = 1, kind = "toggle",
        name = L["Pause all SSF actions"],
        desc = L["Stop every press from moving or deleting shards, until you turn it off."],
        get = function() return SSF.db.profile.paused end,
        apply = function(value) SSF.db.profile.paused = value end,
    })
    pauseGui.order = 1 -- GUI only: first in the Pause group
    pauseGui.width = "full"
    pauseGui.dialogControl = "SSFIndentCheckBox"
    Options.pauseCmd = pauseCmd -- for TogglePause; replaced on every rebuild

    local args = {
        status = {
            type = "description",
            order = 0,
            width = "full",
            cmdHidden = true,
            fontSize = "large",
            dialogControl = "SSFCenteredLabel", -- Widgets\SSFCentered.lua
            name = function() return Options:StatusText() .. "\n" end,
        },

        -- a blank line between each pair of groups, so the sections stand apart (plain
        -- description entries: no widget is restyled for the spacing)
        gap0 = { type = "description", order = 3, name = " ", width = "full", cmdHidden = true },
        gap1 = { type = "description", order = 7, name = " ", width = "full", cmdHidden = true },
        gap2 = { type = "description", order = 15, name = " ", width = "full", cmdHidden = true },
        gap3 = { type = "description", order = 25, name = " ", width = "full", cmdHidden = true },
        gap4 = { type = "description", order = 35, name = " ", width = "full", cmdHidden = true },

        -- keyed pausegroup: "pause" is the chat command's key in this same table
        pausegroup = {
            type = "group", inline = true, order = 5, cmdHidden = true,
            name = L["Pause SSF"],
            args = {
                pauseGui = pauseGui,
                -- the sound, its volume and the chat line hang off the pause box: indented one
                -- step, greyed while not paused (their values are kept)
                pausesound = Width(Toggle(2, L["Play pause sound"],
                    function() return SSF.db.profile.pauseSound end,
                    function(_, value)
                        local p = SSF.db.profile
                        p.pauseSound = value
                        -- ticking it on plays the sound at the selected level, as a preview
                        if value then
                            SSF:GetModule("Sounds"):Play(p.pauseSoundName, p.pauseSoundVolume)
                        end
                        changed("pausesound")
                    end,
                    function() return not SSF.db.profile.paused end, nil, 2), "normal"),
                -- on the same row as Play pause sound; picking a level plays the sound at it
                pausevolume = {
                    type = "select", order = 3, width = "half",
                    cmdHidden = true, descStyle = "hidden", name = "",
                    values = {
                        full = L["Full volume"], loud = L["Loud"], medium = L["Medium"],
                        quiet = L["Quiet"],
                    },
                    sorting = VOLUME_ORDER,
                    get = function() return VolumeKey(SSF.db.profile.pauseSoundVolume) end,
                    set = function(_, key)
                        local p = SSF.db.profile
                        p.pauseSoundVolume = VOLUMES[key] or 1
                        SSF:GetModule("Sounds"):Play(p.pauseSoundName, p.pauseSoundVolume)
                        changed("pausevolume")
                    end,
                    disabled = function()
                        local p = SSF.db.profile
                        return not (p.paused and p.pauseSound)
                    end,
                },
                pauselog = Toggle(4, L["Log pause to chat"],
                    function() return SSF.db.profile.pauseLog end,
                    function(_, value)
                        SSF.db.profile.pauseLog = value
                        changed("pauselog")
                    end,
                    function() return not SSF.db.profile.paused end, nil, 2),
            },
        },

        cap = {
            type = "group", inline = true, order = 10, cmdHidden = true,
            name = L["Soul shard cap"],
            args = {
                setmaxGui = setmaxGui,
                automax = Toggle(2, -- left-aligned like every other checkbox
                    function()
                        if Bags():SoulBagSlots() > 0 then return L["Match soul bag size"] end
                        return L["Match soul bag size (no soul bag)"]
                    end,
                    function() return SSF.db.profile.autoMax end,
                    function(_, value)
                        SSF.db.profile.autoMax = value
                        Cap():Recompute()
                        changed("automax")
                    end,
                    function() return Bags():SoulBagSlots() == 0 end),
            },
        },

        bagcount = {
            type = "group", inline = true, order = 30, cmdHidden = true,
            name = L["Soul shard counter"],
            args = {
                counter = Toggle(1, L["Show shard count on bag bar"],
                    function() return SSF.db.profile.counter end,
                    function(_, value)
                        SSF.db.profile.counter = value
                        changed("counter")
                    end),
                -- the number follows an equipped soul bag (Counter:Anchor); greyed with the
                -- count off, but never for a missing soul bag: it waits for one to go on
                soulbag = Toggle(3, L["Show on soul bag when equipped"],
                    function() return SSF.db.profile.counterSoulBag end,
                    function(_, value)
                        SSF.db.profile.counterSoulBag = value
                        changed("countersoulbag")
                    end,
                    function() return not SSF.db.profile.counter end,
                    nil, 2),
                -- colorize and soul bag both hang off the count checkbox: one step in, colorize first
                colorize = Toggle(2, L["Colorize bag count"],
                    function() return SSF.db.profile.counterColorize end,
                    function(_, value)
                        SSF.db.profile.counterColorize = value
                        changed("countercolorize")
                    end,
                    function() return not SSF.db.profile.counter end,
                    nil, 2),
                -- LibSharedMedia supplies the font list; the AceGUI SharedMedia widget draws
                -- the dropdown with previews. Size auto-fits the button.
                font = {
                    type = "select",
                    order = 4,
                    width = "full",
                    cmdHidden = true,
                    descStyle = "hidden",
                    dialogControl = "LSM30_Font",
                    name = L["Bag counter font"],
                    values = LSM:HashTable("font"),
                    get = function() return SSF.db.profile.counterFont end,
                    set = function(_, value)
                        SSF.db.profile.counterFont = value
                        changed("counterfont")
                    end,
                    disabled = function() return not SSF.db.profile.counter end,
                },
            },
        },

        -- right under the cap group, so the two sliders sit together; slider first, its
        -- checkbox below it, the same shape as the cap group
        glow = {
            type = "group", inline = true, order = 20, cmdHidden = true,
            name = L["Soul shard warning"],
            args = {
                lowglow = Toggle(2, L["Glow bag button when low"],
                    function() return SSF.db.profile.lowGlow end,
                    function(_, value)
                        SSF.db.profile.lowGlow = value
                        changed("lowglow")
                    end),
                lowmark = {
                    type = "range",
                    order = 1,
                    cmdHidden = true,
                    descStyle = "hidden",
                    name = L["Low shard warn"],
                    -- the cap's own range: a warlock holding 96 shards may want a warning at 40
                    min = 1, max = 100, step = 1,
                    width = "full",
                    dialogControl = "SSFStepperSlider",
                    get = function() return SSF.db.profile.lowMark end,
                    set = function(_, value)
                        SSF.db.profile.lowMark = value
                        changed("lowmark")
                    end,
                    disabled = function() return not SSF.db.profile.lowGlow end,
                },
            },
        },

        other = {
            type = "group", inline = true, order = 40, cmdHidden = true,
            name = L["Other settings"],
            args = {
                -- How shards move: SSF Mode, or SoulSort's sort in its Normal or Reverse
                -- order (soulsortLegacy, soulsortReverse). Each line's tooltip is in arg
                -- (Widgets\SSFDropdownItemTip.lua). SSF Mode leaves soulsortReverse as it is.
                shardmode = {
                    type = "select",
                    order = 3,
                    width = "full",
                    cmdHidden = true,
                    descStyle = "hidden",
                    name = L["How shards move"],
                    values = {
                        ssf = L["SSF Mode"],
                        normal = L["SoulSort Normal"],
                        reverse = L["SoulSort Reverse"],
                    },
                    sorting = { "ssf", "normal", "reverse" },
                    itemControl = "SSFDropdownItemTip",
                    arg = {
                        ssf = L["Shards move to soul bag. SSF does not sort."],
                        normal = L["Shards move to soul bag. Shards sort top down."],
                        reverse = L["Shards move to soul bag. Shards sort bottom up."],
                    },
                    get = function()
                        local p = SSF.db.profile
                        if not p.soulsortLegacy then return "ssf" end
                        return p.soulsortReverse and "reverse" or "normal"
                    end,
                    set = function(_, value)
                        local p = SSF.db.profile
                        p.soulsortLegacy = value ~= "ssf"
                        if value ~= "ssf" then p.soulsortReverse = value == "reverse" end
                        changed("shardmode")
                    end,
                },
                announceGui = announceGui,
                minimap = Toggle(1, L["Show minimap icon"],
                    function() return not SSF.db.profile.minimap.hide end,
                    function(_, value)
                        SSF.db.profile.minimap.hide = not value
                        changed("minimap")
                    end),
                -- Auto follows the client; a code forces that locale (Core:ApplyLanguage).
                -- Names are each language's own, never translated, and so is "Auto": it is
                -- the way back for a player stuck in a language they cannot read. The
                -- rebuild is deferred a tick: AceConfigDialog is still inside this set when
                -- it returns.
                language = {
                    type = "select",
                    order = 5,
                    width = "full",
                    cmdHidden = true,
                    descStyle = "hidden",
                    name = L["Language"],
                    values = function()
                        local values = { auto = "Auto" }
                        for code, locale in pairs(NS.locales) do values[code] = locale.name end
                        return values
                    end,
                    sorting = function()
                        local order = { "auto" }
                        for _, code in ipairs(NS.localeOrder) do order[#order + 1] = code end
                        return order
                    end,
                    get = function() return SSF.db.profile.language or "auto" end,
                    set = function(_, value)
                        SSF.db.profile.language = value ~= "auto" and value or nil
                        SSF:ApplyLanguage()
                        Options:ScheduleTimer("Rebuild", 0)
                        changed("language")
                    end,
                },
            },
        },

        -- chat commands, hidden from the window
        setmax = setmaxCmd,
        announce = announceCmd,
        pause = pauseCmd,
        delete = {
            type = "execute",
            order = 1,
            dialogHidden = true,
            name = L["Delete Shard"],
            desc = L["Delete one Soul Shard if you are over the cap. In a macro, put /ssf delete on the line before the ability."],
            func = function() SSF:GetModule("Trimmer"):Delete() end,
        },
        options = {
            type = "execute",
            order = 70,
            dialogHidden = true,
            name = L["Open options"],
            desc = L["Open the options window."],
            func = function() Options:Open() end,
        },
        settings = { -- alias of options (S9)
            type = "execute",
            order = 71,
            dialogHidden = true,
            name = L["Open options"],
            desc = L["Same as options."],
            func = function() Options:Open() end,
        },
    }

    return { type = "group", name = L["Soul Shard Forever"], args = args }
end

-- Setup lives in OnEnable, not OnInitialize: Ace3 runs every module's OnInitialize even when
-- Core's warlock gate has switched the module off, so /ssf would register on other classes.
-- Tab completion in the chat box: "/ssf del<Tab>" -> "/ssf delete". Only the words
-- AceConfigCmd exposes (root entries without cmdHidden), plus "help".
local function CommandWords(words)
    for key, entry in pairs(Options.table.args) do
        if not entry.cmdHidden then words[#words + 1] = key end
    end
    words[#words + 1] = "help"
end

function Options:OnEnable()
    -- a saved volume that is no longer a level (the dropped Faint) goes back to Full
    local p = SSF.db.profile
    if VolumeKey(p.pauseSoundVolume) == "full" then p.pauseSoundVolume = VOLUMES.full end
    p.window.open = nil -- left over from a dropped reopen-after-reload try
    self.table = BuildTable()
    AceConfig:RegisterOptionsTable(APP, self.table) -- no slashcmd here: /ssf is registered below
    -- /ssf: naked opens the window (open only, never a toggle) and prints the pause line,
    -- the status line and a pointer to help.
    -- "/ssf help" or "/ssf ?" prints AceConfigCmd's command list. An unknown first word
    -- prints one error line, then the list. Anything else goes straight to AceConfigCmd,
    -- which parses and dispatches to the table.
    SSF:RegisterChatCommand("ssf", function(input)
        input = strtrim(input or "")
        -- WoW's chat never shows the slash command typed, so SSF echoes it in grey after a
        -- "> " prompt, above its answer, the way a terminal does. Not for "delete": macros run it before
        -- every cast, and an echo there would flood chat.
        local first = (input:match("^(%S+)") or ""):lower()
        if first ~= "delete" then
            SSF:Print("|cff808080> /ssf" .. (input ~= "" and (" " .. input) or "") .. "|r")
        end
        if input == "" then
            Options:Open()
            SSF:Print(Options:PauseText())
            SSF:Print(Options:StatusText())
            SSF:Print(L["Type /ssf help for commands."])
            return
        end
        local word = input:match("^(%S+)"):lower()
        if word == "help" or word == "?" then
            AceConfigCmd:HandleCommand("ssf", APP, "")
            return
        end
        local entry = Options.table.args[word]
        if not entry or entry.cmdHidden then
            SSF:Print(L['Unknown command "%s".']:format(word))
            AceConfigCmd:HandleCommand("ssf", APP, "")
            return
        end
        AceConfigCmd:HandleCommand("ssf", APP, input)
    end)
    AceConfigDialog:SetDefaultSize(APP, 310, 590) -- the width; the height is replaced by the first fit
    AceConfigDialog:AddToBlizOptions(APP, L["Soul Shard Forever"])

    AceTab:RegisterTabCompletion("SSF", "/ssf ", CommandWords, SSF:GetModule("Settings").TabUsage)

    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    self:RegisterMessage("SSF_SHARD_DELETED", "Refresh")
    self:RegisterMessage("SSF_OPTIONS_CHANGED", "OnOptionsChanged")
    self:RegisterBucketEvent({ "BAG_UPDATE", "BAG_CONTAINER_UPDATE" }, 0.5, "Refresh")
end

-- Login and reload: the same two lines as a bare /ssf, once, after the version line. The
-- count needs the bag contents. On a reload they are there when the world is entered; on
-- a fresh login they are not (tested: it counted 0), so the lines wait for the game's
-- BAG_UPDATE_DELAYED, with a timer in case that never comes.
function Options:PLAYER_ENTERING_WORLD(_, isInitialLogin)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    if isInitialLogin then
        self:RegisterEvent("BAG_UPDATE_DELAYED", "PrintLoginStatus")
        self.loginTimer = self:ScheduleTimer("PrintLoginStatus", 10)
    else
        self:PrintLoginStatus()
    end
end

function Options:PrintLoginStatus()
    if self.loginStatusPrinted then return end
    self.loginStatusPrinted = true
    self:UnregisterEvent("BAG_UPDATE_DELAYED")
    if self.loginTimer then self:CancelTimer(self.loginTimer) end
    SSF:Print(self:PauseText())
    SSF:Print(self:StatusText())
end

-- After a Language change: the table captured its strings when built, so build it again
-- and re-register (AceConfigRegistry replaces by app name; Settings:Define's AceTab
-- registrations are no-ops the second time). The window's own two strings are reset here
-- too. The Interface Options category keeps the name it was added under until a reload.
function Options:Rebuild()
    self.table = BuildTable()
    AceConfig:RegisterOptionsTable(APP, self.table)
    if self.window then self:DressWindow() end
    self:Refresh()
end

-- Blizzard's Key Bindings page, scrolled to SSF's section and opened expanded. There is no
-- function to expand a section, so the section's own flag (initializer.data.expanded) is
-- set first; tested in game, and a key bound there afterwards stuck through a reload with
-- nothing blocked. The section name is Bindings.xml's category. SSF's window closes first:
-- it draws above the settings panel.
local BINDING_SECTION = "Soul Shard Forever"

function Options:OpenKeyBindings()
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
function Options:DressWindow()
    self.window:SetActionButton(L["Delete Shard"], function() SSF:GetModule("Trimmer"):Delete() end)
    local label = SETTINGS_KEYBINDINGS_LABEL or KEY_BINDINGS or "Key Bindings"
    self.window:SetRightButton(label, function() Options:OpenKeyBindings() end)
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
    if app ~= APP or not container or container ~= Options.window then return end
    StyleGroupTitles(container.children[1]) -- the ScrollFrame AceConfigDialog puts in
end

local hookedOpen
local function HookDialogOpen()
    if AceConfigDialog.Open == hookedOpen then return end
    hooksecurefunc(AceConfigDialog, "Open", AfterDialogOpen)
    hookedOpen = AceConfigDialog.Open
end

-- Feed the table into the window, then size the window to it (see SSFWindow:FitToContent).
function Options:Feed()
    HookDialogOpen()
    AceConfigDialog:Open(APP, self.window)
    self.window:FitToContent()
end

-- Keep the status line and the AutoMax state fresh while a window is open.
-- NOT on SSF_CAP_CHANGED: AceConfigDialog calls the slider's set on every drag tick, and a
-- rebuild from inside that loop recreates the slider under the mouse. AceConfig already
-- refreshes after a release or a button click; the bag bucket covers everything else.
-- NotifyChange covers the Interface Options panel; the standalone window is our own
-- container, which AceConfigDialog does not track, so it is re-fed here while shown.
function Options:Refresh()
    AceConfigRegistry:NotifyChange(APP)
    if self.window and self.window.frame:IsShown() then
        self:Feed()
    end
end

-- A chat command changed a setting: redraw so an open window shows it. Only for "chat":
-- a GUI change sends the same message on every slider drag tick (see Refresh).
function Options:OnOptionsChanged(_, _, source)
    if source == "chat" then self:Refresh() end
end

-- The small standalone window: minimap click, /ssf, /ssf options, /ssf settings. Our own
-- SSFWindow container (X button, no status bar, sized to content), created once and
-- re-fed on every open.
-- The minimap icon and broker click: close the window if it is showing, else open it.
function Options:Toggle()
    if self.window and self.window.frame:IsShown() then
        self.window:Hide()
    else
        self:Open()
    end
end

function Options:Open()
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
