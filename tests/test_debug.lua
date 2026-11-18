-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_debug: the debug record. It starts off and the switch is not a saved setting; off,
-- nothing is recorded and nothing is listened to; on, every kind of event lands in the
-- record with its counts and positions; a press does the same thing either way; the saved
-- record is kept until cleared, and the text holds this session's events only, one line
-- each.
-- Saves:   profile.debugLog (through Debug, and one seeded by hand), paused, maxShards,
--          autoMax, for the test at hand.
-- Touches nothing else.

local SHARD = SSF.SHARD_ITEM_ID
local Debug = SSF:GetModule("Debug")
local Trimmer = SSF:GetModule("Trimmer")
local Sorter = SSF:GetModule("Sorter")
local Bags = SSF:GetModule("Bags")
local profile = SSF.db.profile
local soul, plain = WoW.SoulBag, WoW.PlainBag

-- the kinds in the record, in order, as one line
local function kinds()
    local out = {}
    for _, e in ipairs(Debug:Log()) do out[#out + 1] = e.kind end
    return table.concat(out, " ")
end

-- the newest event of this kind
local function last(kind)
    local log = Debug:Log()
    for i = #log, 1, -1 do
        if log[i].kind == kind then return log[i] end
    end
end

-- Runs fn with an empty record switched on, and switches it off again whatever fn does.
local function recording(fn)
    Debug:Set(false)
    Debug:Clear()
    local pauseLog, pauseSound, announce = profile.pauseLog, profile.pauseSoundLevel, profile.announce
    profile.paused, profile.autoMax = false, false
    profile.pauseLog, profile.pauseSoundLevel, profile.announce = false, 0, false
    Debug:Set(true)
    local okay, err = pcall(fn)
    Debug:Set(false)
    WoW.channel, WoW.targeting, WoW.itemCount = nil, nil, nil
    profile.paused, profile.maxShards = false, 8
    profile.pauseLog, profile.pauseSoundLevel, profile.announce = pauseLog, pauseSound, announce
    assert(okay, err)
end

-- One delete press, and how many shards it deleted (the stub's cursor really takes the
-- shard and really deletes it). Without `works`, the pickup takes nothing, as when the
-- game refuses it: the cursor stays empty and the delete cannot go through.
local function press(works)
    local pickup = C_Container.PickupContainerItem
    if not works then C_Container.PickupContainerItem = function() end end
    local before = #WoW.deleted
    local okay, err = pcall(Trimmer.Delete, Trimmer)
    C_Container.PickupContainerItem = pickup
    assert(okay, err)
    return #WoW.deleted - before
end

local function threeLoose()
    WoW.SetBags({ [0] = plain(16, { [1] = SHARD, [2] = SHARD, [3] = SHARD }) })
end

test("it starts off, and off records nothing: not a press, a fight or a bag change", function()
    eq(Debug:IsOn(), false, "off before anyone turned it on")
    eq(profile.debug, nil, "the switch is not a saved setting")
    Debug:Clear()
    profile.paused, profile.autoMax, profile.maxShards = false, false, 1
    threeLoose()
    eq(press(true), 1, "the press still deletes")
    WoW.FireEvent("PLAYER_REGEN_DISABLED")
    Bags:OnBagsChanged()
    eq(profile.debugLog, nil, "no record made")
    eq(Debug:Text(), "Nothing recorded this session.", "and the text says so")
    profile.maxShards = 8
end)

test("on: a press over the cap records the press, then the delete", function()
    recording(function()
        threeLoose()
        profile.maxShards = 1
        eq(press(true), 1, "one delete")
        eq(kinds(), "on press deleted", "the three events, in order")
        local p = last("press")
        eq(p.decision, "delete", "the press decided to delete")
        eq(p.count, 3, "SSF's count before the delete")
        eq(p.game, 3, "the game's own count")
        eq(p.cap, 1, "the cap")
        eq(p.delta, 3, "the count moved since the event before (empty bags)")
        eq(p.at, "0:1 0:2 0:3", "where every shard sat")
        eq(p.lock, nil, "not in a fight")
        eq(last("deleted").slot, "0:1", "the shard that went")
        ok(type(p.clock) == "string" and type(p.t) == "number", "both times")
        ok(type(last("on").day) == "string", "turning it on notes the day")
    end)
end)

test("on: a press at the cap, and a paused press, are recorded with the reason", function()
    recording(function()
        threeLoose()
        profile.maxShards = 3
        eq(press(true), 0, "at the cap: no delete")
        eq(last("press").decision, "atcap", "at the cap")
        profile.paused = true
        eq(press(true), 0, "paused: no delete")
        eq(last("press").decision, "paused", "paused")
        eq(kinds(), "on press press", "two presses, nothing else")
    end)
end)

test("on, in a fight: the press, the delete, and the sort that was skipped", function()
    recording(function()
        threeLoose()
        profile.maxShards = 1
        WoW.combat = true
        eq(press(true), 1, "one delete in a fight")
        eq(kinds(), "on press mute unmute deleted sortnote", "muted for the delete, and the sort noted")
        eq(last("mute").what, "delete", "what the sounds were muted for")
        eq(last("press").lock, true, "the lockdown flag")
        eq(last("press").combat, true, "the in-combat flag")
        WoW.combat = false
    end)
end)

test("on: a delete that does not go through is recorded with why", function()
    recording(function()
        threeLoose()
        profile.maxShards = 1
        eq(press(false), 0, "the cursor never held the shard")
        eq(kinds(), "on press failed", "press, then the failure")
        eq(last("failed").why, "cursor", "Trimmer's word for it")
    end)
end)

test("on: the press notes a channel and a targeting circle", function()
    recording(function()
        threeLoose()
        profile.maxShards = 1
        WoW.channel, WoW.targeting = "Drain Soul", true
        press(true)
        eq(last("press").channel, "Drain Soul", "the spell being channeled")
        eq(last("press").circle, true, "the circle was up")
    end)
end)

test("on: what SSF prints and the sound it plays are recorded; off, the hooks are gone", function()
    recording(function()
        threeLoose()
        profile.maxShards = 1
        profile.announce = true
        press(true)
        eq(kinds(), "on press deleted chat", "the delete's chat line")
        ok(last("chat").text:find("2", 1, true), "its text, with the count")
        ok(not last("chat").text:find("|c", 1, true), "color codes stripped")
        profile.announce = false

        profile.paused, profile.pauseSoundLevel, profile.pauseLog = true, 1, true
        press(true)
        eq(kinds(), "on press deleted chat press sound chat", "paused, out of a fight: the sound and the line")
        eq(last("sound").name, SSF:GetModule("Sounds"):DefaultName(), "which sound")
        WoW.combat = true
        press(true)
        eq(kinds(), "on press deleted chat press sound chat press", "paused, in a fight: the press and nothing else")
        WoW.combat = false

        SSF:Printf("%s: %d", "Shards", 7)
        eq(last("chat").text, "Shards: 7", "a formatted line too")
    end)
    local n = #Debug:Log()
    SSF:Print("after it is off")
    eq(#Debug:Log(), n, "off: a printed line is not recorded")
end)

test("on and off several times: one printed line is still one event", function()
    recording(function()
        Debug:Set(false)
        Debug:Set(true)
        Debug:Set(false)
        Debug:Set(true)
        local n = #Debug:Log()
        SSF:Print("once")
        eq(#Debug:Log(), n + 1, "the hooks did not stack")
        eq(last("chat").text, "once", "and it is the line")
        SSF:Print(SSF:GetModule("Colors"):Gold("green") .. " |TInterface\\Icons\\x:0|t |Hitem:1|h[Thing]|h")
        eq(last("chat").text, "green  [Thing]", "color, texture and link codes stripped")
    end)
end)

test("off is off even if noting it fails", function()
    Debug:Set(false)
    Debug:Clear()
    Debug:Set(true)
    local cap = SSF:GetModule("Cap")
    local get = cap.Get
    cap.Get = function() error("broken", 0) end
    local okay = pcall(Debug.Set, Debug, false)
    cap.Get = get
    eq(okay, false, "the note threw")
    eq(Debug:IsOn(), false, "but the record is off")
    local n = #Debug:Log()
    WoW.FireEvent("PLAYER_REGEN_DISABLED")
    SSF:Print("after")
    eq(#Debug:Log(), n, "and nothing is still listening")
end)

test("a press does the same thing with the record on and off", function()
    profile.paused, profile.autoMax, profile.maxShards = false, false, 1
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD, [9] = SHARD }), [1] = soul(4, { [4] = SHARD }) })
    local offDeletes = press(true)
    local offPicks = #WoW.picks
    WoW.picks = {}
    local onDeletes, onPicks
    recording(function()
        WoW.SetBags({ [0] = plain(16, { [2] = SHARD, [9] = SHARD }), [1] = soul(4, { [4] = SHARD }) })
        profile.maxShards = 1
        onDeletes = press(true)
        onPicks = #WoW.picks
    end)
    eq(onDeletes, offDeletes, "the same deletes")
    eq(onPicks, offPicks, "the same pickups")
end)

