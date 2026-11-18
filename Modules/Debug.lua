-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Debug: the debug record. While it is on it writes down what SSF did and what the bags
-- looked like, one event at a time, in the saved file (profile.debugLog), and hands this
-- session's part of the record back as text for the report window (DebugReport). It ships
-- to every player: one with a problem turns it on, plays, and sends the report.
-- It always starts off: the switch is not saved, so after every login and every reload it
-- has to be turned on again, and nobody leaves it on by accident. One thing turns it on by
-- itself, once: WatchNextLogin, asked for by the player, has the next login or reload start
-- with the record on and note what the bags look like at each step of the load, because
-- no command can be typed that early. The record itself is
-- permanent: it grows until Clear() empties it, with no cap. It only listens: Trimmer and
-- Sorter send their messages whether or not it is on, and nothing here changes what a
-- press does. Off means off: no message and no game event is registered until it is turned
-- on, and its two print hooks (see Hooks) do nothing. It prints nothing; its text is
-- English only, on purpose: the report is read by whoever maintains SSF, whatever the
-- player's language. It also writes down every line SSF prints
-- through its own Print and Printf, and every sound SSF itself plays, so "did the line
-- print, did the sound play" is read from the record, not asked of the player. The lines
-- are caught by a hook on the addon object's Print and Printf, so no code that prints is
-- changed; the command list and usage lines AceConfigCmd writes straight to the chat frame
-- do not pass through those and are not caught. A sound the
-- game makes by itself (an item's pickup tink) cannot be caught: the mute events say
-- whether SSF had those sounds muted at the time.
--
-- Every event carries: kind; clock (wall time) and t (seconds since the UI loaded, for the
-- time between two events); lock and combat (the combat lockdown, and the player flagged in
-- combat; each saved only when true); count (SSF's own, Bags:Count) and game (the game's
-- own count of the item, asked separately, so a counting mistake in SSF shows as the two
-- disagreeing); cap; delta (how far count moved since the event before, saved only when it
-- moved: a shard gained shows as +1). `at` is where every shard sits, as "bag:slot" pairs.
-- The kinds, with what each adds:
--   on, off    the switch (on: day, at)
--   zone       the world loaded again, through a loading screen (at)
--   login      one step of a watched login or reload (step: the addon enabled, the world
--              entered, the game said the bags are ready, the shard's item data arrived,
--              the watch ended; bags: every bag slot 0 up as "bag:slots kind", kind being
--              what Bags takes the bag for: soul, plain, or other; at)
--   mark       a name the player typed, to split the record by test (name, at)
--   press      a delete press, before anything is deleted (decision: "delete" or
--              Trimmer:WhyNot's answer; channel: the spell being channeled; circle: a
--              targeting circle was up; at)
--   deleted    a delete was sent (slot); its counts are from before the bags settle,
--              the bags event after it has the new ones
--   failed     a press decided to delete and did not (why, Trimmer's word)
--   sorted     a Sorter pass moved shards (moves, as "bag:slot>bag:slot")
--   sortnote   a Sorter pass was asked for in a fight and was noted
--   sortrun    the fight ended and the noted pass is about to run
--   mute       SSF muted the item move sounds (what: "sort" or "delete")
--   unmute     and turned them back on (what)
--   chat       SSF printed a line to chat (text; color, texture and link codes
--              stripped)
--   sound      SSF played one of its own sounds (name)
--   bags       the bags changed and the shards sit differently (at)
--   combat     a fight started or ended (state, at)
--   channel    the player's channel started or stopped (state, spell)
-- New kinds are added when a test needs them, never ahead of one.
--
-- Public:  IsOn() -> bool; Set(on) (turns the record on or off and records that);
--          Mark(name) (a marker; turns the record on first when it is off);
--          Clear() (empties the saved record; the switch stays as it is);
--          WatchNextLogin() (the next login or reload starts with the record on and its
--          steps noted, once);
--          Log() -> the saved list of events (the tests' handle); Text() -> this session's
--          events as text, one line each under two heading lines: every event since the
--          record was first turned on after the last login or reload.
-- Listens: only while on. SSF_DELETE_PRESSED, SSF_SHARD_DELETED, SSF_DELETE_FAILED,
--          SSF_SORTED, SSF_SORT_NOTED, SSF_SORT_RESUMED, SSF_SOUNDS_MUTED,
--          SSF_SOUNDS_UNMUTED, SSF_SOUND_PLAYED, SSF_BAGS_CHANGED; PLAYER_ENTERING_WORLD,
--          PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED, UNIT_SPELLCAST_CHANNEL_START,
--          UNIT_SPELLCAST_CHANNEL_STOP. During a watched login, for its first minute:
--          BAG_UPDATE_DELAYED and GET_ITEM_INFO_RECEIVED.
-- Hooks:   through AceHook (secure hooks, after the original): SSF.Print and SSF.Printf
--          (the addon object's, from AceConsole), to note each line SSF prints. They
--          attach the first time the record is turned on and stay for the session, doing
--          nothing while it is off: a secure hook cannot be taken off again, and hooking
--          afresh at every "on" would stack one more wrapper each time.
-- Reads:   Bags:Count/ForEachShard/NumSlots/IsSoulBag/IsRegularBag, Cap:Get; SSF.VERSION;
--          profile.debugLog, debugLogin.
-- Saves:   profile.debugLog (every event; Clear); profile.debugLogin (true from
--          WatchNextLogin until the next login or reload takes it).
-- Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Debug = SSF:NewModule("Debug", "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0")

local SHARD = SSF.SHARD_ITEM_ID

-- The switch, and where this session's events start in the saved record (nil until the
-- record is first turned on). Neither is saved: both are gone at a login or a reload.
local on, sessionStart = false, nil

-- A watched login: how long after the addon is enabled the game's own "bags are ready" and
-- the shard's item data are noted, and whether that is going on now.
local LOGIN_WATCH_SECONDS = 60
local watching = false

-- the count and the shard positions of the event before, for delta and for "did the
-- shards move"
local lastCount, lastAt

-- A value the game handed over, or nil when it is a secret value on this engine: a secret
-- cannot be compared, joined into text or saved.
local function plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- the game's own count of the shards in the bags, not SSF's walk of the slots
local function GameCount()
    local n = plain(C_Item.GetItemCount(SHARD))
    return type(n) == "number" and n or nil
end

-- where every shard sits: "bag:slot" pairs, bag 0 up, top slot first
local function Positions()
    local list = {}
    SSF:GetModule("Bags"):ForEachShard(function(bag, slot) list[#list + 1] = bag .. ":" .. slot end)
    return table.concat(list, " ")
end

-- the name of the spell the player is channeling, or nil
local function Channeling()
    local name = plain(UnitChannelInfo("player"))
    return type(name) == "string" and name or nil
end

-- Adds one event of this kind to the record. `e` holds what the kind adds; `at` is true to
-- note where every shard sits, or that text when the caller already has it.
local function Record(kind, e, at)
    local p = SSF.db.profile
    e = e or {}
    e.kind = kind
    e.clock = date("%H:%M:%S")
    e.t = math.floor(GetTime() * 100 + 0.5) / 100
    e.lock = InCombatLockdown() and true or nil
    e.combat = UnitAffectingCombat("player") and true or nil
    e.count = SSF:GetModule("Bags"):Count()
    e.game = GameCount()
    e.cap = SSF:GetModule("Cap"):Get()
    if lastCount and e.count ~= lastCount then e.delta = e.count - lastCount end
    lastCount = e.count
    if at then
        e.at = at == true and Positions() or at
        lastAt = e.at
    end
    local log = p.debugLog or {}
    log[#log + 1] = e
    p.debugLog = log
end

function Debug:OnPressed(_, decision)
    Record("press", { decision = decision, channel = Channeling(), circle = SpellIsTargeting() and true or nil }, true)
end

function Debug:OnDeleted(_, _, _, bag, slot)
    Record("deleted", { slot = bag and (bag .. ":" .. slot) or nil })
end

function Debug:OnDeleteFailed(_, why)
    Record("failed", { why = why })
end

function Debug:OnSorted(_, _, moves)
    local list = {}
    for i, move in ipairs(moves or {}) do
        list[i] = move[1] .. ":" .. move[2] .. ">" .. move[3] .. ":" .. move[4]
    end
    Record("sorted", { moves = table.concat(list, " ") })
end

function Debug:OnSortNoted()
    Record("sortnote")
end

function Debug:OnSortResumed()
    Record("sortrun")
end

function Debug:OnSoundsMuted(_, what)
    Record("mute", { what = what })
end

function Debug:OnSoundsUnmuted(_, what)
    Record("unmute", { what = what })
end

function Debug:OnSoundPlayed(_, name)
    Record("sound", { name = name })
end

-- One printed line as plain text: the strings and numbers handed to Print, joined (a chat
-- frame handed first is skipped), color codes taken out.
local function Printed(...)
    local parts = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "string" or type(v) == "number" then parts[#parts + 1] = tostring(v) end
    end
    local text = table.concat(parts, " ")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn.-:", ""):gsub("|r", "")
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|H.-|h", ""):gsub("|h", "")
    return text
end

-- The two print hooks. They stay attached while the record is off, so they check the
-- switch; and they run inside whatever printed (the delete press among them), so nothing
-- they do may raise an error into it.
local function NotePrinted(...)
    Record("chat", { text = Printed(...) })
end

function Debug:OnPrint(_, ...)
    if on then pcall(NotePrinted, ...) end
end

-- Printf's arguments are a format and its values, or a chat frame first
function Debug:OnPrintf(_, first, ...)
    if not on then return end
    local okay, text
    if type(first) == "string" then
        okay, text = pcall(string.format, first, ...)
    else
        okay, text = pcall(string.format, ...)
    end
    pcall(NotePrinted, okay and text or first)
end

-- Bags sends its signal for any item in any bag; an event is kept only when the shards sit
-- differently from the last time they were noted.
function Debug:OnBagsChanged()
    local at = Positions()
    if at ~= lastAt then Record("bags", nil, at) end
end

function Debug:OnCombatStart()
    Record("combat", { state = "start" }, true)
end

function Debug:OnCombatEnd()
    Record("combat", { state = "end" }, true)
end

function Debug:OnChannel(event, unit)
    if plain(unit) ~= "player" then return end
    local start = event == "UNIT_SPELLCAST_CHANNEL_START"
    Record("channel", { state = start and "start" or "stop", spell = start and Channeling() or nil })
end

-- Every bag slot from the backpack to the reagent slot, as "bag:slots kind": how many slots
-- the game says the bag has and what Bags takes it for. A bag with no slots is empty or not
-- filled in yet; "other" is a bag Bags counts no shard in.
local function BagFacts()
    local Bags = SSF:GetModule("Bags")
    local list = {}
    for bag = 0, Enum.BagIndex.ReagentBag do
        local slots = Bags:NumSlots(bag)
        local kind = slots == 0 and "" or Bags:IsSoulBag(bag) and " soul" or Bags:IsRegularBag(bag) and " plain" or " other"
        list[#list + 1] = bag .. ":" .. slots .. kind
    end
    return table.concat(list, ", ")
end

local function LoginStep(step)
    Record("login", { step = step, bags = BagFacts() }, true)
end

function Debug:OnBagsReady()
    LoginStep("bags ready")
end

function Debug:OnItemInfo(_, itemID)
    if plain(itemID) == SHARD then LoginStep("shard data arrived") end
end

function Debug:EndLoginWatch()
    watching = false
    self:UnregisterEvent("BAG_UPDATE_DELAYED")
    self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    LoginStep("watch over")
end

-- A loading screen inside a session. At a login or a reload the record is off by then,
-- unless the load is a watched one: then it is a step of that.
function Debug:OnEnteringWorld(_, isLogin, isReload)
    if watching then
        LoginStep(isLogin and "world entered, login" or isReload and "world entered, reload" or "world entered")
    else
        Record("zone", nil, true)
    end
end

function Debug:IsOn()
    return on
end

function Debug:Log()
    return SSF.db.profile.debugLog or {}
end

function Debug:Set(want)
    want = want and true or false
    if want == on then return end
    if want then
        on = true
        sessionStart = sessionStart or (#self:Log() + 1)
        lastCount, lastAt = nil, nil
        self:RegisterMessage("SSF_DELETE_PRESSED", "OnPressed")
        self:RegisterMessage("SSF_SHARD_DELETED", "OnDeleted")
        self:RegisterMessage("SSF_DELETE_FAILED", "OnDeleteFailed")
        self:RegisterMessage("SSF_SORTED", "OnSorted")
        self:RegisterMessage("SSF_SORT_NOTED", "OnSortNoted")
        self:RegisterMessage("SSF_SORT_RESUMED", "OnSortResumed")
        self:RegisterMessage("SSF_SOUNDS_MUTED", "OnSoundsMuted")
        self:RegisterMessage("SSF_SOUNDS_UNMUTED", "OnSoundsUnmuted")
        self:RegisterMessage("SSF_SOUND_PLAYED", "OnSoundPlayed")
        if not self:IsHooked(SSF, "Print") then
            self:SecureHook(SSF, "Print", "OnPrint")
            self:SecureHook(SSF, "Printf", "OnPrintf")
        end
        self:RegisterMessage("SSF_BAGS_CHANGED", "OnBagsChanged")
        self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
        self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStart")
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")
        self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "OnChannel")
        self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", "OnChannel")
        Record("on", { day = date("%Y-%m-%d") }, true)
    else
        -- stop listening first and flip the switch, then note it: whatever the note
        -- does, the record is off and nothing of it is left registered
        self:UnregisterAllMessages()
        self:UnregisterAllEvents()
        self:CancelAllTimers()
        on, watching = false, false
        Record("off")
    end
end

-- AceAddon switched the module off: the switch follows (AceEvent has already dropped every
-- registration, and the hooks stay, doing nothing while off; a later Set(true) listens again)
function Debug:OnDisable()
    on, watching = false, false
end

function Debug:WatchNextLogin()
    SSF.db.profile.debugLogin = true
end

-- The watched login or reload, asked for before it: the record on from the first moment,
-- once. Setup lives in OnEnable, not OnInitialize: Core's warlock gate switches modules off
-- before OnEnable.
function Debug:OnEnable()
    local p = SSF.db.profile
    if not p.debugLogin then return end
    p.debugLogin = nil
    self:Set(true)
    watching = true
    self:RegisterEvent("BAG_UPDATE_DELAYED", "OnBagsReady")
    self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "OnItemInfo")
    self:ScheduleTimer("EndLoginWatch", LOGIN_WATCH_SECONDS)
    LoginStep("addon enabled")
end

function Debug:Mark(name)
    self:Set(true)
    Record("mark", { name = name }, true)
end

-- Empties the saved record. Still on, the record goes on from empty.
function Debug:Clear()
    local p = SSF.db.profile
    p.debugLog = nil
    sessionStart = on and 1 or nil
    lastCount, lastAt = nil, nil
end

-- what happened, in words, for one event's line
local function What(e)
    local kind = e.kind
    if kind == "on" then return "debug on" .. (e.day and (" " .. e.day) or "") end
    if kind == "off" then return "debug off" end
    if kind == "zone" then return "loading screen" end
    if kind == "login" then return "login: " .. tostring(e.step) .. " | bags " .. tostring(e.bags) end
    if kind == "mark" then return "mark " .. tostring(e.name) end
    if kind == "press" then
        return "press: " .. tostring(e.decision)
            .. (e.channel and (", channeling " .. e.channel) or "")
            .. (e.circle and ", targeting circle up" or "")
    end
    if kind == "deleted" then return "deleted " .. tostring(e.slot) end
    if kind == "failed" then return "delete failed: " .. tostring(e.why) end
    if kind == "sorted" then return "sorted: " .. tostring(e.moves) end
    if kind == "sortnote" then return "sort noted: in a fight" end
    if kind == "sortrun" then return "noted sort runs: the fight is over" end
    if kind == "mute" then return "move sounds muted for " .. tostring(e.what) end
    if kind == "unmute" then return "move sounds back on after " .. tostring(e.what) end
    if kind == "chat" then return "SSF printed: " .. tostring(e.text) end
    if kind == "sound" then return "SSF played: " .. tostring(e.name) end
    if kind == "bags" then return "bags changed" end
    if kind == "combat" then return "combat " .. tostring(e.state) end
    if kind == "channel" then return "channel " .. tostring(e.state) .. (e.spell and (" " .. e.spell) or "") end
    return tostring(kind)
end

local function Line(e)
    local flags = (e.lock and " [lock]" or "") .. (e.combat and " [combat]" or "")
    local delta = e.delta and (" (%+d)"):format(e.delta) or ""
    local line = ("%s %.2f%s %s | count %s/%s%s cap %s"):format(
        e.clock or "?", e.t or 0, flags, What(e), tostring(e.count), tostring(e.game), delta, tostring(e.cap))
    if e.at then line = line .. " | " .. (e.at ~= "" and e.at or "no shards") end
    return line
end

function Debug:Text()
    local log = self:Log()
    if not sessionStart or sessionStart > #log then return "Nothing recorded this session." end
    local lines = {
        ("SSF %s debug report: %d events this session"):format(SSF.VERSION, #log - sessionStart + 1),
        "count is SSF's/the game's; [lock] and [combat] mean in a fight; positions are bag:slot",
    }
    for i = sessionStart, #log do lines[#lines + 1] = Line(log[i]) end
    return table.concat(lines, "\n")
end
