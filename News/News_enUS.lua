-- Soul Shards Forever (SSF). MIT, see LICENSE.
-- The current announcement's lines, English: the keys News\News.lua names. Added to the
-- enUS table through Locales\Register.lua. Touches nothing else.

local _, NS = ...
local L = {}

L["Thanks for Trying the SSF Beta"] = true
L["SSF now deletes shards in and out of combat. Your keybind still works, and so do any old or new macros you might use."] = true
L["How to use it:"] = true
L["put /ssf delete on the line before the spells you cast most. Two little macros are all you need:"] = true
L["#showtooltip\n/ssf delete\n/cast %s"] = true
L["Tip:"] = true
L["/stopattack and /stopcasting make instant casts like %s go off on the first press, even while you're wanding:"] = true
L["#showtooltip\n/ssf delete\n/stopattack\n/stopcasting\n/cast %s"] = true
L["1.16.0-beta.2 notes:"] = true
L["fixed race that could cause deletion below cap during rapid keypresses"] = true
L["***"] = true
L["Thank you for giving our beta a try. Close to release, would like to see a few CurseForge comments first."] = true

NS.AddLocaleStrings("enUS", L)
