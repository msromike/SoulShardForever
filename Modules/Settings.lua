-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Settings: turns ONE definition of a stateful setting into the two AceConfig entries it
-- needs: a GUI control (toggle or range, hidden from chat) and a chat command (hidden from
-- the GUI) that share the same get/apply. The GUI control carries SSF's look: full width,
-- the indented check box for a toggle, the stepper slider for a range.
--
-- Chat rule it enforces for every stateful command: typed naked it reports the current
-- value; typed with a value it applies and echoes the new one; booleans show green ON /
-- red OFF. AceConfigCmd cannot do that by itself (a naked toggle flips, a naked range
-- errors), which is the only reason this module exists (Parse below is that rule, not a
-- copy of AceConfigCmd's parsing).
--
-- Public:  Settings:Define(key, def) where def = { order, kind = "toggle"|"range", name,
--          desc, get(), apply(value), optional extra() -> text appended to the chat echo,
--          optional echo() -> the whole echo line in place of "name: value" (pause),
--          optional disabled, and for range: min, max, step }.
--          Returns gui, cmd -- two entries for Options to place in its args table; a
--          GUI-only setting places gui and drops cmd.
--          A toggle's Define also registers AceTab completion of "on"/"off" after
--          "/ssf <key> ".
--          Settings.TabUsage -- the AceTab usage callback every completion set shares
--          (Options uses it for the command words too).
-- Sends:   SSF_OPTIONS_CHANGED with the key after every apply, plus "chat" when the chat
--          command applied it (Window redraws an open window only then).
-- Reads:   Colors:OnOff/Value for the echo. Prints through AceConsole only.
-- Owns no state, no events, no frames. Touches nothing else.

local ADDON = ...
local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Settings = SSF:NewModule("Settings", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)
local AceTab = LibStub("AceTab-3.0")

local function Colors() return SSF:GetModule("Colors") end

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
        if def.echo then SSF:Print(def.echo()) return end
        local shown = def.kind == "toggle" and Colors():OnOff(def.get()) or Colors():Value(def.get())
        local extra = def.extra and (" " .. def.extra()) or ""
        SSF:Printf("%s: %s%s", def.name, shown, extra)
    end
    local function set(value, source)
        def.apply(value)
        self:SendMessage("SSF_OPTIONS_CHANGED", key, source)
    end

    local gui = {
        type = def.kind,
        order = def.order,
        width = "full",
        cmdHidden = true,
        descStyle = "hidden", -- Options.lua's ApplyHelp shows desc as a tooltip in help mode
        name = def.name,
        desc = def.desc,
        get = function() return def.get() end,
        set = function(_, value) set(value) end,
        disabled = def.disabled,
    }
    if def.kind == "range" then
        gui.min, gui.max, gui.step = def.min, def.max, def.step
        gui.dialogControl = "SSFStepperSlider" -- Widgets\SSFStepperSlider.lua: "-" and "+" buttons at the value box
    else
        gui.dialogControl = "SSFIndentCheckBox" -- Widgets\SSFCentered.lua: inset in its group
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
            set(value, "chat")
            echo()
        end,
    }
    return gui, cmd
end
