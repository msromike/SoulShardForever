-- Soul Shards Forever (SSF). MIT, see LICENSE.
-- The current announcement's lines, German: the keys News\News.lua names. Added to the
-- deDE table through Locales\Register.lua. Touches nothing else.

local _, NS = ...
local L = {}

L["Delete in Combat is Live"] = "Löschen im Kampf ist da"
L["SSF now deletes shards in and out of combat. Your keybind still works, and so do any old or new macros you might use."] = "SSF löscht Seelensplitter jetzt im Kampf und außerhalb. Deine Tastenbelegung funktioniert weiterhin, genau wie alle alten oder neuen Makros, die du benutzt."
L["New macros:"] = "Neue Makros:"
L["we reworked the recommended macros to go with it. There's a new %s macro, and an option to have the macro stop your wand."] = "wir haben die empfohlenen Makros dafür überarbeitet. Es gibt ein neues Makro für %s und eine Option, mit der das Makro deinen Zauberstab stoppt."
L["How to get them:"] = "So bekommst du sie:"
L["click %s in the panel on the right."] = "klicke im Fenster rechts auf %s."
L["Note:"] = "Hinweis:"
L["I put /ssf delete into every offensive macro I use and it is working great."] = "Ich habe /ssf delete in jedes meiner Angriffsmakros gesetzt, und es funktioniert prima."

NS.AddLocaleStrings("deDE", L)
