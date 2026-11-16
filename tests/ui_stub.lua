-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- ui_stub: the part of the game's UI the real options window needs, on top of wow_stub, so
-- AceGUI, AceConfigDialog and SSF's widgets can build the window in plain Lua. Loaded by
-- tests/window.lua only, right after wow_stub and before any library. Frames here have
-- parents and children, are shown or hidden, enabled or greyed, and carry a text: enough
-- to say WHAT is in the window. Nothing has a size or a place that means anything, so
-- nothing here can say how the window looks.
--
-- Strict on purpose: a frame method this file does not know raises an error that names
-- it. A method is known one of three ways: it is written out below (it keeps state the
-- list of controls reads), it is on a short list of answers (GET), or its name starts
-- with a word on SETTERS (it changes how a frame is drawn, which nothing here tracks).
--
-- Public:  WoW.errors -- every error the game's error handler was handed (the red errors a
--            player would see), each with where it came from
--          WoW.RunTimers() -- runs every C_Timer.After callback waiting, and any those
--            queue, until none is left
--          WoW.Controls(root, rank) -> a list of { kind, text, shown, enabled, depth, place }
--            for root and everything under it that carries a text, and for every button
--            with a click and no text ({ template, art } in place of text). rank(frame) -> a number
--            or nil, optional: a frame takes the rank of the nearest frame up the tree
--            that has one, and the list is in rank order, then the order frames were
--            made (the caller knows the layout order; this file does not)
--          Every frame: __parent, __children, __shown, __enabled, __text (the fields the
--            list reads)
-- Touches nothing else.

local WoW = _G.WoW
local meta = getmetatable(UIParent)

-- Timers: queued, run on demand (wow_stub's After drops them)
local timers = {}
C_Timer = {
    After = function(_, fn) timers[#timers + 1] = fn end,
    NewTimer = function(_, fn) timers[#timers + 1] = fn return { Cancel = function() end } end,
    NewTicker = function() return { Cancel = function() end } end,
}
function WoW.RunTimers()
    local rounds = 0
    while #timers > 0 do
        rounds = rounds + 1
        assert(rounds < 100, "timers keep queueing timers")
        local run = timers
        timers = {}
        for _, fn in ipairs(run) do fn() end
    end
end

-- Errors: Ace runs OnEnable, events, timers and callbacks through the game's error handler,
-- which shows the red error and carries on. Here each one is kept, so the caller can fail
-- on them: an error the game would have shown is never swallowed.
WoW.errors = {}
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
function M:SetAttribute(key, value) self.__attributes = self.__attributes or {} self.__attributes[key] = value end
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
function M:CreateAnimation() return CreateFrame("Animation", nil, self) end
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
    GetLeft = 0, GetRight = 0, GetTop = 0, GetBottom = 0, GetStringHeight = 12, GetLineHeight = 12,
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

meta.__index = function(_, k)
    if type(k) ~= "string" or not k:find("^%u") then return nil end -- a field (frame.obj), not a method
    if M[k] then return M[k] end
    if MANY[k] then return MANY[k] end
    if GET[k] ~= nil then local v = GET[k] return function() return v end end
    if IsSetter(k) then return Nothing end
    error("ui_stub: no frame method " .. k .. " (add it to tests/ui_stub.lua on purpose)", 2)
end

-- Blizzard templates that come with named children the libraries reach by name
local TEMPLATE_CHILDREN = {
    UIDropDownMenuTemplate = { Left = "Texture", Middle = "Texture", Right = "Texture", Button = "Button",
                               Text = "FontString", Icon = "Texture" },
    UIPanelScrollBarTemplate = { ScrollUpButton = "Button", ScrollDownButton = "Button", ThumbTexture = "Texture" },
    OptionsSliderTemplate = { Text = "FontString", Low = "FontString", High = "FontString" },
}

local frames = WoW.frames
local made = 0
function CreateFrame(kind, name, parent, template)
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

-- the frames wow_stub made before this file loaded join the tree
for _, f in ipairs(frames) do
    f.__children = f.__children or {}
    f[0] = f[0] or newproxy()
end

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
-- macros: both of SSF's exist, so the window offers no "Create macros" button
GetMacroIndexByName = function() return 1 end
GetNumMacros = function() return 2, 2 end
MAX_ACCOUNT_MACROS, MAX_CHARACTER_MACROS = 120, 18
C_Spell = { GetSpellName = function(id) return "Spell " .. id end }
-- Blizzard's settings panel: AceConfigDialog registers SSF's page in it at enable
Settings = {
    GetCategory = function() end,
    RegisterCanvasLayoutCategory = function(_, name) return { ID = name } end,
    RegisterCanvasLayoutSubcategory = function(_, _, name) return { ID = name } end,
    RegisterAddOnCategory = function() end,
}

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
