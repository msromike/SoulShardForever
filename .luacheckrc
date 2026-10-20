-- luacheck configuration for Soul Shards Forever (WoW Forever runs Lua 5.1).
-- Run from the addon root: luacheck .   (the check script does this before every commit)
-- Every name in read_globals was harvested from a run with no whitelist on 2026-10-20 and
-- checked to be a real WoW API or FrameXML global. Add a name only when the game has it.

std = "lua51"
max_line_length = false
self = false -- a method written with ':' may leave self unused
codes = true

exclude_files = { "Libs/**", "_ref/**", ".docs/**", "tests/**" }

globals = {
    -- Bindings.xml labels, set by Core (chunk 3.01 moves them to KeyBindings)
    "BINDING_NAME_SSF_DELETE", "BINDING_NAME_SSF_PAUSE",
}

read_globals = {
    -- libraries
    "LibStub",
    -- WoW Lua extensions
    "wipe", "tinsert", "strtrim", "bit", "hooksecurefunc",
    -- frames and UI globals
    "CreateFrame", "UIParent", "GameTooltip", "UISpecialFrames", "UIErrorsFrame",
    "GameFontNormal", "GameFontNormalLarge",
    "MainMenuBarBackpackButton", "CharacterBag3Slot", "CharacterReagentBag0Slot",
    "MacroFrame", "ShowMacroFrame", "Settings", "SettingsPanel",
    -- API namespaces and enums
    "C_Container", "C_Item", "C_AddOns", "C_Spell", "C_Sound", "Enum", "Constants",
    "ItemLocation", "NUM_BAG_SLOTS", "RAID_CLASS_COLORS",
    -- functions
    "InCombatLockdown", "UnitAffectingCombat", "UnitClassBase", "GetLocale", "ReloadUI",
    "ClearCursor", "GetCursorInfo", "DeleteCursorItem",
    "GetMacroIndexByName", "GetNumMacros", "CreateMacro", "GetActionText",
    "PlaySound", "PlaySoundFile",
    -- global strings
    "CLOSE", "KEY_BINDINGS", "SETTINGS_KEYBINDINGS_LABEL",
}

files["Widgets/SSFWindow.lua"] = {
    ignore = { "411" }, -- 'title' redefined at 700; the file is rebuilt in chunk 4.01
}
