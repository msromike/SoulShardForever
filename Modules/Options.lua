-- Soul Shard Forever (SSF). GPLv3, see LICENSE.
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
local AceTab = LibStub("AceTab-3.0")

local function Cap() return SSF:GetModule("Cap") end
local function Bags() return SSF:GetModule("Bags") end

local function Value(v) return SSF:GetModule("Settings"):Value(v) end

-- The one count/cap wording, used by the window and the announce line. Values green.
function Options:StatusText()
    return L["Soul Shards: %s (cap %s)"]:format(Value(Bags():Count()), Value(Cap():Get()))
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
                return L["Soul Shard Forever"] .. " " .. version .. "\n" .. L["Fork of SoulSort by Anilusion. GPLv3."] .. "\n"
            end,
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
    AceConfig:RegisterOptionsTable(ADDON, options, "ssf")
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
function Options:Refresh()
    AceConfigRegistry:NotifyChange(ADDON)
end

function Options:OnEnable()
    self:RegisterMessage("SSF_SHARD_DELETED", "Refresh")
    self:RegisterBucketEvent({ "BAG_UPDATE", "BAG_CONTAINER_UPDATE" }, 0.5, "Refresh")
end

-- The small standalone window: minimap click, /ssf options, the Options button.
function Options:Open()
    AceConfigDialog:Open(ADDON)
end