test("on: a sort's moves are recorded", function()
    recording(function()
        WoW.SetBags({ [0] = plain(16, { [2] = SHARD }), [1] = soul(4, {}) })
        eq(Sorter:Pass(), 1, "one move")
        eq(last("sorted").moves, "0:2>1:4", "from the backpack into the soul bag's bottom slot")
        eq(kinds(), "on mute unmute sorted", "muted for the sort, and back on")
    end)
end)

test("on: a sort noted in a fight and run when the fight ends is recorded", function()
    recording(function()
        WoW.SetBags({ [0] = plain(16, { [2] = SHARD }), [1] = soul(4, {}) })
        WoW.combat = true
        Sorter:Pass()
        WoW.combat = false
        Sorter:OnCombatEnd()
        eq(kinds(), "on sortnote sortrun mute unmute sorted", "noted, then run, muted, sorted")
        ok(Debug:Text():find("noted sort runs: the fight is over", 1, true), "and in the text")
    end)
end)

test("on: a bag change is kept only when the shards sit differently", function()
    recording(function()
        WoW.SetBags({ [0] = plain(16, { [1] = SHARD, [2] = SHARD }) })
        Bags:OnBagsChanged()
        eq(kinds(), "on bags", "the shards appeared")
        Bags:OnBagsChanged()
        eq(kinds(), "on bags", "nothing moved: no second event")
        WoW.SetBags({ [0] = plain(16, { [1] = SHARD, [2] = SHARD, [3] = SHARD }) })
        Bags:OnBagsChanged()
        eq(kinds(), "on bags bags", "a shard gained")
        eq(last("bags").delta, 1, "shown as +1")
        eq(last("bags").at, "0:1 0:2 0:3", "and where they sit now")
    end)
end)

