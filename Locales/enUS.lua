-- SoulStone Sort Forever (SSF). GPLv3, see LICENSE.
-- English strings. Every user-facing string lives here; modules read L["..."].

local L = LibStub("AceLocale-3.0"):NewLocale("SoulStoneSortForever", "enUS", true)
if not L then return end

L["SoulStone Sort Forever"] = true
L["SSF"] = true
L["Deleted a Soul Shard (%d/%d)."] = true

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
L["Announce deletions in chat"] = true
L["One chat line per deleted shard, for addons that watch chat."] = true
L["Minimap button"] = true
L["Open options"] = true
L["Open the options window."] = true
L["The options window arrives in Stage 2."] = true
