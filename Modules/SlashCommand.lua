-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- SlashCommand: /ssf itself. Naked it opens the window (open only, never a toggle) and
-- prints the pause line, the status line and a pointer to help. "/ssf help" or "/ssf ?"
-- prints AceConfigCmd's command list. A whole number on its own sets the cap, as setmax.
-- An unknown first word prints one error line, then the list. Anything else goes straight
-- to AceConfigCmd, which parses it and dispatches to Options' table.
--
-- It wraps AceConfigCmd instead of letting AceConfigCmd register /ssf: AceConfigCmd's
-- dispatch ignores cmdHidden, has no "help" word, and would not open the window on a bare
-- /ssf. Every typed command is echoed first, in grey after a "> " prompt, the way a
-- terminal does (WoW's chat never shows the slash command typed), except "delete": macros
-- run it before every cast, and an echo there would flood chat. Which words are commands,
-- listed or hidden, is Options' answer (ChatWord).
--
-- Public:  none; the game calls the handler through /ssf.
-- Reads:   Options:ChatWord/SetCapShortForm and Options.APP, Window:Open,
--          Status:PrintStatus, Colors:Echo.
-- Acts on: the slash command /ssf (AceConsole's RegisterChatCommand, on the addon object).
-- Touches nothing else.

local ADDON = ...
local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local SlashCommand = SSF:NewModule("SlashCommand")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)
local AceConfigCmd = LibStub("AceConfigCmd-3.0")

local function Options() return SSF:GetModule("Options") end

local function HandleCommand(input)
    local APP = Options().APP
    input = strtrim(input or "")
    local first = (input:match("^(%S+)") or ""):lower()
    if first ~= "delete" then
        SSF:Print(SSF:GetModule("Colors"):Echo("> /ssf" .. (input ~= "" and (" " .. input) or "")))
    end
    if input == "" then
        SSF:GetModule("Window"):Open()
        SSF:GetModule("Status"):PrintStatus()
        SSF:Print(L["Type /ssf help for commands."])
        return
    end
    if first == "help" or first == "?" then
        AceConfigCmd:HandleCommand("ssf", APP, "")
        return
    end
    -- a whole number on its own is the cap: "/ssf 32" is "/ssf setmax 32" (a player's ask,
    -- 2026-11-16). Options runs setmax's own command, marked short, so Settings checks the
    -- range and answers a bad value in the short form the player typed. Why not through
    -- AceConfigCmd: Options:SetCapShortForm says.
    if input:match("^%d+$") then
        Options():SetCapShortForm(input)
        return
    end
    if not Options():ChatWord(first) then
        SSF:Print(L['Unknown command "%s".']:format(first))
        AceConfigCmd:HandleCommand("ssf", APP, "")
        return
    end
    AceConfigCmd:HandleCommand("ssf", APP, input)
end

-- Setup lives in OnEnable, not OnInitialize: Core's warlock gate switches modules off before
-- OnEnable, so /ssf never registers on other classes.
function SlashCommand:OnEnable()
    SSF:RegisterChatCommand("ssf", HandleCommand)
end
