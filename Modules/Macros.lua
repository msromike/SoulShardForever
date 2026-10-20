-- Soul Shard Forever (SSF). MIT, see LICENSE.
--
-- Macros: the two recommended macros, /ssf delete before Life Tap and before Bane of Agony.
-- Holds their text (the one source: the help text shows exactly what Create writes), says
-- whether each exists, makes the missing ones on a click, reloads (a new macro shows a stale
-- icon until a reload: a game bug) and then opens Blizzard's macro window on them. The
-- player drags them to a bar; SSF never places a macro.
--
-- Found by name in both the account and the character section, so a renamed one counts as
-- missing. Never split: the missing ones all go to the character's macros if there is a
-- free slot for each, else all to the account's, else a red error and nothing is made.
-- In combat Create does nothing.
--
-- Public:  SpellName(key), Body(key), Exists(key), AnyMissing(), Names(), Create().
--          key: "LT" (Life Tap) or "BoA" (Bane of Agony).
-- Sends:   SSF_MACROS_CHANGED, from a bucketed UPDATE_MACROS (it fires in bursts of about
--          five, even on a click in Blizzard's macro window); SSF_MACRO_WINDOW_SHOWN once
--          SSF has opened Blizzard's macro window on them.
-- Saves:   profile.macroWindowAfterReload, true only across Create's reload.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Macros = SSF:NewModule("Macros", "AceEvent-3.0", "AceBucket-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("SoulShardForever")

-- names are never translated: the name is how SSF finds them
local MACROS = {
    LT  = { name = "SSF_LT",  spell = 1454, fallback = "Life Tap" },
    BoA = { name = "SSF_BoA", spell = 980,  fallback = "Bane of Agony" },
}
local ORDER = { "LT", "BoA" }
local ICON = 134400 -- INV_Misc_QuestionMark: with #showtooltip the button shows the spell's icon

-- The slot limits. Constants.MacroConsts on this client (the MAX_*_MACROS globals are nil);
-- the numbers are its values (spike 4, 2026-10-19), in case the table is missing.
local function Limits()
    local k = Constants and Constants.MacroConsts
    return k and k.MAX_ACCOUNT_MACROS or 120, k and k.MAX_CHARACTER_MACROS or 30
end

-- the spell's name in the client's language; this client has no GetSpellInfo
function Macros:SpellName(key)
    local m = MACROS[key]
    return C_Spell.GetSpellName(m.spell) or m.fallback
end

function Macros:Body(key)
    return "#showtooltip\n/ssf delete\n/cast " .. self:SpellName(key)
end

function Macros:Exists(key)
    return GetMacroIndexByName(MACROS[key].name) > 0
end

function Macros:AnyMissing()
    for _, key in ipairs(ORDER) do
        if not self:Exists(key) then return true end
    end
    return false
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

-- the macros' names, the way the macro window and the action bars show them
function Macros:Names()
    local names = {}
    for _, key in ipairs(ORDER) do names[#names + 1] = MACROS[key].name end
    return names
end

function Macros:Create()
    if InCombatLockdown() then return end
    local missing = {}
    for _, key in ipairs(ORDER) do
        if not self:Exists(key) then missing[#missing + 1] = key end
    end

    if #missing == 0 then -- nothing to make (the note's button is greyed out then): show them
        local index = GetMacroIndexByName(MACROS[ORDER[1]].name)
        if index > 0 then ShowInMacroWindow(index) end
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
    for _, key in ipairs(missing) do
        CreateMacro(MACROS[key].name, ICON, self:Body(key), perChar)
    end
    -- A new macro shows a stale icon (another macro's) until the next reload, even made
    -- exactly as Blizzard's macro window makes it, and nothing short of a reload clears it
    -- (tested in game, 2026-10-19). So: reload, then open the macro window on them.
    SSF.db.profile.macroWindowAfterReload = true
    ReloadUI()
end

-- After Create's reload: the macro window on the new macros, once. The tab comes from the
-- macro's slot number, so nothing else is saved.
function Macros:LOADING_SCREEN_DISABLED()
    self:UnregisterEvent("LOADING_SCREEN_DISABLED")
    SSF.db.profile.macroWindowAfterReload = false
    local index = GetMacroIndexByName(MACROS[ORDER[1]].name)
    if index > 0 then ShowInMacroWindow(index) end
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
