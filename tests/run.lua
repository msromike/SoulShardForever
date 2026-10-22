-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- run: the headless test runner. Loads the WoW stub, the Ace3 libraries SSF's logic
-- modules need, then Core and the logic modules (never the widgets or the window), then
-- sets a saved file as a 1.8.1 user has it (one profile under the old AceDB key) before
-- OnInitialize, so Core's profile-key migration runs, then every tests/test_*.lua. Exit
-- code 0 when every check passes, 1 otherwise. Run from the addon root, on Lua 5.1 (the
-- game's own):  lua51 tests/run.lua
-- (tools/check.py does).
--
-- Public:  test(name, fn) -- one test; fresh bags, no combat and an empty pick record
--            before fn runs. Inside fn: eq(got, want, label) and ok(cond, label) record
--            one check each.
--          SSF, the addon object, as a global for the test files.
--          SoulShardForeverDB, the saved file, as the game would hold it (test_core reads
--            the old profile in it).
--          WoW.initialProfile -- the profile's values right after OnInitialize, before any
--            test touches them (test_core reads them to prove the migration).
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
    "Libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua",
}) do loadLua(rel) end

-- The addon: locales, Core, then the logic modules under test (toc order; no widgets, no
-- window, no Options: those need AceGUI and a drawn UI)
for _, rel in ipairs({
    "Locales/Register.lua",
    "Locales/enUS.lua",
    "Core.lua",
    "Modules/Colors.lua",
    "Modules/KeyBindings.lua",
    "Modules/Bags.lua",
    "Modules/Cap.lua",
    "Modules/Sorter.lua",
    "Modules/Sounds.lua",
    "Modules/Trimmer.lua",
    "Modules/Status.lua",
}) do loadLua(rel, ADDON, NS) end

-- A saved file as a 1.8.1 user has it: one profile under the old AceDB 36 key. Core's
-- profile-key migration must carry it over to the new key at OnInitialize.
SoulShardForeverDB = {
    profileKeys = { ["Tester - PvE"] = "Tester - PvE" },
    profiles = { ["Tester - PvE"] = { maxShards = 12, lowMark = 10, welcomed = 10801, pauseLog = true } },
}

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
LibStub("AceAddon-3.0"):InitializeAddon(SSF) -- OnInitialize: the warlock gate, the db, the language
_G.SSF = SSF
-- what the profile looked like right after OnInitialize, before any test touches it
WoW.initialProfile = {
    char = SSF.db.keys.char, profileKey = SSF.db.keys.profile,
    maxShards = SSF.db.profile.maxShards, lowMark = SSF.db.profile.lowMark,
    welcomed = SSF.db.profile.welcomed, pauseLog = SSF.db.profile.pauseLog,
}

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
    WoW.picks = {}
    local okay, err = pcall(fn)
    if not okay then record(false, "error", tostring(err)) end
end

-- Every tests/test_*.lua, sorted; the listing command by OS (a Windows redirect run on
-- Linux would write a file named nul)
local names = {}
local onWindows = package.config:sub(1, 1) == "\\"
local listing = onWindows
    and ('dir /b "' .. ROOT:gsub("/", "\\") .. '\\tests\\test_*.lua" 2>nul')
    or ("ls " .. ROOT .. "/tests/test_*.lua 2>/dev/null")
local p = io.popen(listing)
if p then
    for line in p:lines() do names[#names + 1] = line:match("[^/\\]+$") end
    p:close()
end
table.sort(names)
for _, name in ipairs(names) do loadLua("tests/" .. name) end

io.write(string.format("%d checks passed, %d failed, %d test files\n", passed, failed, #names))
os.exit(failed == 0 and 0 or 1)
