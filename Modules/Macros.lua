-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Macros: the three recommended macros, /ssf delete before Life Tap, Drain Soul and Bane of Agony.
-- One option, off unless the player turns it on: the macros stop the wand, a /stopattack
-- line between /ssf delete and the cast, in all three. Nothing else is ever added to a
-- macro, deliberate: no line that cancels a cast or holds a channel.
-- Holds their text (the one source: the help text shows exactly what Create writes), says
-- what a click would do (make the missing ones, bring the others in line with the option,
-- or nothing), does it, and after making any hands back /reload for the
-- note's secure button to run (a new macro shows a stale
-- icon until a reload: a game bug) and then opens Blizzard's macro window on the first of
-- them (SSF_LT). The
-- player drags them to a bar; SSF never places a macro.
--
-- Found by name in both the account and the character section, so a renamed one counts as
-- missing. Never split: the missing ones all go to the character's macros if there is a
-- free slot for each, else all to the account's, else a red error and nothing is made.
-- A macro that exists is rewritten, in place, only when its text is exactly SSF's other
-- text for it (with the wand line while the option is off, without it while it is on): one
-- the player edited is never touched. A rewrite needs no reload (seen in game: the bar
-- icon stays, and Blizzard's macro window shows the new text at once).
-- In combat Create does nothing.
--
-- Public:  SpellName(key), Body(key, stopWand) (stopWand: with the wand line or without;
--          left out, as the option says), Exists(key), Names(),
--          Keys() -> the macros' keys, in the order they are shown and made,
--          StopWand() -> bool, the option; SetStopWand(on),
--          Pending() -> what a click would do: "create" (a macro is missing), "update"
--          (none missing, an unedited one not as the option says), or nil (nothing),
--          Reloads() -> bool, a click now would end in a reload (it would make a macro),
--          Create() -> "/reload" once it made macros, else nil.
--          key: "LT" (Life Tap), "DS" (Drain Soul) or "BoA" (Bane of Agony).
--          BodyFor(spellName, lines) -> the same macro text for any spell's name: the
--          one template (Body uses it, and so does an announcement's macro). lines,
--          optional: a list of a variant's own lines, put between /ssf delete and the
--          cast.
-- Listens: UPDATE_MACROS, bucketed (it fires in bursts of about five, even on a click in
--          Blizzard's macro window); LOADING_SCREEN_DISABLED once, after Create's reload.
-- Sends:   SSF_MACROS_CHANGED; SSF_MACRO_WINDOW_SHOWN once SSF has opened Blizzard's macro
--          window on them.
-- Game internals: Blizzard's macro window, past its documented API: ShowMacroFrame opens it
--          (Blizzard_MacroUI loads on demand), MacroFrame's ChangeTab and SelectMacro pick the tab
--          and the macro; UIErrorsFrame's AddExternalErrorMessage prints the red line. A Blizzard
--          rename breaks the "show them" step or the no-free-slot message.
-- Reads:   Combat:Locked (Create does nothing in combat); Spells:NameOf (a macro's spell,
--          in the client's language); profile.macroWindowAfterReload, macroStopWand;
--          Blizzard's macro API and MacroFrame.
-- Saves:   profile.macroWindowAfterReload, true only across Create's reload;
--          profile.macroStopWand, the option.
-- Acts on: the player's macros (CreateMacro: makes the missing ones, in the character's
--          slots when they fit, else the account's; EditMacro: rewrites an unedited one's
--          text to what the option says); Blizzard's macro window
--          (ShowMacroFrame opens it, then MacroFrame's tab and selection are set); the
--          game's red error text (UIErrorsFrame, one line when no macro slot is free).
-- Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Macros = SSF:NewModule("Macros", "AceEvent-3.0", "AceBucket-3.0")
local ADDON = ...
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)

-- names are never translated: the name is how SSF finds them
local MACROS = {
    LT  = { name = "SSF_LT",  spell = SSF.SPELLS.LIFE_TAP,      fallback = "Life Tap" },
    DS  = { name = "SSF_DS",  spell = SSF.SPELLS.DRAIN_SOUL,    fallback = "Drain Soul" },
    BoA = { name = "SSF_BoA", spell = SSF.SPELLS.BANE_OF_AGONY, fallback = "Bane of Agony" },
}
local ORDER = { "LT", "DS", "BoA" }
local ICON = 134400 -- INV_Misc_QuestionMark: with #showtooltip the button shows the spell's icon

-- The slot limits. Constants.MacroConsts on this client (the MAX_*_MACROS globals are nil);
-- the numbers are its values (read in game), in case the table is missing.
local function Limits()
    local k = Constants and Constants.MacroConsts
    return k and k.MAX_ACCOUNT_MACROS or 120, k and k.MAX_CHARACTER_MACROS or 30
end

function Macros:SpellName(key)
    local m = MACROS[key]
    return SSF:GetModule("Spells"):NameOf(m.spell) or m.fallback
end

-- the one template: /ssf delete on the line before the cast; a variant's own lines
-- (/stopattack, /stopcasting) go between the two
function Macros:BodyFor(spellName, lines)
    local between = ""
    for _, line in ipairs(lines or {}) do between = between .. line .. "\n" end
    return "#showtooltip\n/ssf delete\n" .. between .. "/cast " .. spellName
end

-- the option's own line, in every macro while it is on
local STOP_WAND = { "/stopattack" }

function Macros:StopWand()
    return SSF.db.profile.macroStopWand == true
end

function Macros:SetStopWand(on)
    SSF.db.profile.macroStopWand = on and true or false
end

function Macros:Body(key, stopWand)
    if stopWand == nil then stopWand = self:StopWand() end
    return self:BodyFor(self:SpellName(key), stopWand and STOP_WAND or nil)
end

-- a copy, so a caller cannot change the order
function Macros:Keys()
    return { unpack(ORDER) }
end

function Macros:Exists(key)
    return GetMacroIndexByName(MACROS[key].name) > 0
end

-- the keys of the macros that do not exist, in ORDER
local function Missing()
    local missing = {}
    for _, key in ipairs(ORDER) do
        if not Macros:Exists(key) then missing[#missing + 1] = key end
    end
    return missing
end

-- a macro's text as the game hands it back, without the line ends and spaces the game or
-- its macro window may leave around it
local function Tidy(text)
    return strtrim((text:gsub("\r", "")))
end

-- The keys of the macros that exist and hold exactly SSF's other text: made by SSF, never
-- edited, and not as the option says now. In ORDER.
local function Stale()
    local other = not Macros:StopWand()
    local stale = {}
    for _, key in ipairs(ORDER) do
        local index = GetMacroIndexByName(MACROS[key].name)
        local _, _, body = GetMacroInfo(index)
        if index > 0 and type(body) == "string" and Tidy(body) == Macros:Body(key, other) then
            stale[#stale + 1] = key
        end
    end
    return stale
end

function Macros:Pending()
    if #Missing() > 0 then return "create" end
    if #Stale() > 0 then return "update" end
end

-- A click now would end in a reload: only making a macro needs one (a new macro's icon is
-- stale until then), a rewrite never does. The one place that rule is decided; Create
-- hands back /reload by it.
function Macros:Reloads()
    return #Missing() > 0
end

-- Blizzard's macro window on the character tab (2) or the account tab (1), that macro
-- selected. Selection is by position within the tab: the character tab starts after the
-- account slots. Opening always lands on the account tab first.
local function ShowInMacroWindow(index)
    local maxAccount = Limits()
    local perChar = index > maxAccount
    ShowMacroFrame()
    MacroFrame:ChangeTab(perChar and 2 or 1)
    MacroFrame:SelectMacro(index - (perChar and maxAccount or 0), true)
    Macros:SendMessage("SSF_MACRO_WINDOW_SHOWN") -- MacroGlow lights the ones not yet on a bar
end

-- the macro window on the first of SSF's macros, if it exists
local function ShowFirst()
    local index = GetMacroIndexByName(MACROS[ORDER[1]].name)
    if index > 0 then ShowInMacroWindow(index) end
end

-- the macros' names, the way the macro window and the action bars show them
function Macros:Names()
    local names = {}
    for _, key in ipairs(ORDER) do names[#names + 1] = MACROS[key].name end
    return names
end

function Macros:Create()
    if SSF:GetModule("Combat"):Locked() then return end
    local missing, stale = Missing(), Stale()

    if #missing == 0 and #stale == 0 then -- nothing to do (the note's button is greyed out then): show them
        ShowFirst()
        return
    end

    local maxAccount, maxChar = Limits()
    local numAccount, numChar = GetNumMacros()
    local perChar
    if numChar + #missing <= maxChar then
        perChar = true
    elseif numAccount + #missing <= maxAccount then
        perChar = false
    else
        UIErrorsFrame:AddExternalErrorMessage(L["No free macro slots. Delete a macro and try again."])
        return
    end
    -- the unedited ones brought in line with the option, in place: the name and the icon
    -- stay, so the macro keeps its bar button
    for _, key in ipairs(stale) do
        EditMacro(GetMacroIndexByName(MACROS[key].name), nil, nil, self:Body(key))
    end
    if not self:Reloads() then return end -- only rewrites: no reload
    for _, key in ipairs(missing) do
        CreateMacro(MACROS[key].name, ICON, self:Body(key), perChar)
    end
    -- A new macro shows a stale icon (another macro's) until the next reload, even made
    -- exactly as Blizzard's macro window makes it, and nothing short of a reload clears it
    -- (tested in game). So: hand the note's button /reload to run as its click (the secure
    -- path; a direct ReloadUI() from addon code can be blocked, as MSBT's has been), then
    -- open the macro window on them.
    SSF.db.profile.macroWindowAfterReload = true
    return "/reload"
end

-- After Create's reload: the macro window on the first of SSF's macros (ShowFirst), once.
-- The tab comes from the macro's slot number, so nothing else is saved.
function Macros:LOADING_SCREEN_DISABLED()
    self:UnregisterEvent("LOADING_SCREEN_DISABLED")
    SSF.db.profile.macroWindowAfterReload = false
    ShowFirst()
end

function Macros:OnMacrosChanged()
    self:SendMessage("SSF_MACROS_CHANGED")
end

-- Setup lives in OnEnable, not OnInitialize: Core's warlock gate switches modules off
-- before OnEnable.
function Macros:OnEnable()
    self:RegisterBucketEvent("UPDATE_MACROS", 0.5, "OnMacrosChanged")
    if SSF.db.profile.macroWindowAfterReload then self:RegisterEvent("LOADING_SCREEN_DISABLED") end
end
