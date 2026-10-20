-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- wow_stub: the smallest WoW environment that lets Ace3 and SSF's logic modules load in
-- plain Lua, outside the game. Frames are inert tables that accept any method. The
-- container API reads from WoW.bags, a table the tests fill. Nothing here is a faithful
-- copy of the game; it is exactly what the loaded files call, and no more.
--
-- Public:  WoW.bags[bagId] = { slots = n, family = bits, items = { [slot] = itemId },
--                              locked = { [slot] = true } }
--          WoW.SetBags(table)          replace every bag at once (nil = all empty)
--          WoW.FireEvent(name, ...)    deliver a game event to every frame registered for it
--          WoW.combat = false          what InCombatLockdown / UnitAffectingCombat answer
--          WoW.chat                    every line printed through DEFAULT_CHAT_FRAME
-- Touches nothing else.

local WoW = { bags = {}, combat = false, chat = {}, frames = {} }
_G.WoW = WoW

-- Lua 5.1 names the game has and Lua 5.4 does not
unpack = unpack or table.unpack
loadstring = loadstring or load
if not getfenv then
    getfenv = function() return _G end
    setfenv = function() end
end
if not bit then
    if _VERSION == "Lua 5.1" then
        bit = require("bit")
    else
        bit = load([[return {
            band = function(a, b) return a & b end,
            bor  = function(a, b) return a | b end,
            bxor = function(a, b) return a ~ b end,
            bnot = function(a) return ~a end,
        }]])()
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

-- Player, class, locale
function UnitClassBase() return "WARLOCK" end
function UnitClass() return "Warlock", "WARLOCK" end
function UnitName() return "Tester" end
function UnitNameUnmodified() return "Tester" end
function UnitRace() return "Undead", "Scourge" end
function UnitFactionGroup() return "Horde" end
function GetRealmName() return "Hrodbar" end
function GetLocale() return "enUS" end
function GetCurrentRegion() return 1 end
function GetBuildInfo() return "1.15.0", "70124", "2026-10-01", 16001 end
function GetCurrentRegionName() return "US" end
function IsLoggedIn() return true end
GAME_LOCALE = nil
C_GameRules = { IsGameRuleActive = function() return false end }
Enum = Enum or {}
Enum.GameRule = { HardcoreRuleset = 1, RPRuleset = 2, PvPRuleset = 3 }
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
Enum = Enum or {}
Enum.BagIndex = { Backpack = 0, ReagentBag = 5 }
Constants = { InventoryConstants = { NumBagSlots = 4 } }
local SOUL_FAMILY = 1 -- the soul bag family bit; GetItemFamily(6265) answers the same

local function bagOf(id) return WoW.bags[id] end

function WoW.SetBags(t) WoW.bags = t or {} end

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
    GetItemFamily = function(itemId) return itemId == 6265 and SOUL_FAMILY or 0 end,
}
ClearCursor = function() end
GetCursorInfo = function() return nil end
DeleteCursorItem = function() end

return WoW
