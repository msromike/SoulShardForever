-- Soul Shard Forever (SSF). MIT, see LICENSE.
--
-- Settings: turns ONE definition of a stateful setting into the two AceConfig entries it
-- needs: a GUI control (toggle or range, hidden from chat) and a chat command (hidden from
-- the GUI) that share the same get/apply.
--
-- Chat rule it enforces for every stateful command: typed naked it reports the current
-- value; typed with a value it applies and echoes the new one; booleans show green ON /
-- red OFF. AceConfigCmd cannot do that by itself (a naked toggle flips, a naked range
-- errors), which is the only reason this module exists.
--
-- Takes:   Settings:Define(key, def) where def = { order, kind = "toggle"|"range", name,
--          desc, get(), apply(value), optional extra() -> text appended to the chat echo,
--          and for range: min, max, step, disabled }.
--          Settings:Value(v) -> v as the green value string used everywhere.
-- Returns: gui, cmd -- two entries for Options to place in its args table.
-- Sends:   SSF_OPTIONS_CHANGED with the key after every apply.
-- Registers: AceTab completion of "on"/"off" after "/ssf <key> " for every toggle.
-- Prints:  through AceConsole only. Owns no state, no events, no frames.

local ADDON = "SoulShardForever"
local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Settings = SSF:NewModule("Settings", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)
local AceTab = LibStub("AceTab-3.0")

local GREEN, RED = "|cff00ff00%s|r", "|cffff0000%s|r"
local function OnOff(b) return b and GREEN:format(L["ON"]) or RED:format(L["OFF"]) end

-- The one way a value is colored in chat and in the window: green. Other modules use it
-- so every number reads the same.
function Settings:Value(v) return GREEN:format(tostring(v)) end

-- AceTab usage callback shared by every completion set: on an ambiguous Tab, list the
-- candidates on one line. (Passing `true` instead trips a nil concat inside AceTab when
-- two or more words match, so every registration uses this.)
function Settings.TabUsage(_, matches)
    local words = {}
    for word in pairs(matches) do words[#words + 1] = word end
    table.sort(words)
    return table.concat(words, "  ")
end

-- Reads "on"/"off" (toggle) or a number in range (range) from chat input.
-- Returns the value, or nil and a usage line.
local function Parse(key, def, input)
    if def.kind == "toggle" then
        if input == "on" or input == "true" then return true end
        if input == "off" or input == "false" then return false end
        return nil, L["Use: /ssf %s on|off"]:format(key)
    end
    local value = tonumber(input)
    if not value or value < def.min or value > def.max then
        return nil, L["Use: /ssf %s %d-%d"]:format(key, def.min, def.max)
    end
    return value
end

function Settings:Define(key, def)
    local function echo()
        local shown = def.kind == "toggle" and OnOff(def.get()) or self:Value(def.get())
        local extra = def.extra and (" " .. def.extra()) or ""
        SSF:Printf("%s: %s%s", def.name, shown, extra)
    end
    local function set(value)
        def.apply(value)
        self:SendMessage("SSF_OPTIONS_CHANGED", key)
    end

    local gui = {
        type = def.kind,
        order = def.order,
        cmdHidden = true,
        descStyle = "hidden",
        name = def.name,
        get = function() return def.get() end,
        set = function(_, value) set(value) end,
        disabled = def.disabled,
    }
    if def.kind == "range" then
        gui.min, gui.max, gui.step = def.min, def.max, def.step
        gui.width = "full"
        gui.dialogControl = "SSFStepperSlider" -- Widgets\SSFStepperSlider.lua: arrows on both edges
    else
        -- "/ssf announce o<Tab>" completes the value word too
        AceTab:RegisterTabCompletion("SSF " .. key, "/ssf " .. key .. " ", { "on", "off" }, Settings.TabUsage)
    end

    local cmd = {
        type = "input",
        order = def.order,
        dialogHidden = true,
        name = def.name,
        desc = def.desc,
        get = function() return "" end,
        set = function(_, input)
            input = strtrim(input or ""):lower()
            if input == "" then echo() return end
            local value, usage = Parse(key, def, input)
            if value == nil then SSF:Print(usage) return end
            set(value)
            echo()
        end,
    }
    return gui, cmd
end
