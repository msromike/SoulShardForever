-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- run: the headless test runner. Brings the whole addon up the way a login does
-- (tests/load.lua: every library, every file in the toc, OnInitialize, every module's
-- OnEnable, then the events a login sends, so what a module does once at login is done
-- before the first test, as in the game) on a saved file as a 1.8.1 user has it (one profile under the old AceDB key),
-- so Core's profile-key migration runs, then runs every tests/test_*.lua. Exit code 0 when
-- every check passes, 1 otherwise, and 1 when no test file was found. Run from the addon
-- root, on Lua 5.1 (the game's own):  lua51 tests/run.lua
-- (tools/check.py does).
--
-- Every test starts from the same place, whatever ran before it: the profile as it was
-- right after the modules enabled, each module's own plain fields as they were then, empty
-- bags, an empty cursor, no combat, no channel, no timers waiting, an empty record of
-- picks and deletes, an empty chat, no sound muted, SSF's two macros and no other, no
-- macro window, nothing refused. So no test depends on another, and the order they run in is free.
-- A test fails on a failed check, on an error, and on any error the game would have shown
-- in red while it ran (WoW.errors).
--
-- Public:  test(name, fn) -- one test, from the clean start above. Inside fn:
--            eq(got, want, label) and ok(cond, label) record one check each.
--          SSF, the addon object, as a global for the test files.
--          SoulShardForeverDB, the saved file, as the game would hold it (test_core reads
--            the old profile in it).
--          WoW.NS -- the addon-private table every file is handed (the locales, the
--            announcement), for a test that swaps what a data file set (test_newsshow).
--          WoW.initialProfile -- the profile's values right after OnInitialize, before any
--            module enabled or any test touched them (test_core reads them to prove the
--            migration).
-- Touches nothing else.

local ROOT = arg and arg[0] and arg[0]:match("^(.*)[/\\]tests[/\\]run%.lua$") or "."
local Load = assert(loadfile(ROOT .. "/tests/load.lua"))(ROOT)

-- A saved file as a 1.8.1 user has it: one profile under the old AceDB 36 key. Core's
-- profile-key migration must carry it over to the new key at OnInitialize.
local SSF = Load({
    login = true,
    saved = {
        profileKeys = { ["Tester - PvE"] = "Tester - PvE" },
        profiles = { ["Tester - PvE"] = { maxShards = 12, lowMark = 10, welcomed = 10801, pauseLog = true } },
    },
    afterInit = function(addon)
        WoW.initialProfile = {
            char = addon.db.keys.char, profileKey = addon.db.keys.profile,
            maxShards = addon.db.profile.maxShards, lowMark = addon.db.profile.lowMark,
            welcomed = addon.db.profile.welcomed, pauseLog = addon.db.profile.pauseLog,
        }
    end,
})
_G.SSF = SSF

-- The clean start: what the profile and each module's own plain fields held once every
-- module had enabled. A module's tables (its Ace registrations, its frames) are left alone.
local function Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = Copy(v) end
    return out
end
local function Plain(value) return type(value) ~= "table" and type(value) ~= "function" and type(value) ~= "userdata" end
local startProfile = Copy(SSF.db.profile)
local startFields = {}
for name, module in pairs(SSF.modules) do
    local fields = {}
    for k, v in pairs(module) do
        if Plain(v) then fields[k] = v end
    end
    startFields[name] = fields
end

local function CleanStart()
    local profile = SSF.db.profile
    for k in pairs(profile) do profile[k] = nil end
    for k, v in pairs(startProfile) do profile[k] = Copy(v) end
    for name, module in pairs(SSF.modules) do
        for k, v in pairs(module) do
            if Plain(v) and startFields[name][k] == nil then module[k] = nil end
        end
        for k, v in pairs(startFields[name]) do module[k] = v end
    end
    WoW.SetBags(nil)
    WoW.combat, WoW.flagged, WoW.channel, WoW.targeting, WoW.itemCount = false, nil, nil, nil, nil
    WoW.picks, WoW.deleted = {}, {}
    WoW.unknownSpells = {}
    WoW.chat, WoW.muted = {}, {}
    WoW.ResetMacros()
    WoW.ClearTimers()
end

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
    CleanStart()
    local seen = #WoW.errors
    local okay, err = pcall(fn)
    if not okay then record(false, "error", tostring(err)) end
    for i = seen + 1, #WoW.errors do
        record(false, "an error the game would show in red", WoW.errors[i]:match("^[^\n]*"))
    end
end

-- nothing the game would have shown in red while the addon came up
current = "loading the addon"
for _, err in ipairs(WoW.errors) do record(false, "an error the game would show in red", err:match("^[^\n]*")) end

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
for _, name in ipairs(names) do
    local chunk, err = loadfile(ROOT .. "/tests/" .. name)
    if not chunk then error("cannot load tests/" .. name .. ": " .. tostring(err)) end
    chunk()
end

io.write(string.format("%d checks passed, %d failed, %d test files\n", passed, failed, #names))
if #names == 0 then io.write("  FAIL  no test file was found: the run proves nothing\n") end
os.exit((failed == 0 and #names > 0) and 0 or 1)
