-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Options: the one settings table. AceConfigCmd turns it into the /ssf commands (through
-- SlashCommand, which owns /ssf itself), AceConfigDialog turns the same table into the
-- options window (fed by the Window module) and the Interface Options entry, and
-- TabComplete offers its words. Keys are the slash words; GUI-only entries carry
-- cmdHidden. Modules that show state (Counter, Broker, Window) listen for
-- SSF_OPTIONS_CHANGED.
--
-- The window's layout and life cycle are in Modules\Window.lua.
-- Chat commands live at the root of the table (AceConfigCmd keys) and are hidden from the
-- window; their GUI twins, where a command has one, live inside the groups (Delete Shard's
-- sits at the top, outside the groups; options and settings have none). No key inside a
-- group may equal a chat word: AceConfigCmd looks inside every group for a typed word and
-- ignores cmdHidden there, so a twin keyed "pause" could take /ssf pause over. Hence
-- pauseGui, setmaxGui, logGui (tests/test_options.lua holds it).
--
-- Pause: the "pause" setting (/ssf pause, the checkbox in the Pause group) stops every press
-- from moving or deleting (Trimmer:Paused is the gate). Options:TogglePause() is the
-- key binding's entry (Bindings.xml SSF_PAUSE); it goes through the chat command's own
-- path, so it applies, redraws an open window and prints the same echo, Status:PauseText
-- ("SSF paused: Yes/No"). A bare /ssf opens the window and prints that line above
-- Status:StatusText.
--
-- Help mode is the Help module's: the table hands itself to Help:Apply at the end of every
-- build (each option's help line is its desc), and rebuilds on SSF_HELP_CHANGED.
--
-- Stateful settings (setmax, log, pause, and the window-only lowmark and pausesound) are defined once through the Settings module, which
-- returns the GUI control and the chat command for each; see Modules\Settings.lua for the
-- chat rule (naked = report, with value = apply and echo). Adding one = one Define() call,
-- then placing its two entries in the table below.
--
-- Language (in Other, GUI-only): the strings in this table are read from L when it is built,
-- so a change goes Core:ApplyLanguage -> Options:Rebuild, which builds and re-registers the
-- table and sends SSF_OPTIONS_REBUILT (Window re-dresses and re-feeds an open window).
-- Everything else reads L live.
--
-- Chat words: "announce", the old word for "log", is a second, hidden chat command, so old
-- macros keep working; it is not listed anywhere. "debug" is hidden the same way
-- (HIDDEN_WORDS); what follows it is DebugCommand's. ChatWord answers which words are
-- commands, listed or hidden, for SlashCommand and TabComplete alike.
--
-- Public:  TogglePause() (the pause key binding), Rebuild();
--          ChatWord(word) -> "listed" | "hidden" | nil, ChatWords() -> every listed word,
--          sorted (SlashCommand, TabComplete); IsHelpWord(word) -> true for the word
--          that prints the command list or its short form (SlashCommand);
--          SetCapShortForm(input) ("/ssf 25", SlashCommand);
--          Options.APP, the AceConfig app name (Window opens the window by it).
-- Listens: SSF_HELP_CHANGED (Rebuild: the table captured its tooltip style when built).
-- Sends:   SSF_OPTIONS_CHANGED (key, "window") from every GUI-only setter; SSF_OPTIONS_REBUILT.
-- Reads:   Help:Apply, Settings:Define/ValueWords,
--          Cap:MIN/MAX/Get/IsAuto/SetManual/Recompute/LowMark/SetLowMark,
--          Bags:HasSoulBag, Counter:OnSoulBag, Trimmer:WhyNot/Delete/Paused (the pause
--          gate, for the greyed rules and the key binding), Sounds (LevelStep, PlayPause),
--          Status:CountText/InBagsText/PauseText, Colors, DeleteHelp:Text,
--          DebugCommand:Run, Window:Open, SSF:ApplyLanguage; NS.locales and NS.localeOrder (the Language
--          list); every profile key it shows: paused, pauseSoundLevel,
--          pauseLog, autoMax, counter, lowGlow, counterColorize, counterSoulBag,
--          counterFont, minimap, announce, soulsortLegacy, soulsortReverse, language.
-- Saves:   the same keys, each through its own setter: profile.paused, pauseSoundLevel,
--          pauseLog, autoMax (SetManual's apply turns it off),
--          counter, lowGlow, counterColorize, counterSoulBag, counterFont, minimap (.hide),
--          announce, soulsortLegacy, soulsortReverse, language. The cap and the low mark
--          are Cap's: they go through Cap:SetManual and Cap:SetLowMark.
-- Touches nothing else.

local ADDON, NS = ...            -- the folder: TOC metadata and the locale; NS.locales for the Language list
local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Options = SSF:NewModule("Options", "AceEvent-3.0", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

Options.APP = "SSF" -- the AceConfig app: AceConfigCmd's help header names it
local APP = Options.APP

local function Cap() return SSF:GetModule("Cap") end
local function Bags() return SSF:GetModule("Bags") end
local function Counter() return SSF:GetModule("Counter") end
local function Sounds() return SSF:GetModule("Sounds") end
local function Status() return SSF:GetModule("Status") end
local function Colors() return SSF:GetModule("Colors") end
local function Gold(text) return Colors():Gold(text) end

-- the greyed-out rules the window shares between its controls
local function Paused() return SSF:GetModule("Trimmer"):Paused() end -- the one pause gate
local function NotPaused() return not Paused() end
local function CounterOff() return not SSF.db.profile.counter end
-- Colorize and the glow grey while paused and keep their ticks, the window's own rule on
-- the pause setting, the mirror image of the pause log row greying while unpaused.
-- What the count looks like while paused is Cap's and Colors' call.
local function CounterOffOrPaused() return CounterOff() or Paused() end

-- The pause key binding (Bindings.xml SSF_PAUSE). Same path as "/ssf pause on|off".
function Options:TogglePause()
    self.pauseCmd.set(nil, Paused() and "off" or "on")
end

local function changed(key)
    Options:SendMessage("SSF_OPTIONS_CHANGED", key, "window") -- every caller is a window control's set
end

-- a full-width, GUI-only checkbox, indented 10px inside its group unless
-- `control` names another dialogControl (see Widgets\SSFCentered.lua). `indent` is the
-- SSFIndentCheckBox level (2 = 20px), or its { level, radio } table, passed as the option's
-- `arg`; nil is level 1.
local function Toggle(order, name, get, set, disabled, control, indent)
    return {
        type = "toggle", order = order, width = "full",
        cmdHidden = true, dialogControl = control or "SSFIndentCheckBox",
        name = name, get = get, set = set, disabled = disabled, arg = indent,
    }
end

-- an entry with a narrower width than its builder gave it, so a second control fits on its row
local function Width(entry, width)
    entry.width = width
    return entry
end

-- One of the two radios for the counter's place (SSFIndentCheckBox drawn as a radio), under the
-- counter checkbox. The dot is where the number sits (Counter:OnSoulBag), not the saved
-- key: with no soul bag equipped the dot is on the far-left radio while the key still says
-- soul bag, so the number moves to the first soul bag by itself. A click saves only on a
-- real change: a click on the radio that has the dot writes nothing and sends nothing
-- (AceConfigDialog redraws after every set, which puts the dot back).
-- The two share one row, a half line over Colorize and the glow, so they read as one pick.
-- Not full width: each is as wide as its label (SSFIndentCheckBox).
-- `follows` marks the second one: it starts one check box width after the first's label.
local function PlaceRadio(order, name, onSoulBag, disabled, follows)
    return Width(Toggle(order, name,
        function() return Counter():OnSoulBag() == onSoulBag end,
        function()
            if Counter():OnSoulBag() == onSoulBag then return end
            SSF.db.profile.counterSoulBag = onSoulBag
            changed("countersoulbag")
        end,
        disabled, nil,
        { level = 2, radio = true, after = true, follows = follows }),
        "normal")
end

-- a blank line between two groups, so the sections stand apart (a plain description entry:
-- no widget is restyled for the spacing)
local function Gap(order)
    return { type = "description", order = order, name = " ", width = "full", cmdHidden = true }
end

-- The old word for "/ssf log": a hidden chat command, so old macros keep working.
local OLD_LOG_WORD = "announce"
-- The debug record's command: hidden too, handed to a player who needs it (DebugCommand).
local DEBUG_WORD = "debug"
-- the chat words /ssf lets through although the help list and Tab never show them
local HIDDEN_WORDS = { [OLD_LOG_WORD] = true, [DEBUG_WORD] = true }
-- The word that prints the command list, shown in that list and offered on Tab, and its
-- short form, which works but is never shown. Neither is an entry of the table:
-- SlashCommand acts on them, and asks here which words they are (IsHelpWord).
local HELP_WORD = "help"
local HELP_WORDS = { [HELP_WORD] = true, ["?"] = true }

-- The reason on a greyed Delete Shard, per Trimmer:WhyNot(). Read live from L, so a
-- Language change shows at once.
local function CapIs() return L["cap is %d"]:format(Cap():Get()) end
local BLOCKER_TEXT = {
    atcap = CapIs,
    undercap = CapIs,
    paused = function() return L["SSF paused"] end,
    quiet = function() return L["no Drain Soul yet"] end,
    locked = function() return L["shard locked"] end,
}

-- every reason the button can show: it sizes itself to the longest
local function AllBlockers()
    local list = {}
    for _, text in pairs(BLOCKER_TEXT) do list[#list + 1] = text() end
    return list
end

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

    local logGui, logCmd = Settings:Define("log", {
        order = 1, kind = "toggle",
        name = L["Log deletions to chat"],
        desc = L["Writes a line to chat every time a shard is deleted."],
        get = function() return SSF.db.profile.announce end,
        apply = function(value) SSF.db.profile.announce = value end,
    })
    logGui.order = 2 -- GUI only: Other is minimap, log deletions, How shards move, language; the chat order stays

    -- "/ssf announce", the old word for "/ssf log": the same command, hidden from the help
    -- list and from Tab, so old macros keep working. The handler below lets it through.
    local announceOld = {}
    for field, value in pairs(logCmd) do announceOld[field] = value end
    announceOld.cmdHidden = true

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
        order = 3, kind = "range",
        name = L["Low shard mark"],
        min = Cap().MIN, max = Cap().MAX, step = 1,
        get = function() return Cap():LowMark() end,
        apply = function(value) Cap():SetLowMark(value) end, -- Cap holds it at or under the cap
    })
    lowmarkGui.arg = function() return Cap():Get() end

    -- GUI only (no chat command): the pause sound's notch, Sounds' scale of 0 (off) to 1,
    -- shown as a percentage. Never greyed, so it can be set before SSF is paused. The
    -- preview plays once at the let-go, not on every drag tick (the slider's `released`,
    -- SSFStepperSlider, fed through `arg`); at 0% it is silent, which is Sounds' call.
    -- A gold tick marks each notch on the bar (the slider's `notches`). While the sound
    -- plays the game refuses to start it again, so the "-" and "+" are greyed until it
    -- ends (the slider's `busy`, Sounds:Busy): every click that can be made is heard.
    -- Under the bar's ends it says "Off" and "Max" (the slider's `ends`), so 0% reads as
    -- off without the help; the value box keeps the percentage.
    local pausesoundGui = Settings:Define("pausesound", {
        order = 2, kind = "range",
        name = L["Sound volume"],
        min = 0, max = 1, step = Sounds():LevelStep(),
        get = function() return SSF.db.profile.pauseSoundLevel end,
        apply = function(value) SSF.db.profile.pauseSoundLevel = value end,
    })
    pausesoundGui.isPercent = true
    pausesoundGui.arg = {
        released = function() Sounds():PlayPause() end,
        notches = true,
        busy = function() return Sounds():Busy() end,
        ends = { low = L["Off"], high = L["Max"] },
    }

    local args = {
        -- the top row: the count, with Delete Shard right after it, so a click and the number
        -- it changes sit together (Widgets\SSFCentered.lua). A mouse click is the hardware
        -- event Trimmer:Delete needs. Its help is every way to delete (DeleteHelp).
        -- Greyed whenever a click could not delete (Trimmer:WhyNot), with the reason on its
        -- face, so a click that does nothing never looks like a broken button.
        deletebutton = {
            type = "execute",
            order = 0,
            width = "full",
            cmdHidden = true,
            dialogControl = "SSFCountButton",
            name = L["Delete Shard"],
            -- greyed, the tooltip is only why (deliberate wording); live, it teaches
            -- every way to delete
            desc = function()
                local why = SSF:GetModule("Trimmer"):WhyNot()
                if why == "paused" then return L["Nothing to delete, SSF is paused."] end
                if why == "quiet" then return L["Nothing to delete, no Drain Soul yet."] end
                if why == "locked" then return L["Can't delete yet, a shard is locked."] end
                if why then return L["Nothing to delete, you are at or under the cap."] end
                return SSF:GetModule("DeleteHelp"):Text(L["SSF deletes one Soul Shard when you're over the cap. Use the %s keybind, this button, a macro, or mix and match."]:format(L["Delete Shard"]))
            end,
            arg = function()
                local why = SSF:GetModule("Trimmer"):WhyNot()
                -- an answer with no text of its own (a new one WhyNot learns) shows "cap is N"
                -- rather than erroring on every redraw; tests/test_options.lua fails on it first
                return Status():CountText(), why and (BLOCKER_TEXT[why] or CapIs)(), AllBlockers()
            end,
            disabled = function() return SSF:GetModule("Trimmer"):WhyNot() ~= nil end,
            func = function() SSF:GetModule("Trimmer"):Delete() end,
        },

        -- a blank line between each pair of groups
        gap0 = Gap(3), gap1 = Gap(7), gap2 = Gap(15), gap3 = Gap(35),

        -- keyed pausegroup: "pause" is the chat command's key in this same table
        pausegroup = {
            type = "group", inline = true, order = 5, cmdHidden = true,
            name = L["Pause SSF"],
            args = {
                pauseGui = pauseGui,
                pausesound = pausesoundGui,
                -- the chat line hangs off the pause box: indented one step, greyed while not
                -- paused (its value is kept)
                pauselog = Toggle(4, L["Log pauses to chat"],
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
            name = L["Soul shard limits"],
            args = {
                setmaxGui = setmaxGui,
                automax = Toggle(2, -- left-aligned like every other checkbox
                    L["Match soul bag size"],
                    function() return SSF.db.profile.autoMax end,
                    function(_, value)
                        SSF.db.profile.autoMax = value
                        Cap():Recompute()
                        changed("automax")
                    end,
                    function() return not Bags():HasSoulBag() end),
                -- the two sliders sit together. The low mark sets where red starts everywhere
                -- (bag, tooltip, window, chat), so it is never greyed
                lowmark = lowmarkGui,
            },
        },

        bagcount = {
            type = "group", inline = true, order = 30, cmdHidden = true,
            name = L["Soul shard counter"],
            args = {
                counter = Toggle(1, L["Show shard counter on bag bar"],
                    function() return SSF.db.profile.counter end,
                    function(_, value)
                        SSF.db.profile.counter = value
                        changed("counter")
                    end),
                -- where the number sits, first under the count checkbox, side by side: far-left
                -- bag, or a soul bag. Both grey with the count off; Soul bag also greys while no soul
                -- bag is equipped (the dot is then on Far-left bag, see PlaceRadio)
                placeleft = PlaceRadio(2, L["Far-left bag"], false, CounterOff),
                placesoul = PlaceRadio(3, L["Soul bag"], true,
                    function() return CounterOff() or not Bags():HasSoulBag() end, true),
                -- the glow is part of the bag display: it sits on the counter's button and
                -- runs only while the count shows (LowGlow). After Colorize: both follow
                -- the low mark
                lowglow = Toggle(5, L["Glow bag button when low"],
                    function() return SSF.db.profile.lowGlow end,
                    function(_, value)
                        SSF.db.profile.lowGlow = value
                        changed("lowglow")
                    end,
                    CounterOffOrPaused),
                -- the place radios hang off the count checkbox, one step in; colorize and glow
                -- line up under the count checkbox itself, under the radios' half line
                colorize = Toggle(4, L["Colorize bag counter"],
                    function() return SSF.db.profile.counterColorize end,
                    function(_, value)
                        SSF.db.profile.counterColorize = value
                        changed("countercolorize")
                    end,
                    CounterOffOrPaused),
                -- LibSharedMedia supplies the font list; the AceGUI SharedMedia widget draws
                -- the dropdown with previews. Size auto-fits the button.
                font = {
                    type = "select",
                    order = 6,
                    width = "full",
                    cmdHidden = true,
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

        other = {
            type = "group", inline = true, order = 40, cmdHidden = true,
            name = L["Other settings"],
            args = {
                -- How shards move: SSF Mode, or a sort in top down or bottom up
                -- order (soulsortLegacy, soulsortReverse). What each choice does is in its help
                -- line, with the others' (help table below). SSF Mode leaves soulsortReverse as it is.
                shardmode = {
                    type = "select",
                    order = 3,
                    width = "full",
                    cmdHidden = true,
                    name = L["How shards move"],
                    values = {
                        ssf = L["SSF Mode"],
                        normal = L["Sort top down"],
                        reverse = L["Sort bottom up"],
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
                logGui = logGui,
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
        log = logCmd,
        [OLD_LOG_WORD] = announceOld,
        [DEBUG_WORD] = {
            type = "input",
            order = 90,
            dialogHidden = true,
            cmdHidden = true,
            name = "Debug",
            desc = "The debug record's command.",
            get = function() return "" end,
            set = function(_, input) SSF:GetModule("DebugCommand"):Run(input) end,
        },
        pause = pauseCmd,
        delete = {
            type = "execute",
            order = 1,
            dialogHidden = true,
            name = L["Delete Shard"],
            desc = Colors():Commands(L["Deletes one Soul Shard if you are over the cap. In a macro, put /ssf delete on the line before the ability."]),
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

    -- Help lines: each option's tooltip while help mode is on (Help:Apply), by group and key.
    -- The cap, Pause and Log lines come with their Settings:Define above. Plain
    -- sentences: the tooltip wraps them itself. Only How shards move keeps one line per choice.
    local lowMarkName = L["Low shard mark"] -- quoted by name in two lines, in the player's language
    local bullet = "\226\128\162 "     -- "• "
    local help = {
        pausegroup = {
            pausesound = L["How loud the pause sound plays. 0% turns it off. Let go to hear it."],
            pauselog = L["Each press while paused prints a chat line."],
        },
        cap = {
            automax = L["Sets cap automatically to the size of all soul bags (one or multiple)."],
            lowmark = L["If shard count is lower than this, you will be notified with a red color change (and glow if enabled)."],
        },
        bagcount = {
            counter = L["Shows your shard count on a bag button (soul bag by default, left bag slot otherwise)."],
            lowglow = L['The bag button glows while you are below "%s".']:format(lowMarkName),
            -- the three color words in the bag's own state colors, so the line shows what it teaches
            colorize = L['%s when below "%s", %s in range, and %s over the cap.']:format(
                Colors():PaintState("low", L["Red"]), lowMarkName,
                Colors():PaintState("ok", L["green"]), Colors():PaintState("over", L["yellow"])),
            placeleft = L["Keeps the counter on your far-left bag."],
            placesoul = L["Moves the counter to your soul bag, whatever slot it's in."],
            font = L["The font used on the shard counter."],
        },
        other = {
            -- the intro, then one bullet per choice with a blank line between, each led by
            -- the choice's own name: SSF Mode in the state green (the safe pick, it moves
            -- nothing else), the sort ones in neutral gold
            shardmode = L["How a macro or keybind moves shards."] .. " " .. L["Shards move to soul bag."]
                .. "\n\n" .. bullet .. Colors():State(L["SSF Mode"] .. ":", true) .. " "
                .. L["SSF does not sort (does NOT change item positions in bags)."]
                .. "\n\n" .. bullet .. Gold(L["Sort top down"] .. ":") .. " "
                .. L["Shards fill from the top (CHANGES item positions in your bags)."]
                .. "\n\n" .. bullet .. Gold(L["Sort bottom up"] .. ":") .. " "
                .. L["Shards fill from the bottom (CHANGES item positions in your bags)."],
            minimap = L["Enables SSF minimap icon."],
            language = L["Auto uses game client language."],
        },
    }
    for group, lines in pairs(help) do
        for key, text in pairs(lines) do args[group].args[key].desc = text end
    end

    local root = { type = "group", name = L["Soul Shards Forever"], args = args }
    SSF:GetModule("Help"):Apply(root) -- every option's tooltip style, per help mode
    return root
end

-- True for a word that asks for the command list: the help word or its short form.
function Options:IsHelpWord(word)
    return HELP_WORDS[word] == true
end

-- What a word typed after /ssf is: "listed" (a root entry AceConfigCmd shows, or the help
-- word, listed with them), "hidden" (a command that works but is never
-- listed or offered: HIDDEN_WORDS), or nil (not a command). SlashCommand's unknown-word
-- check and TabComplete's list both ask this, so the two can never disagree.
function Options:ChatWord(word)
    if word == HELP_WORD then return "listed" end
    if HIDDEN_WORDS[word] then return "hidden" end
    local entry = self.table.args[word]
    if entry ~= nil and not entry.cmdHidden then return "listed" end
end

-- Every listed chat word, the help word included, sorted.
function Options:ChatWords()
    local list = { HELP_WORD }
    for key in pairs(self.table.args) do
        if key ~= HELP_WORD and self:ChatWord(key) == "listed" then list[#list + 1] = key end
    end
    table.sort(list)
    return list
end

-- "/ssf 25": runs setmax's own chat command with the number typed alone, marked short, so
-- Settings checks the range and a bad value answers in the short form ("Use: /ssf 1-100").
-- ON PURPOSE, not a bypass of AceConfigCmd (a review flagged it as "Ace first"; it was
-- kept deliberately): AceConfigCmd can only dispatch "setmax 25", and then has
-- no way to say the player typed the short form, so the usage line would name setmax.
-- Calling a setting's own `set` is this file's way to run a chat command from code
-- (TogglePause does the same for the key binding). Nothing Ace does is redone here; the
-- third argument, short, is Settings' documented extension.
function Options:SetCapShortForm(input)
    self.table.args.setmax.set(nil, input, true)
end

-- Setup lives in OnEnable, not OnInitialize: Ace3 runs every module's OnInitialize even when
-- Core's warlock gate has switched the module off. /ssf is SlashCommand's, Tab is
-- TabComplete's; both read this table through ChatWord and ChatWords.
function Options:OnEnable()
    self.table = BuildTable()
    AceConfig:RegisterOptionsTable(APP, self.table) -- no slashcmd: SlashCommand registers /ssf
    -- once: AceConfigDialog refuses a second entry under the same name, so an OnEnable that
    -- runs again (the module switched off and on) keeps the first
    if not self.inBlizOptions then
        AceConfigDialog:AddToBlizOptions(APP, L["Soul Shards Forever"])
        self.inBlizOptions = true
    end
    self:RegisterMessage("SSF_HELP_CHANGED", "Rebuild")
end

-- After a Language change or a help toggle (SSF_HELP_CHANGED): the table captured its
-- strings and its tooltip style when built, so build it again and re-register
-- (AceConfigRegistry replaces by app name). Window resets
-- the window's own strings and redraws on SSF_OPTIONS_REBUILT. The Interface Options
-- category keeps the name it was added under until a reload.
function Options:Rebuild()
    self.table = BuildTable()
    AceConfig:RegisterOptionsTable(APP, self.table)
    self:SendMessage("SSF_OPTIONS_REBUILT")
end
