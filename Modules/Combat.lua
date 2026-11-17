-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Combat: the two questions SSF asks about a fight, each answered here and nowhere else.
--   Locked(): the game's combat lockdown is on. While it is, SSF moves no shard, makes no
--     macro and sets no secure button's command; a delete is not heard (Sounds) and a
--     paused press plays no sound and prints no line (Trimmer). A delete still deletes,
--     and its announce line still prints when that setting is on: each asker decides what
--     "locked" means for it. Sorter, Sounds, Trimmer, Macros and SSFSideNote ask.
--   InFight(): the lockdown, or the player already flagged in combat
--     (PLAYER_REGEN_DISABLED fires as the fight starts, before the lockdown itself is on).
--     The window and the notes beside it stay shut for the whole of it. Window, Welcome
--     and NewsShow ask.
-- The others ask and none decides: tools/check.py fails on InCombatLockdown or
-- UnitAffectingCombat typed in any other file. Debug is the one exception it names: it
-- writes the game's two raw answers into its record and decides nothing by them.
--
-- Public:  Locked() -> bool; InFight() -> bool.
-- Owns no state, no events, no frames. Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Combat = SSF:NewModule("Combat")

function Combat:Locked()
    return InCombatLockdown() and true or false
end

function Combat:InFight()
    return (InCombatLockdown() or UnitAffectingCombat("player")) and true or false
end
