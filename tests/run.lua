-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- run: the headless test runner. Loads the WoW stub, the Ace3 libraries SSF's logic
-- modules need, then Core and those modules (never the widgets or the window), then
-- every tests/test_*.lua. Exit code 0 when every check passes, 1 otherwise.
-- Run from the addon root:  lua tests/run.lua        (tools/check.py does this)
--
-- A test file calls test(name, fn); inside fn, eq(got, want, label) and ok(cond, label)
-- record one check each. Fresh bags per test: call WoW.SetBags{...} at the top of fn.
-- Touches nothing else.

local ROOT = arg and arg[0] and arg[0]:match("^(.*)[/\\]tests[/\\]run%.lua$") or "."
local ADDON, NS = "SoulShardForever", {}

local function loadLua(rel, ...)
    local chunk, err = loadfile(ROOT .. "/" .. rel)
    if not chunk then error("cannot load " .. rel .. ": " .. tostring(err)) end
    return chunk(...)
end

loadLua("tests/wow_stub.lua")

-- Libraries, in embeds.xml order, only those the logic modules need
for _, rel in ipairs({
    "Libs/LibStub/LibStub.lua",
    "Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
    "Libs/AceAddon-3.0/AceAddon-3.0.lua",
    "Libs/AceEvent-3.0/AceEvent-3.0.lua",
    "Libs/AceTimer-3.0/AceTimer-3.0.lua",
    "Libs/AceBucket-3.0/AceBucket-3.0.lua",
    "Libs/AceDB-3.0/AceDB-3.0.lua",
    "Libs/AceConsole-3.0/AceConsole-3.0.lua",
    "Libs/AceLocale-3.0/AceLocale-3.0.lua",
}) do loadLua(rel) end

-- The addon: locales, Core, then the logic modules under test
for _, rel in ipairs({
    "Locales/Register.lua",
    "Locales/enUS.lua",
    "Core.lua",
    "Modules/Bags.lua",
    "Modules/Cap.lua",
}) do loadLua(rel, ADDON, NS) end

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
LibStub("AceAddon-3.0"):InitializeAddon(SSF) -- OnInitialize: the warlock gate, the db, the language
_G.SSF = SSF

-- The tiny assertion kit
local passed, failed, current = 0, 0, nil
local function record(okay, label, detail)
    if okay then passed = passed + 1 return end
    failed = failed + 1
    io.write(string.format("  FAIL  %s: %s%s\n", current, label or "", detail and ("  " .. detail) or ""))
end
function ok(cond, label) record(cond and true or false, label) end
function eq(got, want, label)
    record(got == want, label, string.format("got %s, want %s", tostring(got), tostring(want)))
end
function test(name, fn)
    current = name
    WoW.SetBags(nil)
    WoW.combat = false
    local okay, err = pcall(fn)
    if not okay then record(false, "error", tostring(err)) end
end

-- Every tests/test_*.lua, sorted
local names = {}
local p = io.popen('dir /b "' .. ROOT:gsub("/", "\\") .. '\\tests\\test_*.lua" 2>nul')
if p then
    for line in p:lines() do names[#names + 1] = line end
    p:close()
end
if #names == 0 then
    local p2 = io.popen("ls " .. ROOT .. "/tests/test_*.lua 2>/dev/null")
    if p2 then
        for line in p2:lines() do names[#names + 1] = line:match("[^/\\]+$") end
        p2:close()
    end
end
table.sort(names)
for _, name in ipairs(names) do loadLua("tests/" .. name) end

io.write(string.format("%d checks passed, %d failed, %d test files\n", passed, failed, #names))
os.exit(failed == 0 and 0 or 1)
