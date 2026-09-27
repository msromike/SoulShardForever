-- Soul Shard Forever (SSF). GPLv3, see LICENSE.
-- English strings. Every user-facing string lives here; modules read L["..."].

local L = LibStub("AceLocale-3.0"):NewLocale("SoulShardForever", "enUS", true)
if not L then return end

L["Soul Shard Forever"] = true
L["SSF"] = true
L["Soul Shard Forever (SSF) v%s by msromike. Type /ssf for options."] = true
L["Deleted a Soul Shard."] = true
L["ON"] = true
L["OFF"] = true
L["Use: /ssf %s on|off"] = true
L["Use: /ssf %s %d-%d"] = true
L["Soul Shards: %s (cap %s)"] = true
L["(in bags: %s)"] = true
L["%s (cap %d)"] = true
L["Match soul bag size (no soul bag equipped)"] = true

-- Options
L["Fork of SoulSort by Anilusion. GPLv3."] = true
L["Delete Shard"] = true
L["Delete one Soul Shard if you are over the cap. In a macro, put /ssf delete on the line before the ability."] = true
L["Shards to keep"] = true
L["The cap. Shards over this number are deleted one per press."] = true
L["Match soul bag size"] = true
L["While a soul bag is equipped, the cap is its slot count. Without one, the slider rules."] = true
L["Show shard count on bag bar"] = true
L["One number on the far-left bag button, red when over the cap."] = true
L["Counter font"] = true
L["Counter size"] = true
L["Counter color"] = true
L["Counter color when over the cap"] = true
L["Announce deletions in chat"] = true
L["One chat line per deleted shard, for addons that watch chat."] = true
L["Minimap button"] = true
L["Open options"] = true
L["Open the options window."] = true

-- Broker
L["Soul Shards"] = true
L["Cap"] = true
L["Over by %d. The next press trims one."] = true
