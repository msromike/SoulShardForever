-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- MacroGlow: when SSF opens Blizzard's macro window on its macros, each one not yet on an
-- action bar glows (LibCustomGlow's button glow, the proc look) until the player drops it
-- on a bar. Closing the macro window ends it.
--
-- Blizzard's grid reuses its button frames whenever it redraws (a tab switch, a scroll, a
-- macro change), so a glow can't stay on a frame: after Blizzard fills each button
-- (MacroSelector:RunSetup) it is re-checked by the macro name it now shows. A drop is seen
-- by the name in the changed action slot (GetActionText); the slot's id is no help, it is
-- the spell the macro resolves to.
--
-- Public:  Stop() (also the OnHide hook's handler).
-- Listens: SSF_MACRO_WINDOW_SHOWN; ACTIONBAR_SLOT_CHANGED while one still glows.
-- Hooks:   MacroSelector.RunSetup and MacroFrame's OnHide (AceHook), attached the first
--          time SSF opens the window (SSF_MACRO_WINDOW_SHOWN): Blizzard_MacroUI loads on
--          demand, so neither frame exists at OnEnable.
-- Reads:   Macros:Names(); Blizzard's MacroFrame.MacroSelector buttons (their Name text).
-- Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local MacroGlow = SSF:NewModule("MacroGlow", "AceEvent-3.0", "AceHook-3.0")
local LCG = LibStub("LibCustomGlow-1.0")

local MAX_ACTION_SLOT = 180 -- every action slot; bar addons use the same ones

local pending = {} -- macro name -> true while it still waits for a bar

local function UpdateButton(button)
    local name = button.Name and button.Name:GetText()
    if name and pending[name] then LCG.ButtonGlow_Start(button) else LCG.ButtonGlow_Stop(button) end
end

local function UpdateAll()
    for button in MacroFrame.MacroSelector:EnumerateButtons() do UpdateButton(button) end
end

local function OnABar(name)
    for slot = 1, MAX_ACTION_SLOT do
        if GetActionText(slot) == name then return true end
    end
    return false
end

-- a conditional macro on a bar fires this constantly, so only the changed slot is read
function MacroGlow:ACTIONBAR_SLOT_CHANGED(_, slot)
    local name = GetActionText(slot)
    if not (name and pending[name]) then return end
    pending[name] = nil
    UpdateAll()
    if not next(pending) then self:UnregisterEvent("ACTIONBAR_SLOT_CHANGED") end
end

function MacroGlow:Stop()
    wipe(pending)
    UpdateAll()
    self:UnregisterEvent("ACTIONBAR_SLOT_CHANGED")
end

function MacroGlow:OnWindowShown()
    wipe(pending)
    for _, name in ipairs(SSF:GetModule("Macros"):Names()) do
        if not OnABar(name) then pending[name] = true end
    end
    -- hooked once, the first time SSF opens the window (Blizzard_MacroUI loads on demand)
    if not self:IsHooked(MacroFrame.MacroSelector, "RunSetup") then
        self:SecureHook(MacroFrame.MacroSelector, "RunSetup", function(_, button) UpdateButton(button) end)
        self:SecureHookScript(MacroFrame, "OnHide", "Stop")
    end
    UpdateAll()
    if next(pending) then self:RegisterEvent("ACTIONBAR_SLOT_CHANGED") end
end

-- Setup lives in OnEnable, not OnInitialize: Core's warlock gate switches modules off
-- before OnEnable.
function MacroGlow:OnEnable()
    self:RegisterMessage("SSF_MACRO_WINDOW_SHOWN", "OnWindowShown")
end
