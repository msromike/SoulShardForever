-- Soul Shard Forever (SSF). MIT, see LICENSE.
-- English strings, the default. Every user-facing string lives here; modules read L["..."].
-- Registered at the bottom through Locales\Register.lua.

local _, NS = ...
local L = {}

L["Soul Shard Forever"] = true
L["SSF"] = true
L["Soul Shard Forever (SSF) v%s by %s. Type /ssf for options."] = true
L["Deleted a Soul Shard."] = true
L["ON"] = true
L["OFF"] = true
L["Use: /ssf %s on|off"] = true
L["Use: /ssf %s %d-%d"] = true
L["Soul Shards: %s (cap %s)"] = true
L["(in bags: %s)"] = true
L["%s (cap %d)"] = true
L["Match soul bag size (no soul bag)"] = true

-- Options
L["Started as a fork of SoulSort by Anilusion."] = true
L["Soul shard cap"] = true
L["Delete Shard"] = true
L["Shards to keep"] = true
L["Match soul bag size"] = true
L["Show shard count on bag bar"] = true
L["Show on soul bag when equipped"] = true
L["Pause SSF"] = true
L["Pause all SSF actions"] = true
L["All SSF actions paused"] = true
L["SSF actions"] = true
L["Type /ssf help for commands."] = true
L['Unknown command "%s".'] = true
L["Play pause sound"] = true
L["Log pause to chat"] = true
L["Full volume"] = "Full"
L["Loud"] = true
L["Medium"] = true
L["Quiet"] = true
L["Soul shard counter"] = true
L["Soul shard warning"] = true
L["Other settings"] = true
L["Colorize bag count"] = true
L["Glow bag button when low"] = true
L["Low shard warn"] = true
L["Bag counter font"] = true
L["Announce deletions in chat"] = true
L["How shards move"] = true
L["SSF Mode"] = true
L["SoulSort Normal"] = true
L["SoulSort Reverse"] = true
L["Show minimap icon"] = true
L["Language"] = true
L["Open options"] = true
L["Open the options window."] = true
L["Same as options."] = true
L["Close"] = true
L["Full"] = true

-- Broker
L["Soul Shards"] = true
L["Cap"] = true
L["Over by"] = true

-- Tooltips: the help button, each option's help line while help mode is on, the bottom
-- buttons' lines and the first-load welcome. Plain sentences: the tooltip wraps them
-- itself. Mike's final text, 2026-10-19.
L["Help OFF: Click to show tooltip help when you hover over an option."] = true
L["Help ON: Click to hide tooltip help."] = true
L["Pause stops SSF from moving or deleting shards until you unpause."] = true
L["Each press while paused plays a sound."] = true
L["Volume"] = true
L["Sets how loud the pause sound is."] = true
L["Each press while paused prints a chat line."] = true
L["Your shard cap. Shards over this number are deleted one per press."] = true
L["Sets cap automatically to the size of all soul bags (one or multiple)."] = true
L["If shard count is lower than this, you will be notified with a red color change (and glow if enabled)."] = true
L["The bag button glows while you are below \"%s\"."] = true
L["Shows your shard count on a bag button (soul bag by default, left bag slot otherwise)."] = true
L["Red when below \"%s,\" green in range, and yellow over the cap."] = true
L["Moves the counter to your soul bag, whatever slot it's in."] = true
L["The font used on the shard counter."] = true
L["Enables SSF minimap icon."] = true
L["Writes a line to chat every time a shard is deleted."] = true
L["How a macro or keybind moves shards."] = true
L["Shards move to soul bag."] = true
L["SSF does not sort (does NOT change item positions in bags)."] = true
L["Shards sort top down (CHANGES item positions in your bags)."] = true
L["Shards sort bottom up (CHANGES item positions in your bags)."] = true
L["Auto uses game client language."] = true
L["Deletes one Soul Shard if you are over the cap. In a macro, put /ssf delete on the line before the ability."] = true
L["Opens WoW's key bindings menu to bind %s and %s."] = true
L["Welcome to SSF"] = true
L["Click for in-game tooltip help."] = true
L["You'll only see this once."] = true

NS.RegisterLocale("enUS", "English", L, true)
