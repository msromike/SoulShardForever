-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- DebugCommand: the words after "/ssf debug". Naked it reports the debug record's switch;
-- "on" and "off" set it and report; "mark <name>" writes a marker into the record, turning
-- the record on first when it is off (and saying so); "report" opens the copy window;
-- "clear" empties the saved record and says so. Anything else prints the usage line. What
-- it prints: the switch (naked, on, off, and a mark that turned the record on), "Debug
-- record cleared." and the usage line; a mark on a record already on, and "report", print
-- nothing. English only, like the record: a
-- player is handed these words when a problem needs them. The "debug" word itself is a
-- hidden entry in Options' table, which hands what follows it to Run.
-- AceConfigCmd reads the "debug" word and stops there on purpose: it cannot do the rest.
-- The bare word reports the switch, and "mark", "report" and "clear" hang off the same
-- word. As a group of AceConfig entries the bare word would print Ace's list of
-- sub-commands in place of the switch, and a wrong word Ace's own error in place of the
-- usage line. Settings reads its own words for the same reason (Run below is that rule,
-- not a copy of AceConfigCmd's parsing).
--
-- Public:  Run(input) -- input: the text after "/ssf debug".
-- Reads:   Debug:IsOn/Set/Mark/Clear, DebugReport:Open, Colors:OnOff.
-- Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local DebugCommand = SSF:NewModule("DebugCommand")

function DebugCommand:Run(input)
    local Debug = SSF:GetModule("Debug")
    input = strtrim(input or "")
    local word, rest = input:match("^(%S*)%s*(.*)$")
    word = word:lower()
    if (word == "on" or word == "off") and rest == "" then
        Debug:Set(word == "on")
    elseif word == "mark" and rest ~= "" then
        local wasOn = Debug:IsOn()
        Debug:Mark(rest)
        if wasOn then return end
    elseif word == "report" and rest == "" then
        SSF:GetModule("DebugReport"):Open()
        return
    elseif word == "clear" and rest == "" then
        Debug:Clear()
        SSF:Print("Debug record cleared.")
        return
    elseif word ~= "" then
        -- each bar doubled: in chat a single bar starts an escape code, and "|r" (in
        -- "|report") is the end-color code, which the game eats
        SSF:Print("Use: /ssf debug on||off||mark <name>||report||clear")
        return
    end
    SSF:Printf("Debug: %s", SSF:GetModule("Colors"):OnOff(Debug:IsOn()))
end
