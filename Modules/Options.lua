-- SoulStone Sort Forever (SSF). GPLv3, see LICENSE.
--
-- Options: the one settings table. AceConfigCmd turns it into the /ssf commands and
-- AceConfigDialog (Stage 2) turns the same table into the options window and the
-- Interface Options entry. Keys are the slash words; GUI-only entries carry cmdHidden.
-- Modules that show state (Counter, Broker) listen for SSF_OPTIONS_CHANGED.

local ADDON = "SoulStoneSortForever"
local SSF = LibStub("AceAddon-3.0"):GetAddon(ADDON)
local Options = SSF:NewModule("Options", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)
local AceConfig = LibStub("AceConfig-3.0")

local function Cap() return SSF:GetModule("Cap") end

local function changed(key)
    Options:SendMessage("SSF_OPTIONS_CHANGED", key)
end

local function BuildTable()
    return {
        type = "group",
        name = L["SoulStone Sort Forever"],
        args = {
            header = {
                type = "description",
                order = 0,
                cmdHidden = true,
                fontSize = "medium",
                name = function()
                    local version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
                    return L["SoulStone Sort Forever"] .. " " .. version .. "\n" .. L["Fork of SoulSort by Anilusion. GPLv3."] .. "\n"
                end,
            },
            delete = {
                type = "execute",
                order = 10,
                name = L["Delete Shard"],
                desc = L["Delete one Soul Shard if you are over the cap. In a macro, put /ssf delete on the line before the ability."],
                func = function() SSF:GetModule("Trimmer"):Delete() end,
            },
            setmax = {
                type = "range",
                order = 20,
                name = L["Shards to keep"],
                desc = L["The cap. Shards over this number are deleted one per press."],
                min = Cap().MIN, max = Cap().MAX, step = 1,
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
                order = 30,
                cmdHidden = true,
                name = L["Match soul bag size"],
                desc = L["While a soul bag is equipped, the cap is its slot count. Without one, the slider rules."],
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
end

-- Stage 2 replaces this with AceConfigDialog:Open.
function Options:Open()
    SSF:Print(L["The options window arrives in Stage 2."])
end
