-- Soul Shard Forever (SSF). MIT, see LICENSE.
--
-- Options: the one settings table. AceConfigCmd turns it into the /ssf commands, AceConfigDialog
-- turns the same table into the options window and the Interface Options entry, AceTab
-- completes the command words. Keys are the slash words; GUI-only entries carry cmdHidden.
-- Modules that show state (Counter, Broker) listen for SSF_OPTIONS_CHANGED.
--
-- Stateful settings (cap, announce) are defined once through the Settings module, which
-- returns the GUI control and the chat command for each; see Modules\Settings.lua for the
-- chat rule (naked = report, with value = apply and echo). Adding one = one Define() call.

local ADDON = "SoulShardForever"
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
-- the counter's state color (grey / green / yellow, or white when colorizing is off) so the
-- window shows the effect of a cap change without looking at the bag; the cap is green.
function Options:StatusText()
    local count, cap = Bags():Count(), Cap():Get()
    local _, _, _, hex = SSF:GetModule("Counter"):StateColor(count, cap)
    return L["Soul Shards: %s (cap %s)"]:format("|cff" .. hex .. count .. "|r", Value(cap))
end

local function changed(key)
    Options:SendMessage("SSF_OPTIONS_CHANGED", key)
end

local function BuildTable()
    local args = {
        header = {
            type = "description",
            order = 0,
            cmdHidden = true,
            fontSize = "medium",
            name = function()
                local version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
                return L["Soul Shard Forever"] .. " " .. version .. "\n"
            end,
        },
        credit = { -- small, last
            type = "description",
            order = 999,
            cmdHidden = true,
            fontSize = "small",
            name = function() return "\n" .. L["Started as a fork of SoulSort by Anilusion. Rewritten from scratch."] end,
        },
        status = {
            type = "description",
            order = 5,
            cmdHidden = true,
            fontSize = "large",
            name = function() return Options:StatusText() .. "\n" end,
        },
        delete = {
            type = "execute",
            order = 10,
            descStyle = "hidden",
            name = L["Delete Shard"],
            desc = L["Delete one Soul Shard if you are over the cap. In a macro, put /ssf delete on the line before the ability."],
            func = function() SSF:GetModule("Trimmer"):Delete() end,
        },
        automax = {
            type = "toggle",
            order = 30,
            cmdHidden = true,
            descStyle = "hidden",
            name = function()
                if Bags():SoulBagSlots() > 0 then return L["Match soul bag size"] end
                return L["Match soul bag size (no soul bag equipped)"]
            end,
            desc = L["While a soul bag is equipped, the cap is its slot count. Without one, the slider rules."],
            disabled = function() return Bags():SoulBagSlots() == 0 end,
            get = function() return SSF.db.profile.autoMax end,
            set = function(_, value)
                SSF.db.profile.autoMax = value
                Cap():Recompute()
                changed("automax")
            end,
        },
        counter = {
            type = "toggle",
            order = 40,
            cmdHidden = true,
            descStyle = "hidden",
            name = L["Show shard count on bag bar"],
            get = function() return SSF.db.profile.counter end,
            set = function(_, value)
                SSF.db.profile.counter = value
                changed("counter")
            end,
        },
        -- Counter look, GUI only. Size is auto-fit to the button.
        countercolorize = {
            type = "toggle",
            order = 41,
            cmdHidden = true,
            descStyle = "hidden",
            name = L["Colorize bag count"],
            get = function() return SSF.db.profile.counterColorize end,
            set = function(_, value)
                SSF.db.profile.counterColorize = value
                changed("countercolorize")
            end,
            disabled = function() return not SSF.db.profile.counter end,
        },
        -- LibSharedMedia supplies the font list; the AceGUI SharedMedia widget draws the
        -- dropdown with previews.
        counterfont = {
            type = "select",
            order = 42,
            cmdHidden = true,
            descStyle = "hidden",
            dialogControl = "LSM30_Font",
            name = L["Counter font"],
            values = LSM:HashTable("font"),
            get = function() return SSF.db.profile.counterFont end,
            set = function(_, value)
                SSF.db.profile.counterFont = value
                changed("counterfont")
            end,
            disabled = function() return not SSF.db.profile.counter end,
        },
        -- Low-shard glow, GUI only.
        lowglow = {
            type = "toggle",
            order = 46,
            cmdHidden = true,
            descStyle = "hidden",
            name = L["Glow bag button when low"],
            get = function() return SSF.db.profile.lowGlow end,
            set = function(_, value)
                SSF.db.profile.lowGlow = value
                changed("lowglow")
            end,
        },
        lowmark = {
            type = "range",
            order = 47,
            cmdHidden = true,
            descStyle = "hidden",
            name = L["Low mark"],
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
        minimap = {
            type = "toggle",
            order = 60,
            cmdHidden = true,
            descStyle = "hidden",
            name = L["Minimap button"],
            get = function() return not SSF.db.profile.minimap.hide end,
            set = function(_, value)
                SSF.db.profile.minimap.hide = not value
                changed("minimap")
            end,
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

    args.setmaxGui, args.setmax = SSF:GetModule("Settings"):Define("setmax", {
        order = 20, kind = "range",
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

    args.announceGui, args.announce = SSF:GetModule("Settings"):Define("announce", {
        order = 50, kind = "toggle",
        name = L["Announce deletions in chat"],
        desc = L["One chat line per deleted shard, for addons that watch chat."],
        get = function() return SSF.db.profile.announce end,
        apply = function(value) SSF.db.profile.announce = value end,
    })

    return { type = "group", name = L["Soul Shard Forever"], args = args }
end

function Options:OnInitialize()
    local options = BuildTable()
    AceConfig:RegisterOptionsTable(ADDON, options) -- no slashcmd here: /ssf is registered below
    -- /ssf: naked prints the status line, then AceConfigCmd's command list; anything else
    -- goes straight to AceConfigCmd, which parses and dispatches to the table.
    SSF:RegisterChatCommand("ssf", function(input)
        if strtrim(input or "") == "" then SSF:Print(Options:StatusText()) end
        AceConfigCmd:HandleCommand("ssf", ADDON, input)
    end)
    AceConfigDialog:SetDefaultSize(ADDON, 420, 380)
    AceConfigDialog:AddToBlizOptions(ADDON, L["Soul Shard Forever"])

    -- Tab completion in the chat box: "/ssf del<Tab>" -> "/ssf delete". Only the words
    -- AceConfigCmd exposes (entries without cmdHidden).
    AceTab:RegisterTabCompletion("SSF", "/ssf ", function(words)
        for key, entry in pairs(options.args) do
            if not entry.cmdHidden then words[#words + 1] = key end
        end
    end, SSF:GetModule("Settings").TabUsage)
end

-- Keep the status line and the AutoMax state fresh while a window is open.
-- NOT on SSF_CAP_CHANGED: AceConfigDialog calls the slider's set on every drag tick, and a
-- rebuild from inside that loop recreates the slider under the mouse. AceConfig already
-- refreshes after a release or a button click; the bag bucket covers everything else.
-- NotifyChange covers the Interface Options panel; the standalone window is our own
-- container, which AceConfigDialog does not track, so it is re-fed here while shown.
function Options:Refresh()
    AceConfigRegistry:NotifyChange(ADDON)
    if self.window and self.window.frame:IsShown() then
        AceConfigDialog:Open(ADDON, self.window)
    end
end

function Options:OnEnable()
    self:RegisterMessage("SSF_SHARD_DELETED", "Refresh")
    self:RegisterBucketEvent({ "BAG_UPDATE", "BAG_CONTAINER_UPDATE" }, 0.5, "Refresh")
end

-- The small standalone window: minimap click, /ssf options, /ssf settings. Our own
-- SSFWindow container (X button, no status bar, sized to content), created once and
-- re-fed on every open.
function Options:Open()
    if not self.window then
        self.window = LibStub("AceGUI-3.0"):Create("SSFWindow")
    end
    AceConfigDialog:Open(ADDON, self.window)
end
