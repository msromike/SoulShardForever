-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- wow_stub: the smallest WoW environment that lets Ace3 and SSF's logic modules load in
-- plain Lua, outside the game. Frames are inert tables that accept any method. The
-- container API reads from WoW.bags, a table the tests fill. Nothing here is a faithful
-- copy of the game: it is what the loaded files call, plus the common WoW globals a new
-- module is likely to touch, so adding one to the runner rarely needs a stub edit.
--
-- Public:  WoW.bags[bagId] = { slots = n, family = bits, items = { [slot] = itemId },
--                              locked = { [slot] = true } }
--          WoW.SoulBag(slots, items, locked), WoW.PlainBag(...) -- one bag table each
--          WoW.SetBags(table)          replace every bag at once (nil = all empty)
--          WoW.picks                   every PickupContainerItem call as { bag, slot }
--          WoW.FireEvent(name, ...)    deliver a game event to every frame registered for it
--          WoW.frames                  every frame CreateFrame made
--          WoW.combat = false          what InCombatLockdown / UnitAffectingCombat answer
--          WoW.chat                    every line printed through DEFAULT_CHAT_FRAME
-- Touches nothing else.

local WoW = { bags = {}, combat = false, chat = {}, frames = {} }
_G.WoW = WoW

-- The tests run on Lua 5.1, the game's own. The game gives every addon a global `bit`
-- (LuaBitOp); plain Lua 5.1 has none, so here it is in arithmetic, 32 bits, for
-- non-negative numbers (all SSF passes it: bag family flags)
assert(_VERSION == "Lua 5.1", "run the tests on Lua 5.1 (lua51), the game's Lua")
local function BitOp(a, b, keep)
    local result, place = 0, 1
    a, b = a % 2 ^ 32, b % 2 ^ 32
    for _ = 1, 32 do
        local x, y = a % 2, b % 2
        if keep(x, y) then result = result + place end
        a, b, place = (a - x) / 2, (b - y) / 2, place * 2
    end
    return result
end
bit = bit or {
    band = function(a, b) return BitOp(a, b, function(x, y) return x == 1 and y == 1 end) end,
    bor  = function(a, b) return BitOp(a, b, function(x, y) return x == 1 or y == 1 end) end,
    bxor = function(a, b) return BitOp(a, b, function(x, y) return x ~= y end) end,
    bnot = function(a) return 2 ^ 32 - 1 - a % 2 ^ 32 end,
}

