-- Soul Shard Forever (SSF). MIT, see LICENSE.
-- English strings. Every user-facing string lives here; modules read L["..."].

local L = LibStub("AceLocale-3.0"):NewLocale("SoulShardForever", "enUS", true)
if not L then return end

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
L["One number on the far-left bag button, red when over the cap."] = true
L["Shards in bag count"] = true
L["Low shard glow"] = true
L["Other settings"] = true
L["Colorize bag count"] = true
L["Glow bag button when low"] = true
L["Low shard warn"] = true
L["Bag counter font"] = true
L["Announce deletions in chat"] = true
L["One chat line per deleted shard, for addons that watch chat."] = true
L["Minimap button"] = true
L["Open options"] = true
L["Open the options window."] = true
L["Same as options."] = true
L["Full"] = true

-- Broker
L["Soul Shards"] = true
L["Cap"] = true
L["Over by"] = true
