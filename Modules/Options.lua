-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Options: the one settings table and the /ssf command. AceConfigCmd turns it into the /ssf
-- commands, AceConfigDialog
-- turns the same table into the options window (fed by the Window module) and the Interface
-- Options entry, AceTab
-- completes the command words. Keys are the slash words; GUI-only entries carry cmdHidden.
-- Modules that show state (Counter, Broker, Window) listen for SSF_OPTIONS_CHANGED.
--
-- The window's layout and life cycle are in Modules\Window.lua.
-- Chat commands live at the root of the table (AceConfigCmd keys) and are hidden from the
-- window; their GUI twins live inside the groups.
--
-- Pause: the "pause" setting (/ssf pause, the checkbox in the cap group) stops every press
-- from moving or deleting (Trimmer reads profile.paused). Options:TogglePause() is the
-- key binding's entry (Bindings.xml SSF_PAUSE); it goes through the chat command's own
-- path, so it applies, redraws an open window and prints the same echo, Status:PauseText
-- ("SSF paused: Yes/No"). A bare /ssf opens the window and prints that line above
-- Status:StatusText.
--
-- Help mode (IsHelpOn, ToggleHelp; the window's help button): each option's help line, its
-- desc, shows as a hover tooltip while on. Off at load; nothing saved.
--
-- Stateful settings (cap, announce, pause) are defined once through the Settings module, which
-- returns the GUI control and the chat command for each; see Modules\Settings.lua for the
-- chat rule (naked = report, with value = apply and echo). Adding one = one Define() call.
--
-- Language (in Other, GUI-only): the strings in this table are read from L when it is built,
-- so a change goes Core:ApplyLanguage -> Options:Rebuild, which builds and re-registers the
-- table and sends SSF_OPTIONS_REBUILT (Window re-dresses and re-feeds an open window).
-- Everything else reads L live.
--
-- The /ssf handler wraps AceConfigCmd instead of registering a slash command with it:
-- AceConfigCmd's dispatch ignores cmdHidden, has no "help" word, and would not open the
-- window on a bare /ssf. It echoes the typed command in grey (except "delete", which macros
-- run before every cast), then hands the rest to AceConfigCmd.
--
-- Public:  TogglePause() (the pause key binding), IsHelpOn(), ToggleHelp(), Rebuild();
--          Options.APP, the AceConfig app name (Window opens the window by it).
-- Sends:   SSF_OPTIONS_CHANGED (key) from every GUI-only setter; SSF_OPTIONS_REBUILT.
-- Reads:   Settings:Define/TabUsage, Cap:MIN/MAX/Get/IsAuto/SetManual/Recompute,
--          Bags:Count/HasSoulBag, Trimmer:WhyNot/Delete, Sounds (levels, PlayPause),
--          Status:CountText/InBagsText/PauseText/PrintStatus, Colors, DeleteHelp:Text,
--          Window:Open, SSF:ApplyLanguage; NS.locales and NS.localeOrder (the Language
--          list); every profile key it shows: paused, pauseSound, pauseSoundVolume,
--          pauseLog, autoMax, lowMark, counter, lowGlow, counterColorize, counterSoulBag,
--          counterFont, minimap, announce, soulsortLegacy, soulsortReverse, language.
-- Saves:   the same keys, each through its own setter: profile.paused, pauseSound,
--          pauseSoundVolume, pauseLog, autoMax (SetManual's apply turns it off), lowMark,
--          counter, lowGlow, counterColorize, counterSoulBag, counterFont, minimap (.hide),
--          announce, soulsortLegacy, soulsortReverse, language. The cap itself goes
--          through Cap:SetManual.
-- Touches nothing else.

local ADDON, NS = ...            -- the folder: TOC metadata and the locale; NS.locales for the Language list
local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Options = SSF:NewModule("Options", "AceEvent-3.0", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigCmd = LibStub("AceConfigCmd-3.0")
local AceTab = LibStub("AceTab-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

Options.APP = "SSF" -- the AceConfig app: every line AceConfigCmd prints is prefixed with it
local APP = Options.APP

local function Cap() return SSF:GetModule("Cap") end
local function Bags() return SSF:GetModule("Bags") end
local function Sounds() return SSF:GetModule("Sounds") end
local function Status() return SSF:GetModule("Status") end
local function Colors() return SSF:GetModule("Colors") end
local function Gold(text) return Colors():Gold(text) end

-- the greyed-out rules the window shares between its controls
local function NotPaused() return not SSF.db.profile.paused end
local function CounterOff() return not SSF.db.profile.counter end
-- Colorize and the glow grey while paused and keep their ticks, the window's own rule on
-- the pause setting, the mirror image of the pause sound rows greying while unpaused
-- (Mike, 2026-10-21). What the count looks like while paused is Cap's and Colors' call.
local function CounterOffOrPaused() return CounterOff() or SSF.db.profile.paused end

-- The pause key binding (Bindings.xml SSF_PAUSE). Same path as "/ssf pause on|off".
function Options:TogglePause()
    self.pauseCmd.set(nil, SSF.db.profile.paused and "off" or "on")
end

-- Help mode, the window's help button: while on, every option in the window shows its help
-- line (its desc) as a hover tooltip; while off, none does. For the session only: nil at
-- load, so a /reload turns it off, and nothing is saved.
function Options:IsHelpOn() return self.help == true end

function Options:ToggleHelp()
    self.help = not self.help
    self:Rebuild() -- the tooltips are set when the table is built (ApplyHelp)
end

-- Every entry the window shows that has a help line gets a tooltip, or none, per help mode.
-- descStyle has to be a plain string (AceConfigRegistry), so it is set on every build. Chat
-- commands (dialogHidden) are skipped: their desc is AceConfigCmd's help text.
local function ApplyHelp(group, style)
    for _, entry in pairs(group.args) do
        if entry.args then
            ApplyHelp(entry, style)
        elseif entry.desc and not entry.dialogHidden then
            entry.descStyle = style
        end
    end
end

local function changed(key)
    Options:SendMessage("SSF_OPTIONS_CHANGED", key)
end

-- a full-width, GUI-only checkbox, indented 10px inside its group unless
-- `control` names another dialogControl (see Widgets\SSFCentered.lua). `indent` is the
-- SSFIndentCheckBox level (2 = 20px), passed as the option's `arg`; nil is level 1.
local function Toggle(order, name, get, set, disabled, control, indent)
    return {
        type = "toggle", order = order, width = "full",
        cmdHidden = true, descStyle = "hidden", dialogControl = control or "SSFIndentCheckBox",
        name = name, get = get, set = set, disabled = disabled, arg = indent,
    }
end

-- an entry with a narrower width than its builder gave it, so a second control fits on its row
local function Width(entry, width)
    entry.width = width
    return entry
end

-- a blank line between two groups, so the sections stand apart (a plain description entry:
-- no widget is restyled for the spacing)
local function Gap(order)
    return { type = "description", order = order, name = " ", width = "full", cmdHidden = true }
end

-- The reason under a greyed Delete Shard, per Trimmer:WhyNot(). Read live from L, so a
-- Language change shows at once.
local BLOCKER_TEXT = {
    atcap = function() return L["At cap"] end,
    undercap = function() return L["Under cap"] end,
    paused = function() return L["SSF paused"] end,
}

local function BuildTable()
    local Settings = SSF:GetModule("Settings")

    local setmaxGui, setmaxCmd = Settings:Define("setmax", {
        order = 1, kind = "range",
        name = L["Shards to keep"],
        desc = L["Your shard cap. Shards over this number are deleted one per press."],
        min = Cap().MIN, max = Cap().MAX, step = 1,
        get = function() return Cap():Get() end,
        extra = function() return Status():InBagsText() end,
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
        desc = L["Writes a line to chat every time a shard is deleted."],
        get = function() return SSF.db.profile.announce end,
        apply = function(value) SSF.db.profile.announce = value end,
    })
    announceGui.order = 2 -- GUI only: Other is minimap, announce, How shards move, language; the chat order stays

    local pauseGui, pauseCmd = Settings:Define("pause", {
        order = 1, kind = "toggle",
        name = L["Pause all SSF actions"],
        desc = L["Pause stops SSF from moving or deleting shards until you unpause."],
        get = function() return SSF.db.profile.paused end,
        apply = function(value) SSF.db.profile.paused = value end,
        -- "SSF paused: Yes/No", the pause line a bare /ssf prints, not "name: ON/OFF"
        echo = function() return Status():PauseText() end,
    })
    pauseGui.order = 1 -- GUI only: first in the Pause group
    Options.pauseCmd = pauseCmd -- for TogglePause; replaced on every rebuild

    -- GUI only (no chat command): the cap's own scale, but the thumb stops at the cap (the
    -- slider's bound, SSFStepperSlider:SetCustomData, fed through `arg`); Cap keeps the
    -- saved mark under the cap when the cap drops
    local lowmarkGui = Settings:Define("lowmark", {
        order = 1, kind = "range",
        name = L["Low shard warn"],
        min = Cap().MIN, max = Cap().MAX, step = 1,
        get = function() return SSF.db.profile.lowMark end,
        apply = function(value) SSF.db.profile.lowMark = value end,
    })
    lowmarkGui.arg = function() return Cap():Get() end

    -- the pause sound's levels, by Sounds' keys, each with its name
    local LEVEL_LABELS = {
        full = L["Full volume"], loud = L["Loud"], medium = L["Medium"], quiet = L["Quiet"],
    }
    local function LevelValues()
        local values = {}
        for _, key in ipairs(Sounds():LevelKeys()) do values[key] = LEVEL_LABELS[key] end
        return values
    end

    local args = {
        -- the top row: the count, with Delete Shard right after it, so a click and the number
        -- it changes sit together (Widgets\SSFCentered.lua). A mouse click is the hardware
        -- event Trimmer:Delete needs. Its help is every way to delete (DeleteHelp).
        -- Greyed whenever a click could not delete (Trimmer:WhyNot), with the reason in gold
        -- under it, so a click that does nothing never looks like a broken button.
        deletebutton = {
            type = "execute",
            order = 0,
            width = "full",
            cmdHidden = true,
            dialogControl = "SSFCountButton",
            name = L["Delete Shard"],
            -- greyed, the tooltip is only why (Mike's words, 2026-10-20); live, it teaches
            -- every way to delete
            desc = function()
                local why = SSF:GetModule("Trimmer"):WhyNot()
                if why == "paused" then return L["Nothing to delete, SSF is paused."] end
                if why then return L["Nothing to delete, you are at or under the cap."] end
                return SSF:GetModule("DeleteHelp"):Text(L["SSF deletes one Soul Shard when you're over the cap. Use the Delete Shard keybind, this button, a macro, or mix and match."])
            end,
            arg = function()
                local why = SSF:GetModule("Trimmer"):WhyNot()
                return Status():CountText(), why and BLOCKER_TEXT[why]()
            end,
            disabled = function() return SSF:GetModule("Trimmer"):WhyNot() ~= nil end,
            func = function() SSF:GetModule("Trimmer"):Delete() end,
        },

        -- a blank line between each pair of groups
        gap0 = Gap(3), gap1 = Gap(7), gap2 = Gap(15), gap3 = Gap(25), gap4 = Gap(35),

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
                        SSF.db.profile.pauseSound = value
                        -- ticking it on plays the sound at the selected level, as a preview
                        if value then Sounds():PlayPause() end
                        changed("pausesound")
                    end,
                    -- not full width, so the checkbox is as wide as its label (SSFIndentCheckBox)
                    -- and the window widens to fit this row (SSFFrame:FitWidth)
                    NotPaused, nil, 2), "normal"),
                -- on the same row as Play pause sound; picking a level plays the sound at it
                -- the name titles its tooltip only: the widget never shows a label
                pausevolume = {
                    type = "select", order = 3, width = "half",
                    cmdHidden = true, descStyle = "hidden", name = L["Volume"],
                    dialogControl = "SSFUnlabeledDropdown", -- Widgets\SSFCentered.lua
                    values = LevelValues,
                    sorting = Sounds():LevelKeys(),
                    get = function() return Sounds():LevelKey(SSF.db.profile.pauseSoundVolume) end,
                    set = function(_, key)
                        SSF.db.profile.pauseSoundVolume = Sounds():LevelVolume(key)
                        Sounds():PlayPause()
                        changed("pausevolume")
                    end,
                    disabled = function() return NotPaused() or not SSF.db.profile.pauseSound end,
                },
                pauselog = Toggle(4, L["Log pause to chat"],
                    function() return SSF.db.profile.pauseLog end,
                    function(_, value)
                        SSF.db.profile.pauseLog = value
                        changed("pauselog")
                    end,
                    NotPaused, nil, 2),
            },
        },

        cap = {
            type = "group", inline = true, order = 10, cmdHidden = true,
            name = L["Soul shard cap"],
            args = {
                setmaxGui = setmaxGui,
                automax = Toggle(2, -- left-aligned like every other checkbox
                    function()
                        if Bags():HasSoulBag() then return L["Match soul bag size"] end
                        return L["Match soul bag size (no soul bag)"]
                    end,
                    function() return SSF.db.profile.autoMax end,
                    function(_, value)
                        SSF.db.profile.autoMax = value
                        Cap():Recompute()
                        changed("automax")
                    end,
                    function() return not Bags():HasSoulBag() end),
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
                -- the glow is part of the bag display: it sits on the counter's button and
                -- runs only while the count shows (LowGlow). First under the count, right
                -- below the warn slider in the group above
                lowglow = Toggle(2, L["Glow bag button when low"],
                    function() return SSF.db.profile.lowGlow end,
                    function(_, value)
                        SSF.db.profile.lowGlow = value
                        changed("lowglow")
                    end,
                    CounterOffOrPaused, nil, 2),
                -- the number follows an equipped soul bag (Counter); greyed with the
                -- count off, but never for a missing soul bag: it waits for one to go on
                soulbag = Toggle(4, L["Show on soul bag when equipped"],
                    function() return SSF.db.profile.counterSoulBag end,
                    function(_, value)
                        SSF.db.profile.counterSoulBag = value
                        changed("countersoulbag")
                    end,
                    CounterOff, nil, 2),
                -- glow, colorize and soul bag all hang off the count checkbox, one step in
                colorize = Toggle(3, L["Colorize bag count"],
                    function() return SSF.db.profile.counterColorize end,
                    function(_, value)
                        SSF.db.profile.counterColorize = value
                        changed("countercolorize")
                    end,
                    CounterOffOrPaused, nil, 2),
                -- LibSharedMedia supplies the font list; the AceGUI SharedMedia widget draws
                -- the dropdown with previews. Size auto-fits the button.
                font = {
                    type = "select",
                    order = 5,
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
                    disabled = CounterOff,
                },
            },
        },

        -- right under the cap group, so the two sliders sit together. The low mark sets where
        -- red starts everywhere (bag, tooltip, window, chat), so it is never greyed
        glow = {
            type = "group", inline = true, order = 20, cmdHidden = true,
            name = L["Soul shard warning"],
            args = { lowmark = lowmarkGui },
        },

        other = {
            type = "group", inline = true, order = 40, cmdHidden = true,
            name = L["Other settings"],
            args = {
                -- How shards move: SSF Mode, or SoulSort's sort in its Normal or Reverse
                -- order (soulsortLegacy, soulsortReverse). What each choice does is in its help
                -- line, with the others' (help table below). SSF Mode leaves soulsortReverse as it is.
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
            desc = L["Deletes one Soul Shard if you are over the cap. In a macro, put /ssf delete on the line before the ability."],
            func = function() SSF:GetModule("Trimmer"):Delete() end,
        },
        options = {
            type = "execute",
            order = 70,
            dialogHidden = true,
            name = L["Open options"],
            desc = L["Open the options window."],
            func = function() SSF:GetModule("Window"):Open() end,
        },
        settings = { -- alias of options (S9)
            type = "execute",
            order = 71,
            dialogHidden = true,
            name = L["Open options"],
            desc = L["Same as options."],
            func = function() SSF:GetModule("Window"):Open() end,
        },
    }

    -- Help lines: each option's tooltip while help mode is on (ApplyHelp), by group and key.
    -- The cap, Pause and Announce lines come with their Settings:Define above. Plain
    -- sentences: the tooltip wraps them itself. Only How shards move keeps one line per choice.
    local lowWarn = L["Low shard warn"] -- quoted by name in two lines, in the player's language
    local bullet = "\226\128\162 "     -- "• "
    local help = {
        pausegroup = {
            pausesound = L["Each press while paused plays a sound."],
            pausevolume = L["Sets how loud the pause sound is."],
            pauselog = L["Each press while paused prints a chat line."],
        },
        cap = {
            automax = L["Sets cap automatically to the size of all soul bags (one or multiple)."],
        },
        glow = {
            lowmark = L["If shard count is lower than this, you will be notified with a red color change (and glow if enabled)."],
        },
        bagcount = {
            counter = L["Shows your shard count on a bag button (soul bag by default, left bag slot otherwise)."],
            lowglow = L['The bag button glows while you are below "%s".']:format(lowWarn),
            colorize = L['Red when below "%s", green in range, and yellow over the cap.']:format(lowWarn),
            soulbag = L["Moves the counter to your soul bag, whatever slot it's in."],
            font = L["The font used on the shard counter."],
        },
        other = {
            -- the intro, then one bullet per choice with a blank line between, each led by
            -- the choice's own name: SSF Mode in the state green (the safe pick, it moves
            -- nothing else), the SoulSort ones in neutral gold
            shardmode = L["How a macro or keybind moves shards."] .. " " .. L["Shards move to soul bag."]
                .. "\n\n" .. bullet .. Colors():State(L["SSF Mode"] .. ":", true) .. " "
                .. L["SSF does not sort (does NOT change item positions in bags)."]
                .. "\n\n" .. bullet .. Gold(L["SoulSort Normal"] .. ":") .. " "
                .. L["Shards sort top down (CHANGES item positions in your bags)."]
                .. "\n\n" .. bullet .. Gold(L["SoulSort Reverse"] .. ":") .. " "
                .. L["Shards sort bottom up (CHANGES item positions in your bags)."],
            minimap = L["Enables SSF minimap icon."],
            language = L["Auto uses game client language."],
        },
    }
    for group, lines in pairs(help) do
        for key, text in pairs(lines) do args[group].args[key].desc = text end
    end

    local root = { type = "group", name = L["Soul Shards Forever"], args = args }
    ApplyHelp(root, Options.help and "tooltip" or "hidden")
    return root
end

-- A chat word: a root entry of the table that AceConfigCmd exposes (not cmdHidden), or
-- "help". The one test for tab completion and for the handler's unknown-word check.
local function IsChatWord(word)
    if word == "help" then return true end
    local entry = Options.table.args[word]
    return entry ~= nil and not entry.cmdHidden
end

-- Tab completion in the chat box: "/ssf del<Tab>" -> "/ssf delete".
local function CommandWords(words)
    for key in pairs(Options.table.args) do
        if IsChatWord(key) then words[#words + 1] = key end
    end
    words[#words + 1] = "help"
end

-- /ssf: naked opens the window (open only, never a toggle) and prints the pause line, the
-- status line and a pointer to help. "/ssf help" or "/ssf ?" prints AceConfigCmd's command
-- list. An unknown first word prints one error line, then the list. Anything else goes
-- straight to AceConfigCmd, which parses and dispatches to the table.
local function HandleCommand(input)
    input = strtrim(input or "")
    local first = (input:match("^(%S+)") or ""):lower()
    -- WoW's chat never shows the slash command typed, so SSF echoes it in grey after a
    -- "> " prompt, above its answer, the way a terminal does. Not for "delete": macros run
    -- it before every cast, and an echo there would flood chat.
    if first ~= "delete" then
        SSF:Print(Colors():Echo("> /ssf" .. (input ~= "" and (" " .. input) or "")))
    end
    if input == "" then
        SSF:GetModule("Window"):Open()
        Status():PrintStatus()
        SSF:Print(L["Type /ssf help for commands."])
        return
    end
    if first == "help" or first == "?" then
        AceConfigCmd:HandleCommand("ssf", APP, "")
        return
    end
    if not IsChatWord(first) then
        SSF:Print(L['Unknown command "%s".']:format(first))
        AceConfigCmd:HandleCommand("ssf", APP, "")
        return
    end
    AceConfigCmd:HandleCommand("ssf", APP, input)
end

-- Setup lives in OnEnable, not OnInitialize: Ace3 runs every module's OnInitialize even when
-- Core's warlock gate has switched the module off, so /ssf would register on other classes.
function Options:OnEnable()
    self.table = BuildTable()
    AceConfig:RegisterOptionsTable(APP, self.table) -- no slashcmd here: /ssf is registered below
    SSF:RegisterChatCommand("ssf", HandleCommand)
    AceConfigDialog:AddToBlizOptions(APP, L["Soul Shards Forever"])
    AceTab:RegisterTabCompletion("SSF", "/ssf ", CommandWords, SSF:GetModule("Settings").TabUsage)
end

-- After a Language change: the table captured its strings when built, so build it again
-- and re-register (AceConfigRegistry replaces by app name; Settings:Define's AceTab
-- registrations are no-ops the second time). Window resets the window's own strings and
-- redraws on SSF_OPTIONS_REBUILT. The Interface Options category keeps the name it was added
-- under until a reload.
function Options:Rebuild()
    self.table = BuildTable()
    AceConfig:RegisterOptionsTable(APP, self.table)
    self:SendMessage("SSF_OPTIONS_REBUILT")
end