-- The game's xpcall passes its extra arguments on to the function (as Lua 5.2 does); plain
-- 5.1's drops them, and Ace3's safecall (AceAddon's OnInitialize/OnEnable) relies on them.
-- Set before any library loads, since each captures xpcall as a local.
do
    local plainXpcall = xpcall
    xpcall = function(f, handler, ...)
        local n, args = select("#", ...), { ... }
        return plainXpcall(function() return f(unpack(args, 1, n)) end, handler)
    end
end

-- WoW's global string and table helpers
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
tinsert, tremove = table.insert, table.remove
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
strsplit = function(sep, s, n)
    local out = {}
    for piece in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = piece end
    return unpack(out)
end
strjoin = function(sep, ...) return table.concat({ ... }, sep) end
strmatch, strfind, strsub, strlen = string.match, string.find, string.sub, string.len
strupper, strlower, format, gsub = string.upper, string.lower, string.format, string.gsub
tostringall = function(...)
    local t = { ... }
    for i = 1, select("#", ...) do t[i] = tostring(t[i]) end
    return unpack(t)
end
geterrorhandler = function() return function(err) error(err, 2) end end
seterrorhandler = function() end
GetTime = os.clock
debugstack = function() return "" end
issecurevariable = function() return false end
securecall = function(f, ...) return f(...) end
hooksecurefunc = function(tbl, name, fn)
    if type(tbl) == "string" then tbl, name, fn = _G, tbl, name end
    local orig = tbl[name]
    tbl[name] = function(...) local r = { orig(...) } fn(...) return unpack(r) end
end

-- Frames: any method call is accepted and returns nothing, except the few below.
local frameMethods = {}
local frameMeta = { __index = function(_, k) return frameMethods[k] or function() end end }
function frameMethods:RegisterEvent(ev) self.__events[ev] = true end
function frameMethods:UnregisterEvent(ev) self.__events[ev] = nil end
function frameMethods:UnregisterAllEvents() wipe(self.__events) end
function frameMethods:IsEventRegistered(ev) return self.__events[ev] == true end
function frameMethods:SetScript(name, fn) self.__scripts[name] = fn end
function frameMethods:GetScript(name) return self.__scripts[name] end
function frameMethods:HookScript(name, fn)
    local orig = self.__scripts[name]
    self.__scripts[name] = function(...) if orig then orig(...) end fn(...) end
end
function frameMethods:Show() self.__shown = true end
function frameMethods:Hide() self.__shown = false end
function frameMethods:IsShown() return self.__shown == true end
function frameMethods:IsVisible() return self.__shown == true end
function frameMethods:GetWidth() return self.__w or 0 end
function frameMethods:GetHeight() return self.__h or 0 end
function frameMethods:SetWidth(w) self.__w = w end
function frameMethods:SetHeight(h) self.__h = h end
function frameMethods:SetSize(w, h) self.__w, self.__h = w, h end
function frameMethods:GetName() return self.__name end
function frameMethods:GetParent() return self.__parent end
function frameMethods:SetText(t) self.__text = t end
function frameMethods:GetText() return self.__text end
function frameMethods:GetObjectType() return self.__type end
function frameMethods:CreateFontString() return CreateFrame("FontString", nil, self) end
function frameMethods:CreateTexture() return CreateFrame("Texture", nil, self) end
function frameMethods:GetChildren() return end
function frameMethods:GetRegions() return end
function frameMethods:GetStringWidth() return 0 end

function CreateFrame(ftype, name, parent)
    local f = setmetatable({ __type = ftype, __name = name, __parent = parent, __events = {}, __scripts = {}, __shown = true }, frameMeta)
    if name then _G[name] = f end
    WoW.frames[#WoW.frames + 1] = f
    return f
end

function WoW.FireEvent(name, ...)
    for _, f in ipairs(WoW.frames) do
        local handler = f.__scripts.OnEvent
        if handler and f.__events[name] then handler(f, name, ...) end
    end
end

UIParent = CreateFrame("Frame", "UIParent")
UIParent.__w, UIParent.__h = 1920, 1080
GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
DEFAULT_CHAT_FRAME = CreateFrame("Frame", "DEFAULT_CHAT_FRAME")
function DEFAULT_CHAT_FRAME:AddMessage(msg) WoW.chat[#WoW.chat + 1] = msg end
ChatFrame1 = DEFAULT_CHAT_FRAME
SELECTED_CHAT_FRAME = DEFAULT_CHAT_FRAME
SlashCmdList, hash_SlashCmdList = {}, {}
UISpecialFrames = {}
GameFontNormal, GameFontNormalLarge = {}, {}
C_Timer = { After = function() end }
C_UIFileAsset = { IsKnownFile = function() return true end } -- LibSharedMedia checks its media files
C_Sound = { PlaySound = function() end }
PlaySoundFile = function() end

-- Player, class, locale
function UnitClassBase() return "WARLOCK" end
function UnitClass() return "Warlock", "WARLOCK" end
function UnitName() return "Tester" end
-- Forever names a character "Name Surname" (regional unique names); AceDB 39 keys the
-- profile "Tester Hrodbar" from this, where AceDB 36 keyed it "Tester - PvE"
function UnitNameUnmodified() return "Tester", "Hrodbar" end
function RegionalUniqueNamesEnabled() return true end
function UnitRace() return "Undead", "Scourge" end
function UnitFactionGroup() return "Horde" end
function GetRealmName() return "Hrodbar" end
-- spells: known unless a test lists it in WoW.unknownSpells (Cap's quiet state)
WoW.unknownSpells = {}
function IsPlayerSpell(id) return not WoW.unknownSpells[id] end
C_SpellBook = { IsSpellKnown = function(id) return not WoW.unknownSpells[id] end }
function GetLocale() return "enUS" end
function GetCurrentRegion() return 1 end
function GetBuildInfo() return "1.15.0", "70124", "2026-10-01", 16001 end
function GetCurrentRegionName() return "US" end
function IsLoggedIn() return true end
GAME_LOCALE = nil
C_GameRules = { IsGameRuleActive = function() return false end }
Enum = { GameRule = { HardcoreRuleset = 1, RPRuleset = 2, PvPRuleset = 3 } }
securecallfunction = function(f, ...) return f(...) end
strlenutf8 = function(s) local _, n = s:gsub("[^\128-\193]", "") return n end
debugprofilestop = function() return os.clock() * 1000 end
GetAddOnMetadata = function(...) return C_AddOns.GetAddOnMetadata(...) end
function InCombatLockdown() return WoW.combat end
function UnitAffectingCombat() return WoW.combat end
RAID_CLASS_COLORS = { WARLOCK = { r = 0.53, g = 0.53, b = 0.93 } }
C_AddOns = { GetAddOnMetadata = function(_, field) return field == "Version" and "test" or nil end }

-- Bags
NUM_BAG_SLOTS = 4
Enum.BagIndex = { Backpack = 0, ReagentBag = 5 }
Constants = { InventoryConstants = { NumBagSlots = 4 } }
local SHARD = 6265      -- the shard item (Core's SSF.SHARD_ITEM_ID; the stub loads before Core)
local SOUL_FAMILY = 1   -- the soul bag family bit; GetItemFamily(SHARD) answers the same

local function bagOf(id) return WoW.bags[id] end

function WoW.SetBags(t) WoW.bags = t or {} end
function WoW.SoulBag(slots, items, locked) return { slots = slots, family = SOUL_FAMILY, items = items or {}, locked = locked } end
function WoW.PlainBag(slots, items, locked) return { slots = slots, family = 0, items = items or {}, locked = locked } end

C_Container = {
    GetContainerNumSlots = function(id) local b = bagOf(id) return b and b.slots or 0 end,
    GetContainerItemID = function(id, slot) local b = bagOf(id) return b and b.items and b.items[slot] or nil end,
    GetContainerNumFreeSlots = function(id)
        local b = bagOf(id)
        if not b then return 0, 0 end
        local used = 0
        for _ in pairs(b.items or {}) do used = used + 1 end
        return b.slots - used, b.family or 0
    end,
}
ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
C_Item = {
    DoesItemExist = function(loc) local b = bagOf(loc.bag) return b and b.items and b.items[loc.slot] ~= nil or false end,
    IsLocked = function(loc) local b = bagOf(loc.bag) return b and b.locked and b.locked[loc.slot] == true or false end,
    GetItemFamily = function(itemId) return itemId == SHARD and SOUL_FAMILY or 0 end,
}
-- Cursor: PickupContainerItem is recorded in WoW.picks as { bag, slot } pairs, so a test can
-- read the moves a Sorter pass fired; nothing is actually moved in the fake bags.
WoW.picks = {}
C_Container.PickupContainerItem = function(bag, slot) WoW.picks[#WoW.picks + 1] = { bag, slot } end
ClearCursor = function() end
GetCursorInfo = function() return nil end
DeleteCursorItem = function() end

return WoW
