-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- wow_stub: the game, for every test. Enough of WoW's Lua environment that the Ace
-- libraries and the whole of SSF load and run in plain Lua 5.1: frames with parents and
-- children that are shown or hidden, enabled or greyed, and carry a text; events; timers
-- that wait until a test runs them; the bags, with a cursor that really moves and deletes
-- items once the server confirms (WoW.Settle); the player. Nothing has a size or a place that means anything, so nothing here
-- can say how SSF looks, only what it does and what is in its window.
--
-- Strict on purpose, in two steps. First the game's own answer: a method the frame's kind
-- and its templates do not have in this client (tests/frame_methods.lua, written by the
-- check from the client's API docs) raises "the game has no method X on a <kind>", as the
-- game would. Then this file's: a method the game has but this file does not know raises
-- an error that names it. A method is known one of three ways: it is written out below (it
-- keeps state a test reads), it is on a short list of answers (GET, MANY), or its name
-- starts with a word on SETTERS (it changes how a frame is drawn, which nothing here
-- tracks). CreateFrame takes a kind in any case, as the game does. An error the game
-- would show in red (Ace hands those to the error handler and carries on) is kept in
-- WoW.errors, so a runner fails on it instead of never seeing it.
--
-- Public:  WoW.bags[bagId] = { slots = n, family = bits, items = { [slot] = itemId },
--                              locked = { [slot] = true } }
--          WoW.SoulBag(slots, items, locked), WoW.PlainBag(...) -- one bag table each
--          WoW.SetBags(table)          replace every bag at once (nil = all empty); the
--                                      cursor is emptied and nothing asked for is waiting
--          WoW.Forget()                drop every move and delete asked for and not yet
--                                      confirmed (SetBags calls it)
--          WoW.cursor                  { bag, slot, item } while an item is held, else nil
--          WoW.picks                   every PickupContainerItem call as { bag, slot }
--          WoW.deleted                 every item a delete was asked for, as { bag, slot, item }
--          WoW.Settle()                the server confirms: every move and delete asked for
--                                      since the last one now shows in the bags, the bag
--                                      events go out and their timers run. Until then the
--                                      bags still show each item where it was, as in the game
--          WoW.FireEvent(name, ...)    deliver a game event to every frame registered for it
--          WoW.RunTimers()             run every C_Timer callback waiting, and any those
--                                      queue, until none is left, in the order they fall
--                                      due; a cancelled one is skipped
--          WoW.now                     the clock GetTime answers: it stands still between
--                                      timers and moves to each one's due time as it fires
--          WoW.ClearTimers()           forget every callback waiting (a runner, between tests)
--          WoW.errors                  every error the game's error handler was handed,
--                                      each with where it came from
--          WoW.frames                  every frame CreateFrame made; each has __parent,
--                                      __children, __shown, __enabled, __text
--          WoW.Controls(root, rank) -> a list of { kind, text, shown, enabled, depth, place }
--                                      for root and everything under it that carries a
--                                      text, and for every button with a click and no text
--                                      ({ template, art } in place of text). rank(frame)
--                                      -> a number or nil, optional: a frame takes the
--                                      rank of the nearest frame up the tree that has
--                                      one, and the list is in rank order, then the order
--                                      frames were made
--          WoW.Drag(handle, top, left) a player's drag on handle: the mouse goes down on
--                                      it, whatever frame its OnMouseDown starts moving
--                                      ends at top, left (GetTop, GetLeft), the mouse
--                                      comes up
--          WoW.combat = false          what InCombatLockdown / UnitAffectingCombat answer
--          WoW.flagged = nil           true: UnitAffectingCombat answers true while
--                                      InCombatLockdown still answers false (the moment a
--                                      fight starts, before the lockdown is on)
--          WoW.channel = nil           the spell name UnitChannelInfo answers
--          WoW.targeting = nil         true: SpellIsTargeting answers true
--          WoW.itemCount = nil         a number: what C_Item.GetItemCount answers, in place
--                                      of counting the fake bags
--          WoW.unknownSpells[id]       true: C_SpellBook.IsSpellKnown(id) answers false
--          WoW.SetMacros(account, character)  the macros that exist, as two lists of names
--                                      (account slots 1-120, character slots from 121, as
--                                      the game numbers them); SSF's two are account
--                                      macros by default
--          WoW.macroList               { account = {...}, character = {...} }, each macro
--                                      { name, icon, body }; CreateMacro adds to it
--          WoW.macroWindow             Blizzard's macro window once ShowMacroFrame opened
--                                      it: { shown, tab, selected }
--          WoW.redErrors               every line put in the game's red error text
--          WoW.actionText[slot]        the macro name an action slot shows (C_ActionBar)
--          WoW.blocked                 every protected call refused under combat lockdown
--                                      (CreateMacro, a secure button's SetAttribute); each
--                                      is also an error, so the test that let it through
--                                      fails
--          WoW.chat                    every line printed through DEFAULT_CHAT_FRAME
--          WoW.muted                   the sound file IDs muted right now (MuteSoundFile
--                                      adds, UnmuteSoundFile removes)
-- Touches nothing else.

local STUB_ROOT = ... -- the addon's folder (tests/load.lua passes it): frame_methods.lua is read from it
local WoW = { bags = {}, combat = false, chat = {}, frames = {}, errors = {} }
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
string.split = strsplit -- the game puts it on every string: ("a\001b"):split("\001") (AceGUI's TreeGroup)
strjoin = function(sep, ...) return table.concat({ ... }, sep) end
strmatch, strfind, strsub, strlen = string.match, string.find, string.sub, string.len
strupper, strlower, format, gsub = string.upper, string.lower, string.format, string.gsub
tostringall = function(...)
    local t = { ... }
    for i = 1, select("#", ...) do t[i] = tostring(t[i]) end
    return unpack(t)
end
seterrorhandler = function() end
date = os.date
debugstack = function() return "" end
issecurevariable = function() return false end
securecall = function(f, ...) return f(...) end
hooksecurefunc = function(tbl, name, fn)
    if type(tbl) == "string" then tbl, name, fn = _G, tbl, name end
    local orig = tbl[name]
    tbl[name] = function(...) local r = { orig(...) } fn(...) return unpack(r) end
end

-- Errors: Ace runs OnEnable, events, timers and callbacks through the game's error handler,
-- which shows the red error and carries on. Here each one is kept, so the caller can fail
-- on them: an error the game would have shown is never swallowed.
geterrorhandler = function()
    return function(err) WoW.errors[#WoW.errors + 1] = tostring(err) .. "\n" .. debug.traceback("", 2) end
end

-- Lua and string helpers the libraries capture at load
table.wipe = wipe
max, min, floor, ceil, abs = math.max, math.min, math.floor, math.ceil, math.abs
tContains = function(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
CopyTable = function(t)
    local out = {}
    for k, v in pairs(t) do out[k] = type(v) == "table" and CopyTable(v) or v end
    return out
end

-- Timers: queued with the time each falls due, run when a test says time passes. The
-- clock (GetTime) stands still until then, and moves to each timer's due time as it fires,
-- so timers fire in the order they fall due, the earlier-made first on a tie, as in the game.
WoW.now = 1000
GetTime = function() return WoW.now end
local timers, made = {}, 0
local function Queue(delay, fn)
    made = made + 1
    local t = { due = WoW.now + math.max(tonumber(delay) or 0, 0), seq = made, fn = fn }
    timers[#timers + 1] = t
    return t
end
C_Timer = {
    After = function(delay, fn) Queue(delay, fn) end,
    NewTimer = function(delay, fn)
        local t = Queue(delay, fn)
        return { Cancel = function() t.cancelled = true end, IsCancelled = function() return t.cancelled == true end }
    end,
    NewTicker = function() return { Cancel = function() end } end,
}
function WoW.ClearTimers() timers = {} end
function WoW.RunTimers()
    local fired = 0
    while #timers > 0 do
        local first = 1
        for i, t in ipairs(timers) do
            local f = timers[first]
            if t.due < f.due or (t.due == f.due and t.seq < f.seq) then first = i end
        end
        local t = table.remove(timers, first)
        WoW.now = math.max(WoW.now, t.due)
        if not t.cancelled then
            fired = fired + 1
            assert(fired < 1000, "timers keep queueing timers")
            t.fn()
        end
    end
end

-- ---------------------------------------------------------------- frames

local M = {}

-- a part of a frame the game makes on demand (a button's textures, its text): one per name
local function Part(self, key, kind)
    local parts = rawget(self, "__parts")
    if not parts then parts = {} rawset(self, "__parts", parts) end
    if not parts[key] then parts[key] = CreateFrame(kind, nil, self) end
    return parts[key]
end

-- events and scripts
function M:RegisterEvent(ev) self.__events[ev] = true end
function M:RegisterUnitEvent(ev) self.__events[ev] = true end
function M:UnregisterEvent(ev) self.__events[ev] = nil end
function M:UnregisterAllEvents() wipe(self.__events) end
function M:IsEventRegistered(ev) return self.__events[ev] == true end
function M:SetScript(name, fn) self.__scripts[name] = fn end
function M:GetScript(name) return self.__scripts[name] end
function M:HasScript() return true end
function M:HookScript(name, fn)
    local orig = self.__scripts[name]
    self.__scripts[name] = function(...) if orig then orig(...) end fn(...) end
end
local function Run(self, name, ...)
    local fn = self.__scripts[name]
    if fn then fn(self, ...) end
end
-- moving: StartMoving makes the frame follow the mouse until StopMovingOrSizing; where it
-- ends is its top and left, which a drag sets
function M:StartMoving() WoW.moving = self end
function M:StopMovingOrSizing() if WoW.moving == self then WoW.moving = nil end end
function M:GetTop() return self.__top or 0 end
function M:GetLeft() return self.__left or 0 end
function WoW.Drag(handle, top, left)
    Run(handle, "OnMouseDown", "LeftButton")
    if WoW.moving then WoW.moving.__top, WoW.moving.__left = top, left end
    Run(handle, "OnMouseUp", "LeftButton")
end
function M:Click(button)
    if self.__enabled == false then return end
    Run(self, "PreClick", button or "LeftButton")
    Run(self, "OnClick", button or "LeftButton")
    Run(self, "PostClick", button or "LeftButton")
end

-- shown and hidden: the script fires when the frame's own state changes
function M:Show()
    if self.__shown then return end
    self.__shown = true
    Run(self, "OnShow")
end
function M:Hide()
    if not self.__shown then return end
    self.__shown = false
    Run(self, "OnHide")
end
function M:SetShown(on) if on then self:Show() else self:Hide() end end
function M:IsShown() return self.__shown == true end
function M:IsVisible()
    local f = self
    while f do
        if not f.__shown then return false end
        f = f.__parent
    end
    return true
end

-- enabled and greyed
function M:Enable() self.__enabled = true end
function M:Disable() self.__enabled = false end
function M:SetEnabled(on) self.__enabled = on and true or false end
function M:IsEnabled() return self.__enabled ~= false end

-- the tree
local function Unlink(self)
    local parent = self.__parent
    if not parent then return end
    for i, child in ipairs(parent.__children) do
        if child == self then table.remove(parent.__children, i) break end
    end
end
function M:SetParent(parent)
    Unlink(self)
    self.__parent = parent
    if parent then parent.__children[#parent.__children + 1] = self end
end
function M:GetParent() return self.__parent end
local REGIONS = { FontString = true, Texture = true, MaskTexture = true, Line = true }
local function Kids(self, regions)
    local out = {}
    for _, child in ipairs(self.__children) do
        if (REGIONS[child.__type] or false) == regions then out[#out + 1] = child end
    end
    return unpack(out)
end
function M:GetChildren() return Kids(self, false) end
function M:GetRegions() return Kids(self, true) end
function M:GetNumChildren() return select("#", Kids(self, false)) end
function M:GetName() return self.__name end
function M:GetObjectType() return self.__type end
function M:IsObjectType(kind) return self.__type == kind end
function M:GetDebugName() return self.__name or self.__type end

-- text
function M:SetText(text) self.__text = text end
function M:GetText() return self.__text end
function M:SetFormattedText(fmt, ...) self.__text = fmt:format(...) end
function M:GetNumber() return tonumber(self.__text) or 0 end
function M:SetNumber(n) self.__text = tostring(n) end

-- values a control holds
function M:SetChecked(on) self.__checked = on and true or false end
function M:GetChecked() return self.__checked == true end
function M:SetValue(v) self.__value = v end
function M:GetValue() return self.__value or 0 end
function M:SetMinMaxValues(lo, hi) self.__min, self.__max = lo, hi end
function M:GetMinMaxValues() return self.__min or 0, self.__max or 0 end
function M:SetAttribute(key, value)
    -- a secure frame's attributes are locked in combat (Refused is defined below, before any call)
    if tostring(self.__template or ""):find("Secure", 1, true) and WoW.Refused("SetAttribute on a secure frame") then return end
    self.__attributes = self.__attributes or {}
    self.__attributes[key] = value
end
function M:GetAttribute(key) return self.__attributes and self.__attributes[key] end
function M:SetTexture(texture) self.__texture = texture end
function M:GetTexture() return self.__texture end
function M:SetAlpha(a) self.__alpha = a end
function M:GetAlpha() return self.__alpha or 1 end
function M:SetFrameLevel(n) self.__level = n end
function M:GetFrameLevel() return self.__level or 1 end
function M:SetScrollChild(child) self.__scrollChild = child end
function M:GetScrollChild() return self.__scrollChild end
function M:SetID(id) self.__id = id end
function M:GetID() return self.__id or 0 end

-- sizes: kept, never meaningful
function M:SetWidth(w) self.__w = w end
function M:SetHeight(h) self.__h = h end
function M:SetSize(w, h) self.__w, self.__h = w, h end
function M:GetWidth() return self.__w or 0 end
function M:GetHeight() return self.__h or 0 end
function M:GetSize() return self.__w or 0, self.__h or 0 end

-- parts
function M:CreateFontString() return CreateFrame("FontString", nil, self) end
function M:CreateTexture() return CreateFrame("Texture", nil, self) end
function M:CreateMaskTexture() return CreateFrame("MaskTexture", nil, self) end
function M:CreateLine() return CreateFrame("Line", nil, self) end
function M:CreateAnimationGroup() return CreateFrame("AnimationGroup", nil, self) end
function M:CreateAnimation(kind) return CreateFrame(kind or "Animation", nil, self) end
function M:GetFontString() return Part(self, "FontString", "FontString") end
for _, name in ipairs({ "Normal", "Pushed", "Highlight", "Disabled", "Checked", "DisabledChecked", "Thumb" }) do
    M["Get" .. name .. "Texture"] = function(self) return Part(self, name, "Texture") end
    M["Set" .. name .. "Texture"] = function(self, texture) Part(self, name, "Texture").__texture = texture end
end

-- GameTooltip
function M:SetOwner(owner) self.__owner = owner end
function M:GetOwner() return self.__owner end
function M:IsOwned(owner) return self.__owner == owner end
function M:AddLine() end
function M:AddDoubleLine() end
function M:NumLines() return 0 end

-- Answers with no state behind them. Each is what a frame of no size at no place says.
local GET = {
    GetRight = 0, GetBottom = 0, GetStringHeight = 12, GetLineHeight = 12,
    GetNumLines = 1, GetNumPoints = 1, GetEffectiveScale = 1, GetScale = 1, GetFrameStrata = "MEDIUM",
    GetCursorPosition = 0, GetVerticalScroll = 0, GetHorizontalScroll = 0, GetVerticalScrollRange = 0,
    GetJustifyH = "LEFT", GetJustifyV = "MIDDLE", GetValueStep = 1,
    IsMouseOver = false, IsDragging = false, IsMovable = false, IsResizable = false, IsUserPlaced = false,
    IsMouseEnabled = true, IsForbidden = false, IsProtected = false, IsTruncated = false,
    IsKeyboardEnabled = false, HasFocus = false, IsMouseMotionFocus = false, IsClampedToScreen = true,
    CanChangeAttribute = true, IsPlaying = false, IsDone = true,
}
-- four of one number: a rectangle of no size, or a color nobody reads (r, g, b, a). Built,
-- not typed, so no color is written outside Colors (the check's rule holds for tests too)
local function Four(n) return function() return n, n, n, n end end
local MANY = {
    GetCenter = function() return 0, 0 end,
    GetRect = Four(0),
    GetPoint = function() return "CENTER", UIParent, "CENTER", 0, 0 end,
    GetFont = function() return "font", 12, "" end,
    GetTextColor = Four(1),
    GetVertexColor = Four(1),
    GetBackdropColor = Four(1),
    GetBackdropBorderColor = Four(1),
    GetHitRectInsets = Four(0),
    GetClampRectInsets = Four(0),
    GetStringWidth = function(self) return #tostring(self.__text or "") * 7 end,
    GetUnboundedStringWidth = function(self) return #tostring(self.__text or "") * 7 end,
    GetWrappedWidth = function(self) return #tostring(self.__text or "") * 7 end,
    GetFontObject = function(self) return Part(self, "FontObject", "Font") end,
    GetNormalFontObject = function(self) return Part(self, "FontObject", "Font") end,
}

-- A method whose name starts with one of these changes how or when a frame is drawn or
-- takes input. Nothing here tracks that, so it is accepted and does nothing.
local SETTERS = { "Set", "Clear", "Enable", "Disable", "Register", "Unregister", "Raise", "Lower", "Start", "Stop",
    "Play", "Pause", "Finish", "Highlight", "Insert", "Lock", "Unlock", "Add", "Remove", "Apply", "Update", "Toggle" }
local function Nothing() end
local function IsSetter(k)
    for _, word in ipairs(SETTERS) do
        if k:find("^" .. word .. "%u") or k == word then return true end
    end
end

-- What the game itself has: every method each frame kind has in this client, and what each
-- template adds (tests/frame_methods.lua, written by tools/check.py from the client's own
-- API docs). A method the frame's kind and templates do not have is an error here, as it is
-- in the game, even when its name looks like a setter.
local KNOWN = assert(loadfile((STUB_ROOT or ".") .. "/tests/frame_methods.lua"))()
local function GameHas(f, k)
    local kind = rawget(f, "__type")
    local known = KNOWN.kinds[kind]
    if not known then error("wow_stub: tests/frame_methods.lua has no frame kind " .. tostring(kind), 3) end
    if known[k] then return true end
    for word in tostring(rawget(f, "__template") or ""):gmatch("[^,%s]+") do
        local adds = KNOWN.templates[word]
        if adds and adds[k] then return true end
    end
    return false
end

local meta = {}
meta.__index = function(f, k)
    if type(k) ~= "string" or not k:find("^%u") then return nil end -- a field (frame.obj), not a method
    if not GameHas(f, k) then
        error(("wow_stub: the game has no method %s on a %s"):format(k, tostring(rawget(f, "__type"))), 2)
    end
    if M[k] then return M[k] end
    if MANY[k] then return MANY[k] end
    if GET[k] ~= nil then local v = GET[k] return function() return v end end
    if IsSetter(k) then return Nothing end
    error("wow_stub: no frame method " .. k .. " (add it to tests/wow_stub.lua on purpose)", 2)
end

-- Blizzard templates that come with named children the libraries reach by name
local TEMPLATE_CHILDREN = {
    UIDropDownMenuTemplate = { Left = "Texture", Middle = "Texture", Right = "Texture", Button = "Button",
                               Text = "FontString", Icon = "Texture" },
    UIPanelScrollBarTemplate = { ScrollUpButton = "Button", ScrollDownButton = "Button", ThumbTexture = "Texture" },
    OptionsSliderTemplate = { Text = "FontString", Low = "FontString", High = "FontString" },
    UIPanelScrollFrameTemplate = { ScrollBar = "Slider" }, -- AceGUI's MultiLineEditBox (the debug report window)
}

-- The game takes a frame kind in any case ("BUTTON") and answers GetObjectType with its own spelling
local KIND_NAMES = {}
for kind in pairs(KNOWN.kinds) do KIND_NAMES[kind:lower()] = kind end

local frames = WoW.frames
local made = 0
function CreateFrame(kind, name, parent, template)
    kind = KIND_NAMES[tostring(kind):lower()] or kind
    made = made + 1
    local f = setmetatable({ __type = kind, __name = name, __events = {}, __scripts = {}, __children = {},
                             __shown = true, __order = made, __template = template,
                             [0] = newproxy() }, meta) -- [0]: the game's own handle, a userdata; AceTab tests for it
    if parent then
        f.__parent = parent
        parent.__children[#parent.__children + 1] = f
    end
    if name then _G[name] = f end
    frames[#frames + 1] = f
    for word in tostring(template or ""):gmatch("[^,%s]+") do
        for suffix, childKind in pairs(TEMPLATE_CHILDREN[word] or {}) do
            local child = CreateFrame(childKind, name and (name .. suffix) or nil, f)
            f[suffix] = child
        end
    end
    return f
end

function WoW.FireEvent(name, ...)
    for _, f in ipairs(WoW.frames) do
        local handler = f.__scripts.OnEvent
        if handler and f.__events[name] then handler(f, name, ...) end
    end
end

-- ---------------------------------------------------------------- the game's own frames and globals

UIParent = CreateFrame("Frame", "UIParent")
UIParent.__w, UIParent.__h = 1920, 1080
GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
DEFAULT_CHAT_FRAME = CreateFrame("Frame", "DEFAULT_CHAT_FRAME")
function DEFAULT_CHAT_FRAME:AddMessage(msg) WoW.chat[#WoW.chat + 1] = msg end
ChatFrame1 = DEFAULT_CHAT_FRAME
SELECTED_CHAT_FRAME = DEFAULT_CHAT_FRAME
SlashCmdList, hash_SlashCmdList = {}, {}
UISpecialFrames = {}
C_UIFileAsset = { IsKnownFile = function() return true end } -- LibSharedMedia checks its media files
C_Sound = { PlaySound = function() end }
PlaySoundFile = function() end
-- muted sound files: WoW.muted holds every file ID muted and not yet unmuted
WoW.muted = {}
MuteSoundFile = function(id) WoW.muted[id] = true end
UnmuteSoundFile = function(id) WoW.muted[id] = nil end

-- Globals the libraries and SSF's window read. Each is here because a file read it.
Minimap = CreateFrame("Minimap", "Minimap", UIParent)
WorldFrame = CreateFrame("Frame", "WorldFrame")
ChatFrame1EditBox = CreateFrame("EditBox", "ChatFrame1EditBox", UIParent)
NUM_CHAT_WINDOWS = 1
ChatEdit_GetActiveWindow = function() return nil end
for _, name in ipairs({ "GameFontNormal", "GameFontNormalLarge", "GameFontNormalSmall", "GameFontHighlight",
    "GameFontHighlightSmall", "GameFontHighlightLarge", "GameFontDisable", "GameFontDisableSmall",
    "GameFontWhite", "ChatFontNormal" }) do
    _G[name] = CreateFrame("Font", name)
end
-- the bag bar's buttons, each with the game's own stack number on it (the ItemButton's Count)
local function BagButton(name)
    local button = CreateFrame("Button", name, UIParent)
    button.Count = CreateFrame("FontString", name .. "Count", button)
    button.icon = CreateFrame("Texture", name .. "IconTexture", button)
end
for i = 0, 3 do BagButton("CharacterBag" .. i .. "Slot") end
BagButton("CharacterReagentBag0Slot")
ACCEPT, CANCEL, CLOSE, OKAY, NOT_BOUND = "Accept", "Cancel", "Close", "Okay", "Not Bound"
IsShiftKeyDown = function() return false end
IsControlKeyDown = function() return false end
IsAltKeyDown = function() return false end
GetCursorPosition = function() return 0, 0 end
GetScreenWidth = function() return 1920 end
GetScreenHeight = function() return 1080 end
PlaySound = function() end
SOUNDKIT = setmetatable({}, { __index = function() return 1 end })
GetCVarBool = function() return false end
CloseSpecialWindows = function() end
-- A call the game refuses from addon code under combat lockdown (a protected call: the game
-- blocks it and shows "Interface action failed because of an AddOn"). Recorded in
-- WoW.blocked and as an error, so a test that lets one through fails.
WoW.blocked = {}
local function Refused(call)
    if not WoW.combat then return false end
    WoW.blocked[#WoW.blocked + 1] = call
    WoW.errors[#WoW.errors + 1] = "ADDON_ACTION_BLOCKED: " .. call .. " under combat lockdown, refused by the game"
    return true
end
WoW.Refused = Refused

-- macros, numbered as the game numbers them: the account's in slots 1 to 120, the
-- character's from 121 (Constants.MacroConsts holds the two limits)
Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = 120, MAX_CHARACTER_MACROS = 30 } }
-- the action bars: WoW.actionText[slot] is the name of the macro in that slot
WoW.actionText = {}
C_ActionBar = { GetActionText = function(slot) return WoW.actionText[slot] end }
function WoW.SetMacros(account, character)
    WoW.macroList = { account = {}, character = {} }
    for _, name in ipairs(account or {}) do WoW.macroList.account[#WoW.macroList.account + 1] = { name = name } end
    for _, name in ipairs(character or {}) do WoW.macroList.character[#WoW.macroList.character + 1] = { name = name } end
end
-- the macro side of a clean start: both of SSF's macros exist (so the window offers no
-- "Create macros"), nothing on a bar, no macro window, no red line, nothing refused
function WoW.ResetMacros()
    WoW.SetMacros({ "SSF_LT", "SSF_BoA" }, {})
    WoW.macroWindow, WoW.redErrors, WoW.blocked = nil, {}, {}
    for k in pairs(WoW.actionText or {}) do WoW.actionText[k] = nil end
end
GetMacroIndexByName = function(name)
    for i, m in ipairs(WoW.macroList.account) do if m.name == name then return i end end
    for i, m in ipairs(WoW.macroList.character) do
        if m.name == name then return Constants.MacroConsts.MAX_ACCOUNT_MACROS + i end
    end
    return 0
end
GetNumMacros = function() return #WoW.macroList.account, #WoW.macroList.character end
GetMacroBody = function(index)
    local max = Constants.MacroConsts.MAX_ACCOUNT_MACROS
    local m = index > max and WoW.macroList.character[index - max] or WoW.macroList.account[index]
    return m and m.body
end
CreateMacro = function(name, icon, body, perCharacter)
    if Refused("CreateMacro") then return nil end
    local list = perCharacter and WoW.macroList.character or WoW.macroList.account
    list[#list + 1] = { name = name, icon = icon, body = body }
    WoW.FireEvent("UPDATE_MACROS")
    return GetMacroIndexByName(name)
end
-- Blizzard's macro window, loaded on demand by ShowMacroFrame: WoW.macroWindow holds the
-- tab and the macro it shows; its selector lists one button per macro, by name
function ShowMacroFrame()
    if not MacroFrame then
        MacroFrame = CreateFrame("Frame", "MacroFrame", UIParent)
        MacroFrame.ChangeTab = function(_, tab) WoW.macroWindow.tab = tab end
        MacroFrame.SelectMacro = function(_, index) WoW.macroWindow.selected = index end
        local selector = CreateFrame("Frame", nil, MacroFrame)
        selector.RunSetup = function() end
        selector.EnumerateButtons = function() return function() end end
        MacroFrame.MacroSelector = selector
    end
    WoW.macroWindow = { shown = true }
    MacroFrame:Show()
end
UIErrorsFrame = CreateFrame("MessageFrame", "UIErrorsFrame", UIParent)
UIErrorsFrame.AddExternalErrorMessage = function(_, text) WoW.redErrors[#WoW.redErrors + 1] = text end
WoW.ResetMacros()
C_Spell = { GetSpellName = function(id) return "Spell " .. id end }
-- Blizzard's settings panel: AceConfigDialog registers SSF's page in it at enable
Settings = {
    GetCategory = function() end,
    RegisterCanvasLayoutCategory = function(_, name) return { ID = name } end,
    RegisterCanvasLayoutSubcategory = function(_, _, name) return { ID = name } end,
    RegisterAddOnCategory = function() end,
}

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
C_SpellBook = { IsSpellKnown = function(id) return not WoW.unknownSpells[id] end }
function GetLocale() return "enUS" end
function GetCurrentRegion() return 1 end
function GetBuildInfo() return "1.15.0", "70124", "2026-10-01", 16001 end
function GetCurrentRegionName() return "US" end
function IsLoggedIn() return WoW.loggedIn == true end -- true from PLAYER_LOGIN on (tests/load.lua)
GAME_LOCALE = nil
C_GameRules = { IsGameRuleActive = function() return false end }
Enum = { GameRule = { HardcoreRuleset = 1, RPRuleset = 2, PvPRuleset = 3 } }
securecallfunction = function(f, ...) return f(...) end
strlenutf8 = function(s) local _, n = s:gsub("[^\128-\193]", "") return n end
debugprofilestop = function() return os.clock() * 1000 end
GetAddOnMetadata = function(...) return C_AddOns.GetAddOnMetadata(...) end
function InCombatLockdown() return WoW.combat end
function UnitAffectingCombat() return WoW.combat or WoW.flagged end
function UnitChannelInfo() return WoW.channel end
function SpellIsTargeting() return WoW.targeting == true end
RAID_CLASS_COLORS = { WARLOCK = { r = 0.53, g = 0.53, b = 0.93 } }
C_AddOns = { GetAddOnMetadata = function(_, field) return field == "Version" and "test" or nil end }

-- ---------------------------------------------------------------- the bags

-- Bags
NUM_BAG_SLOTS = 4
Enum.BagIndex = { Backpack = 0, ReagentBag = 5 }
Constants.InventoryConstants = { NumBagSlots = 4 }
local SHARD = 6265      -- the shard item (Core's SSF.SHARD_ITEM_ID; the stub loads before Core)
local SOUL_FAMILY = 1   -- the soul bag family bit; GetItemFamily(SHARD) answers the same

local function bagOf(id) return WoW.bags[id] end

function WoW.SetBags(t) WoW.bags = t or {} WoW.cursor = nil WoW.Forget() end
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
-- every move and delete asked for and not yet confirmed (see the cursor, below)
local pending = {}
function WoW.Forget() pending = {} end -- nothing asked for is still waiting
-- A slot is locked when a test set it so (the bag's own locked table) or when a move or a
-- delete asked for still waits on the server: the slot the item was taken from, and the
-- slot a move is going to. For a move that is how the game behaves; for a delete it is
-- taken to be the same, and no test here depends on which.
local function slotLocked(bag, slot)
    local b = bagOf(bag)
    if b and b.locked and b.locked[slot] == true then return true end
    for _, ask in ipairs(pending) do
        if ask.held.bag == bag and ask.held.slot == slot then return true end
        if ask.bag == bag and ask.slot == slot then return true end
    end
    return false
end
C_Item = {
    DoesItemExist = function(loc) local b = bagOf(loc.bag) return b and b.items and b.items[loc.slot] ~= nil or false end,
    IsLocked = function(loc) return slotLocked(loc.bag, loc.slot) end,
    GetItemFamily = function(itemId) return itemId == SHARD and SOUL_FAMILY or 0 end,
    -- the game's own count of an item across the bags; a test sets WoW.itemCount to make
    -- it disagree with the slots
    GetItemCount = function(itemId)
        if WoW.itemCount then return WoW.itemCount end
        local n = 0
        for _, b in pairs(WoW.bags) do
            for _, id in pairs(b.items or {}) do
                if id == itemId then n = n + 1 end
            end
        end
        return n
    end,
}
-- The cursor, and the server. A pickup with an empty cursor takes hold of the item in
-- that slot; a pickup while holding asks for the held item to go into that slot (whatever
-- is there goes back where the held item came from); DeleteCursorItem asks for the held
-- item to be deleted. As in the game, asking empties the cursor at once but the bags do
-- not change yet: they still show the item where it was until the server confirms, which
-- here is WoW.Settle(). Settle applies everything asked for, in order, then sends the bag
-- events the game sends and runs the timers they start (the bag bucket). Every pickup is
-- also recorded in WoW.picks, so a test can read what SSF asked for without settling. A
-- locked slot gives nothing and takes nothing, and a slot stays locked from the asking
-- until Settle (slotLocked, above).
WoW.picks = {}
WoW.deleted = {}
C_Container.PickupContainerItem = function(bag, slot)
    WoW.picks[#WoW.picks + 1] = { bag, slot }
    local b = bagOf(bag)
    if not b or slotLocked(bag, slot) then return end
    b.items = b.items or {}
    local held = WoW.cursor
    if not held then
        if b.items[slot] then WoW.cursor = { bag = bag, slot = slot, item = b.items[slot] } end
        return
    end
    pending[#pending + 1] = { held = held, bag = bag, slot = slot }
    WoW.cursor = nil
end
ClearCursor = function() WoW.cursor = nil end
GetCursorInfo = function()
    if WoW.cursor then return "item", WoW.cursor.item end
    return nil
end
DeleteCursorItem = function()
    local held = WoW.cursor
    if not held then return end
    pending[#pending + 1] = { held = held, delete = true }
    WoW.deleted[#WoW.deleted + 1] = held
    WoW.cursor = nil
end
function WoW.Settle()
    local asked = pending
    pending = {}
    local touched = {}
    for _, ask in ipairs(asked) do
        local from = bagOf(ask.held.bag)
        touched[ask.held.bag] = true
        if ask.delete then
            from.items[ask.held.slot] = nil
        else
            local to = bagOf(ask.bag)
            touched[ask.bag] = true
            from.items[ask.held.slot], to.items[ask.slot] = to.items[ask.slot], from.items[ask.held.slot]
        end
    end
    for bag in pairs(touched) do WoW.FireEvent("BAG_UPDATE", bag) end
    if next(touched) then WoW.FireEvent("BAG_UPDATE_DELAYED") end
    WoW.RunTimers()
end

-- ---------------------------------------------------------------- the list of controls

local function Clean(text)
    text = tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("\n", " / ")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- greyed: the nearest frame up the tree that was disabled (a text has no state of its own)
local function Enabled(f)
    while f do
        if f.__enabled == false then return false end
        f = f.__parent
    end
    return true
end

function WoW.Controls(root, rank)
    local out = {}
    local function walk(f, depth, place)
        place = rank and rank(f) or place
        local text = f.__text
        if text ~= nil and Clean(text) ~= "" then
            -- a button's label is the button, not the text inside it
            local owner = f.__type == "FontString" and f.__parent and f.__parent.__parts
                and f.__parent.__parts.FontString == f and f.__parent or f
            out[#out + 1] = { kind = owner.__type, text = Clean(text), shown = f:IsVisible(),
                              enabled = Enabled(f), depth = depth, order = f.__order, place = place }
        elseif f.__type == "Button" and f.__scripts.OnClick
            and not (f.__parts and f.__parts.FontString and f.__parts.FontString.__text) then
            -- a button with a click and no text (a close X, an icon): named by its template
            -- or its art, which is all it has
            local normal = f.__parts and f.__parts.Normal
            out[#out + 1] = { kind = "Button", shown = f:IsVisible(), enabled = Enabled(f), depth = depth,
                              order = f.__order, place = place, template = f.__template,
                              art = normal and normal.__texture }
        end
        for _, child in ipairs(f.__children) do walk(child, depth + 1, place) end
    end
    walk(root, 0, 0)
    table.sort(out, function(a, b)
        if a.place ~= b.place then return a.place < b.place end
        return a.order < b.order
    end)
    return out
end

return WoW