test("on: the game's own count is recorded beside SSF's", function()
    recording(function()
        threeLoose()
        WoW.itemCount = 7
        Debug:Mark("mismatch")
        eq(last("mark").count, 3, "SSF's count")
        eq(last("mark").game, 7, "the game's, disagreeing")
        eq(last("mark").name, "mismatch", "the marker's name")
    end)
end)

test("on: fights, the player's channel and a loading screen are recorded; off stops it", function()
    recording(function()
        WoW.FireEvent("PLAYER_REGEN_DISABLED")
        WoW.channel = "Drain Soul"
        WoW.FireEvent("UNIT_SPELLCAST_CHANNEL_START", "target")
        WoW.FireEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
        WoW.channel = nil
        WoW.FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
        WoW.FireEvent("PLAYER_REGEN_ENABLED")
        WoW.FireEvent("PLAYER_ENTERING_WORLD", false, false)
        eq(kinds(), "on combat channel channel combat zone", "someone else's channel is not ours")
        local log = Debug:Log()
        eq(log[2].state, "start", "the fight starts")
        eq(log[3].spell, "Drain Soul", "the channel's spell")
        eq(log[4].state, "stop", "the channel stops")
        eq(log[5].state, "end", "the fight ends")
    end)
    local n = #Debug:Log()
    eq(Debug:Log()[n].kind, "off", "switching off is the last event")
    WoW.FireEvent("PLAYER_REGEN_DISABLED")
    eq(#Debug:Log(), n, "nothing more once off")
end)

test("a watched login: the record starts on, once, and notes each step with the bags", function()
    Debug:Set(false)
    Debug:Clear()
    Debug:OnEnable()
    eq(Debug:IsOn(), false, "not asked for: a login leaves the record off")
    WoW.SetBags({ [0] = plain(16, { [1] = SHARD }), [5] = soul(14, { [14] = SHARD }) })
    Debug:WatchNextLogin()
    eq(profile.debugLogin, true, "asked for, saved")
    Debug:OnEnable()
    eq(profile.debugLogin, nil, "taken: the login after this one is not watched")
    eq(Debug:IsOn(), true, "the record is on")
    WoW.FireEvent("PLAYER_ENTERING_WORLD", true, false)
    WoW.FireEvent("BAG_UPDATE_DELAYED")
    WoW.FireEvent("GET_ITEM_INFO_RECEIVED", SHARD + 1, true)
    WoW.FireEvent("GET_ITEM_INFO_RECEIVED", SHARD, true)
    eq(kinds(), "on login login login login", "enabled, world, bags ready, the shard's data; another item's is not noted")
    local log = Debug:Log()
    eq(log[2].step, "addon enabled", "the first step")
    eq(log[3].step, "world entered, login", "the world, and that it is a login")
    eq(log[4].step, "bags ready", "the game's own signal")
    eq(log[5].step, "shard data arrived", "the shard's item data")
    eq(log[4].bags, "0:16 plain, 1:0, 2:0, 3:0, 4:0, 5:14 soul", "every bag slot, its size and what Bags takes it for")
    eq(log[4].count, 2, "SSF's count at that step")
    eq(log[4].at, "0:1 5:14", "and where the shards sit")
    ok(Debug:Text():find("login: bags ready | bags 0:16 plain, 1:0, 2:0, 3:0, 4:0, 5:14 soul | count 2/2", 1, true), "the step's line")
    Debug:EndLoginWatch()
    eq(last("login").step, "watch over", "the watch ends with a last step")
    local n = #Debug:Log()
    WoW.FireEvent("BAG_UPDATE_DELAYED")
    eq(#Debug:Log(), n, "after it, the game's signal is no longer noted")
    WoW.FireEvent("PLAYER_ENTERING_WORLD", false, false)
    eq(last("zone") ~= nil, true, "and a loading screen is a loading screen again")
    eq(Debug:IsOn(), true, "the record stays on for the session")
    Debug:Set(false)
    Debug:Clear()
end)

test("a mark turns the record on when it is off", function()
    Debug:Set(false)
    Debug:Clear()
    Debug:Mark("start")
    eq(Debug:IsOn(), true, "on")
    eq(kinds(), "on mark", "turned on, then the marker")
    Debug:Set(false)
end)

test("the saved record is kept until cleared; the text holds this session only", function()
    Debug:Set(false)
    Debug:Clear()
    -- an event from an earlier session, as the saved file would hold it
    profile.debugLog = { { kind = "mark", name = "april", clock = "10:00:00", t = 1, count = 5, cap = 8 } }
    eq(Debug:Text(), "Nothing recorded this session.", "an old record, nothing this session")
    Debug:Set(true)
    Debug:Mark("today")
    Debug:Set(false)
    Debug:Set(true)
    local text = Debug:Text()
    ok(not text:find("april", 1, true), "the earlier session is not in the text")
    ok(text:find("mark today", 1, true), "this session's marker is")
    ok(text:find("debug off", 1, true), "off and on again: still the one session")
    eq(Debug:Log()[1].name, "april", "the earlier event is still in the saved record")
    eq(kinds(), "mark on mark off on", "nothing dropped, however many")

    for i = 1, 1500 do Debug:Mark("m" .. i) end
    eq(#Debug:Log(), 1505, "no cap: every event is kept")
    local _, breaks = Debug:Text():gsub("\n", "")
    eq(breaks + 1, 2 + 1504, "and the text has the whole session")

    Debug:Clear()
    eq(profile.debugLog, nil, "clear empties the saved record")
    eq(Debug:IsOn(), true, "and leaves the switch alone")
    Debug:Mark("after")
    eq(kinds(), "mark", "still on: the record goes on from empty")
    ok(Debug:Text():find("mark after", 1, true), "and the text with it")
    Debug:Set(false)
    Debug:Clear()
end)

test("the text: one line per event, counts and positions on it", function()
    recording(function()
        threeLoose()
        profile.maxShards = 1
        Debug:Mark("town")
        press(true)
        local text = Debug:Text()
        local _, breaks = text:gsub("\n", "")
        eq(breaks + 1, 2 + #Debug:Log(), "two heading lines, then one line per event")
        ok(text:find("mark town | count 3/3 (+3) cap 1 | 0:1 0:2 0:3", 1, true), "the marker's line")
        ok(text:find("press: delete | count 3/3 cap 1 | 0:1 0:2 0:3", 1, true), "the press's line")
        ok(text:find("deleted 0:1 | count 3/3 cap 1", 1, true), "the delete's line")
    end)
end)
