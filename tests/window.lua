-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- window: opens the real options window outside the game and prints what is in it. Loads
-- the WoW stub and the UI stub, every library embeds.xml names, in its order, and every
-- file the toc names, in its order; runs OnInitialize and every module's OnEnable; sends
-- the events a login sends; opens the window the way /ssf does; then prints one line per
-- control that carries a text: its kind, shown or hidden, enabled or greyed, and the text.
-- tools/check.py runs it and compares the print with tests/window_controls.txt, so the
-- controls a player has cannot change without that file changing, and a test card names
-- only controls that file lists. Run from the addon root, on Lua 5.1:
--     lua51 tests/window.lua <scene>
-- Scenes: "settled" (a character that has seen the welcome and the announcement: the
-- window alone), "first" (a new character's first login: the window opens by itself with
-- the welcome on its right and the announcement on its left).
--
-- What it cannot say: where anything sits, its size, its color, whether a text is cut
-- short. The stubs give every frame no size and no place.
--
-- Reads:   embeds.xml and the toc (the load lists); WoW.Controls and WoW.RunTimers
--          (tests/ui_stub.lua); Window:Open.
-- Touches nothing else.

local ROOT = arg and arg[0] and arg[0]:match("^(.*)[/\\]tests[/\\]window%.lua$") or "."
local SCENE = arg and arg[1] or "settled"
local ADDON, NS = "SoulShardForever", {}
local SEEN = 99999999 -- an id later than any welcome or announcement: both already seen

local function loadLua(rel, ...)
    local chunk, err = loadfile(ROOT .. "/" .. rel)
    if not chunk then error("cannot load " .. rel .. ": " .. tostring(err)) end
    return chunk(...)
end

loadLua("tests/wow_stub.lua")
loadLua("tests/ui_stub.lua")

-- every Lua file an xml names, through the xml files it includes, in order
local function XmlFiles(xml, out)
    local dir = xml:match("^(.*)/[^/]+$")
    local file = io.open(ROOT .. "/" .. xml)
    if not file then return out end -- AceConfig-3.0.xml names a folder this client's copy lacks
    for line in file:lines() do
        local kind, inc = line:match("<(%a+)%s+file%s*=%s*[\"']([^\"']+)[\"']")
        if kind == "Include" or kind == "Script" then
            inc = ((dir and (dir .. "/") or "") .. inc):gsub("\\", "/")
            if kind == "Include" then XmlFiles(inc, out) else out[#out + 1] = inc end
        end
    end
    file:close()
    return out
end

for _, rel in ipairs(XmlFiles("embeds.xml", {})) do
    if rel:find("LibCustomGlow", 1, true) then
        -- the glow library draws with the game's texture pools, which no stub has: a
        -- stand-in that takes every call. A glow is a look, and no part of the list.
        setmetatable(LibStub:NewLibrary("LibCustomGlow-1.0", 1), { __index = function() return function() end end })
    else
        loadLua(rel, ADDON, NS)
    end
end

-- the bags: a backpack and a 20-slot soul bag holding 5 shards
local SHARD = 6265
WoW.SetBags({ [0] = WoW.PlainBag(16), [4] = WoW.SoulBag(20, { SHARD, SHARD, SHARD, SHARD, SHARD }) })

-- the saved file, before OnInitialize reads it
if SCENE == "settled" then
    SoulShardForeverDB = {
        profileKeys = { ["Tester Hrodbar"] = "Tester Hrodbar" },
        profiles = { ["Tester Hrodbar"] = { welcomed = SEEN, newsSeen = SEEN } },
    }
elseif SCENE == "first" then
    GetMacroIndexByName = function() return 0 end -- a new character has neither of SSF's macros
else
    error("unknown scene " .. tostring(SCENE) .. ' (use "settled" or "first")')
end

-- the addon: every Lua file the toc names, in its order
for line in io.lines(ROOT .. "/SoulShardForever.toc") do
    line = line:gsub("\r", "")
    if line:lower():match("%.lua$") and not line:match("^#") then loadLua((line:gsub("\\", "/")), ADDON, NS) end
end

local AceAddon = LibStub("AceAddon-3.0")
local SSF = AceAddon:GetAddon("SSF")
AceAddon:InitializeAddon(SSF)
AceAddon:EnableAddon(SSF)
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "LOADING_SCREEN_DISABLED", "BAG_UPDATE_DELAYED" }) do
    WoW.FireEvent(event)
end
WoW.RunTimers()

local Window = SSF:GetModule("Window")
if SCENE == "settled" then Window:Open() end -- "first" opened by itself, or the scene is wrong
WoW.RunTimers()

assert(Window.window, "the window never opened in scene " .. SCENE)
if #WoW.errors > 0 then
    local firsts = {}
    for i, err in ipairs(WoW.errors) do firsts[i] = "  " .. i .. ". " .. err:match("^[^\n]*") end
    error(#WoW.errors .. " error(s) the game would have shown in red:\n" .. table.concat(firsts, "\n")
        .. "\nthe first, in full:\n" .. WoW.errors[1], 0)
end

-- top to bottom as the player reads it: AceGUI keeps each container's children in layout
-- order, so every widget's frame is numbered by a walk of that tree. What the window
-- draws on its own frame (the title, the bottom row, the notes) has no widget: rank 0.
local places, count = {}, 0
local function Number(widget)
    count = count + 1
    places[widget.frame] = count
    for _, child in ipairs(widget.children or {}) do Number(child) end
end
Number(Window.window)
places[Window.window.frame] = 0

io.write(string.format("scene: %s\n", SCENE))
for _, c in ipairs(WoW.Controls(Window.window.frame, function(frame) return places[frame] end)) do
    -- a button with no text counts only on the window's own frame (the X, the help "i", a
    -- note's X); inside a stock widget it is that widget's own arrow or box
    local text = c.text or (c.place == 0 and ("(no text: " .. tostring(c.template or c.art or "plain") .. ")"))
    if text then
        io.write(string.format("%-11s %-6s %-7s %s\n", c.kind, c.shown and "shown" or "hidden",
            c.enabled and "enabled" or "greyed", text))
    end
end
