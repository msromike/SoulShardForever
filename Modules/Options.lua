-- Soul Shard Forever (SSF). MIT, see LICENSE.
--
-- Options: the one settings table. AceConfigCmd turns it into the /ssf commands, AceConfigDialog
-- turns the same table into the options window and the Interface Options entry, AceTab
-- completes the command words. Keys are the slash words; GUI-only entries carry cmdHidden.
-- Modules that show state (Counter, Broker) listen for SSF_OPTIONS_CHANGED.
--
-- Window layout: status line, then three inline groups (Cap, Bag count, Low shard glow) and
-- Other, then a small version/credit line. Every toggle is full width so no label truncates.
-- Chat commands live at the root of the table (AceConfigCmd keys) and are hidden from the
-- window; their GUI twins live inside the groups.
--
-- Stateful settings (cap, announce) are defined once through the Settings module, which
-- returns the GUI control and the chat command for each; see Modules\Settings.lua for the
-- chat rule (naked = report, with value = apply and echo). Adding one = one Define() call.

local ADDON = "SoulShardForever" -- the folder: TOC metadata and the locale
local APP = "SSF"                -- the AceConfig app: every line AceConfigCmd prints is prefixed with it
local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Options = SSF:NewModule("Options", "AceEvent-3.0", "AceBucket-3.0")
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

local function changed(key)
    Options:SendMessage("SSF_OPTIONS_CHANGED", key)
end

-- a full-width, GUI-only, tooltip-free checkbox, indented 10px inside its group unless
-- `control` names another dialogControl (see Widgets\SSFCentered.lua)
local function Toggle(order, name, get, set, disabled, control)
    return {
        type = "toggle", order = order, width = "full",
        cmdHidden = true, descStyle = "hidden", dialogControl = control or "SSFIndentCheckBox",
        name = name, get = get, set = set, disabled = disabled,
    }
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
    announceGui.width = "full"
    announceGui.dialogControl = "SSFIndentCheckBox"

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

        cap = {
            type = "group", inline = true, order = 10, cmdHidden = true,
            name = L["Soul shard cap"],
            args = {
                setmaxGui = setmaxGui,
                automax = Toggle(2, -- centered in its row, see Widgets\SSFCentered.lua
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
                    function() return Bags():SoulBagSlots() == 0 end,
                    "SSFCenteredCheckBox"),
            },
        },

        bagcount = {
            type = "group", inline = true, order = 20, cmdHidden = true,
            name = L["Shards in bag count"],
            args = {
                counter = Toggle(1, L["Show shard count on bag bar"],
                    function() return SSF.db.profile.counter end,
                    function(_, value)
                        SSF.db.profile.counter = value
                        changed("counter")
                    end),
                colorize = Toggle(2, L["Colorize bag count"],
                    function() return SSF.db.profile.counterColorize end,
                    function(_, value)
                        SSF.db.profile.counterColorize = value
                        changed("countercolorize")
                    end,
                    function() return not SSF.db.profile.counter end),
                -- LibSharedMedia supplies the font list; the AceGUI SharedMedia widget draws
                -- the dropdown with previews. Size auto-fits the button.
                font = {
                    type = "select",
                    order = 3,
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

        glow = {
            type = "group", inline = true, order = 30, cmdHidden = true,
            name = L["Low shard glow"],
            args = {
                lowglow = Toggle(1, L["Glow bag button when low"],
                    function() return SSF.db.profile.lowGlow end,
                    function(_, value)
                        SSF.db.profile.lowGlow = value
                        changed("lowglow")
                    end),
                lowmark = {
                    type = "range",
                    order = 2,
                    cmdHidden = true,
                    descStyle = "hidden",
                    name = L["Low shard warn"],
                    min = 1, max = 20, step = 1,
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
                announceGui = announceGui,
                minimap = Toggle(2, L["Minimap button"],
                    function() return not SSF.db.profile.minimap.hide end,
                    function(_, value)
                        SSF.db.profile.minimap.hide = not value
                        changed("minimap")
                    end),
            },
        },

        -- chat commands, hidden from the window
        setmax = setmaxCmd,
        announce = announceCmd,
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
function Options:OnEnable()
    local options = BuildTable()
    AceConfig:RegisterOptionsTable(APP, options) -- no slashcmd here: /ssf is registered below
    -- /ssf: naked prints the status line, then AceConfigCmd's command list; anything else
    -- goes straight to AceConfigCmd, which parses and dispatches to the table.
    SSF:RegisterChatCommand("ssf", function(input)
        if strtrim(input or "") == "" then SSF:Print(Options:StatusText()) end
        AceConfigCmd:HandleCommand("ssf", APP, input)
    end)
    AceConfigDialog:SetDefaultSize(APP, 310, 590)
    AceConfigDialog:AddToBlizOptions(APP, L["Soul Shard Forever"])

    -- Tab completion in the chat box: "/ssf del<Tab>" -> "/ssf delete". Only the words
    -- AceConfigCmd exposes (root entries without cmdHidden).
    AceTab:RegisterTabCompletion("SSF", "/ssf ", function(words)
        for key, entry in pairs(options.args) do
            if not entry.cmdHidden then words[#words + 1] = key end
        end
    end, SSF:GetModule("Settings").TabUsage)

    self:RegisterMessage("SSF_SHARD_DELETED", "Refresh")
    self:RegisterBucketEvent({ "BAG_UPDATE", "BAG_CONTAINER_UPDATE" }, 0.5, "Refresh")
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
        AceConfigDialog:Open(APP, self.window)
    end
end

-- The small standalone window: minimap click, /ssf options, /ssf settings. Our own
-- SSFWindow container (X button, no status bar, sized to content), created once and
-- re-fed on every open.
function Options:Open()
    if not self.window then
        self.window = LibStub("AceGUI-3.0"):Create("SSFWindow")
        -- bottom row: Delete Shard far left, version and credit in the middle, Close far right
        self.window:SetActionButton(L["Delete Shard"], function() SSF:GetModule("Trimmer"):Delete() end)
        local version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
        self.window:SetFooter("v" .. version .. "  " .. L["Started as a fork of SoulSort by Anilusion."])
    end
    AceConfigDialog:Open(APP, self.window)
end
