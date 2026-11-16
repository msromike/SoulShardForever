-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- window: opens the real options window outside the game and prints what is in it. Brings
-- the whole addon up the way a login does (tests/load.lua), sends the events a login
-- sends, opens the window the way /ssf does, then prints one line per control that
-- carries a text: its kind, shown or hidden, enabled or greyed, and the text.
-- tools/check.py runs it and compares the print with tests/window_controls.txt, so the
-- controls a player has cannot change without that file changing, and a test card names
-- only controls that file lists. Run from the addon root, on Lua 5.1:
--     lua51 tests/window.lua <scene>
-- Scenes: "settled" (a character that has seen the welcome and the announcement: the
-- window alone), "first" (a new character's first login: the window opens by itself with
-- the welcome on its right and the announcement on its left).
--
-- What it cannot say: where anything sits, its size, its color, whether a text is cut
-- short. The stub gives every frame no size and no place.
--
-- Reads:   tests/load.lua (the addon, brought up); WoW.Controls, WoW.RunTimers, WoW.errors
--          and WoW.macros (tests/wow_stub.lua); Window:Open.
-- Touches nothing else.

local ROOT = arg and arg[0] and arg[0]:match("^(.*)[/\\]tests[/\\]window%.lua$") or "."
local SCENE = arg and arg[1] or "settled"
local SEEN = 99999999 -- an id later than any welcome or announcement: both already seen
local SHARD = 6265    -- the shard item (Core's SSF.SHARD_ITEM_ID, not loaded yet where the bags are set)

local saved
if SCENE == "settled" then
    saved = {
        profileKeys = { ["Tester Hrodbar"] = "Tester Hrodbar" },
        profiles = { ["Tester Hrodbar"] = { welcomed = SEEN, newsSeen = SEEN } },
    }
elseif SCENE ~= "first" then
    error("unknown scene " .. tostring(SCENE) .. ' (use "settled" or "first")')
end

local Load = assert(loadfile(ROOT .. "/tests/load.lua"))(ROOT)
local SSF = Load({
    saved = saved,
    login = true,
    before = function()
        -- the bags: a backpack and a 20-slot soul bag holding 5 shards
        WoW.SetBags({ [0] = WoW.PlainBag(16), [4] = WoW.SoulBag(20, { SHARD, SHARD, SHARD, SHARD, SHARD }) })
        if SCENE == "first" then WoW.macros = {} end -- a new character has neither of SSF's macros
    end,
})

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
