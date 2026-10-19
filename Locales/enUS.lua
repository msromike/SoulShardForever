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
L["Delete one Soul Shard if you are over the cap. In a macro, put /ssf delete on the line before the ability."] = true
L["Shards to keep"] = true
L["The cap. Shards over this number are deleted one per press."] = true
L["Match soul bag size"] = true
L["While a soul bag is equipped, the cap is its slot count. Without one, the slider rules."] = true
L["Show shard count on bag bar"] = true
L["Show on soul bag when equipped"] = true
L["Pause SSF"] = true
L["Pause all SSF actions"] = true
L["Stop every press from moving or deleting shards, until you turn it off."] = true
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
L["One chat line per deleted shard, for addons that watch chat."] = true
L["How shards move"] = true
L["SSF Mode"] = true
L["SoulSort Normal"] = true
L["SoulSort Reverse"] = true
L["Shards move to soul bag. SSF does not sort."] = true
L["Shards move to soul bag. Shards sort top down."] = true
L["Shards move to soul bag. Shards sort bottom up."] = true
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

NS.RegisterLocale("enUS", "English", L, true)
