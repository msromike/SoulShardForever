-- Soul Shards Forever (SSF). MIT, see LICENSE.
-- The current announcement's lines, English: the keys News\News.lua names. Added to the
-- enUS table through Locales\Register.lua. Touches nothing else.

local _, NS = ...
local L = {}

L["Delete in Combat is Live"] = true
L["SSF now deletes shards in and out of combat. Your keybind still works, and so do any old or new macros you might use."] = true
L["New macros:"] = true
L["we reworked the recommended macros to go with it. There's a new %s macro, and an option to have the macro stop your wand."] = true
L["How to get them:"] = true
L["click %s in the panel on the right."] = true
L["Note:"] = true
L["I put /ssf delete into every offensive macro I use and it is working great."] = true

NS.AddLocaleStrings("enUS", L)
