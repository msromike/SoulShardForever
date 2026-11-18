-- Soul Shards Forever (SSF). MIT, see LICENSE.
-- The current announcement's lines, English: the keys News\News.lua names. Added to the
-- enUS table through Locales\Register.lua. Touches nothing else.

local _, NS = ...
local L = {}

L["Delete in Combat is Live"] = true
L["SSF now deletes shards in and out of combat. Your keybind still works, and so do any old or new macros you might use."] = true
L["How to use it:"] = true
L["put /ssf delete on the line before the spells you cast most. Two or three macros are all you need:"] = true
L["Tip:"] = true
L["/stopattack and /stopcasting make instant casts like %s go off on the first press, even while you're wanding or in melee:"] = true
L["#showtooltip\n/ssf delete\n/stopattack\n/stopcasting\n/cast %s"] = true
L["Note:"] = true
L["I put /ssf delete into every offensive macro I use and it is working great."] = true

NS.AddLocaleStrings("enUS", L)
