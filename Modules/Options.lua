-- Soul Shard Forever (SSF). GPLv3, see LICENSE.
--
-- Options: the one settings table. AceConfigCmd turns it into the /ssf commands and
-- AceConfigDialog (Stage 2) turns the same table into the options window and the
-- Interface Options entry. Keys are the slash words; GUI-only entries carry cmdHidden.
-- Modules that show state (Counter, Broker) listen for SSF_OPTIONS_CHANGED.

local ADDON = "SoulShardForever"
local SSF = LibStub("AceAddon-3.0"):GetAddon(ADDON)
local Options = SSF:NewModule("Options", "AceEvent-3.0", "AceBucket-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local function Cap() return SSF:GetModule("Cap") end
local function Bags() return SSF:GetModule("Bags") end

-- The one count/cap wording, used by the window, the announce line and the broker text.
function Options:StatusText()
    return L["Soul Shards: %d (cap %d)"]:format(Bags():Count(), Cap():Get())
end

local function changed(key)
    Options:SendMessage("SSF_OPTIONS_CHANGED", key)
end

local function BuildTable()
    return {
        type = "group",
        name = L["Soul Shard Forever"],
        args = {
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
                descStyle = "hidden", -- no hover tooltip; desc still feeds /ssf
                order = 10,
                name = L["Delete Shard"],
                desc = L["Delete one Soul Shard if you are over the cap. In a macro, put /ssf delete on the line before the ability."],
                func = function() SSF:GetModule("Trimmer"):Delete() end,
            },
            setmax = {
                type = "range",
                descStyle = "hidden", -- no hover tooltip; desc still feeds /ssf
                order = 20,
                name = L["Shards to keep"],
                desc = L["The cap. Shards over this number are deleted one per press."],
                min = Cap().MIN, max = Cap().MAX, step = 1,
                width = "full",
                dialogControl = "SSFStepperSlider", -- Widgets\SSFStepperSlider.lua: arrows on both edges
                get = function() return Cap():Get() end,
                set = function(_, value)
                    SSF.db.profile.autoMax = false
                    Cap():SetManual(value)
                    changed("setmax")
                end,
                -- greyed in the GUI while AutoMax binds to a soul bag; the slash form always works
                disabled = function(info) return info.uiType ~= "cmd" and Cap():IsAuto() end,
            },
            automax = {
                type = "toggle",
                descStyle = "hidden", -- no hover tooltip; desc still feeds /ssf
                order = 30,
                cmdHidden = true,
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
                descStyle = "hidden", -- no hover tooltip; desc still feeds /ssf
                order = 40,
                cmdHidden = true,
                name = L["Show shard count on bag bar"],
                desc = L["One number on the far-left bag button, red when over the cap."],
                get = function() return SSF.db.profile.counter end,
                set = function(_, value)
                    SSF.db.profile.counter = value
                    changed("counter")
                end,
            },
            announce = {
                type = "toggle",
                descStyle = "hidden", -- no hover tooltip; desc still feeds /ssf
                order = 50,
                name = L["Announce deletions in chat"],
                desc = L["One chat line per deleted shard, for addons that watch chat."],
                get = function() return SSF.db.profile.announce end,
                set = function(_, value)
                    SSF.db.profile.announce = value
                    changed("announce")
                end,
            },
            minimap = {
                type = "toggle",
                descStyle = "hidden", -- no hover tooltip; desc still feeds /ssf
                order = 60,
                cmdHidden = true,
                name = L["Minimap button"],
                get = function() return not SSF.db.profile.minimap.hide end,
                set = function(_, value)
                    SSF.db.profile.minimap.hide = not value
                    changed("minimap")
                end,
            },
            options = {
                type = "execute",
                descStyle = "hidden", -- no hover tooltip; desc still feeds /ssf
                order = 70,
                dialogHidden = true,
                name = L["Open options"],
                desc = L["Open the options window."],
                func = function() Options:Open() end,
            },
        },
    }
end

function Options:OnInitialize()
    AceConfig:RegisterOptionsTable(ADDON, BuildTable(), "ssf")
    AceConfigDialog:SetDefaultSize(ADDON, 420, 380)
    AceConfigDialog:AddToBlizOptions(ADDON, L["Soul Shard Forever"])
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
