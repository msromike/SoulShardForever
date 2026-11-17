-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- TabComplete: Tab in the chat box, through AceTab. "/ssf del<Tab>" becomes "/ssf delete",
-- "/ssf pause o<Tab>" becomes "/ssf pause off" or "on". The words are Options' listed chat
-- words (ChatWords), each toggle with its value words (Settings:ValueWords); a hidden word
-- is never offered. One completion set of whole phrases, never a second set on
-- "/ssf <key> ": a set nested inside another can move AceTab's insert point, and on AceTab
-- 11 a Tab then replaced from the wrong place (seen in game). Sorted, so a Tab
-- cycles in the order the list prints (AceTab 12 keeps the order; 11 scrambles it). On an
-- ambiguous Tab it prints the part being chosen on one line: the value words when every
-- match is under one command word, otherwise the command words.
--
-- Public:  none; AceTab calls it on Tab.
-- Reads:   Options:ChatWords, Settings:ValueWords.
-- Acts on: AceTab's completion list for "/ssf " in the chat box (RegisterTabCompletion).
-- Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local TabComplete = SSF:NewModule("TabComplete")
local AceTab = LibStub("AceTab-3.0")

-- every whole phrase Tab can complete to, sorted
local function CommandWords(words)
    local Settings = SSF:GetModule("Settings")
    local list = {}
    for _, word in ipairs(SSF:GetModule("Options"):ChatWords()) do
        local values = Settings:ValueWords(word)
        if values then
            for _, value in ipairs(values) do list[#list + 1] = word .. " " .. value end
        else
            list[#list + 1] = word
        end
    end
    table.sort(list)
    for _, word in ipairs(list) do words[#words + 1] = word end
end

-- the line printed on an ambiguous Tab: the part being chosen
local function TabUsage(_, matches)
    local firsts, seconds = {}, {}
    for phrase in pairs(matches) do
        local first, second = phrase:match("^(%S+) (%S+)$")
        firsts[first or phrase] = true
        if second then seconds[second] = true end
    end
    local function Sorted(set)
        local list = {}
        for word in pairs(set) do list[#list + 1] = word end
        table.sort(list)
        return list
    end
    local list = Sorted(firsts)
    if #list == 1 and next(seconds) then list = Sorted(seconds) end
    return table.concat(list, "  ")
end

-- AceTab keeps the first registration of a name, so an OnEnable that runs again is harmless.
function TabComplete:OnEnable()
    AceTab:RegisterTabCompletion("SSF", "/ssf ", CommandWords, TabUsage)
end
