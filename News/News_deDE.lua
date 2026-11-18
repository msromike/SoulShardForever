-- Soul Shards Forever (SSF). MIT, see LICENSE.
-- The current announcement's lines, German: the keys News\News.lua names. Added to the
-- deDE table through Locales\Register.lua. Touches nothing else.

local _, NS = ...
local L = {}

L["Delete in Combat is Live"] = "Löschen im Kampf ist da"
L["SSF now deletes shards in and out of combat. Your keybind still works, and so do any old or new macros you might use."] = "SSF löscht Seelensplitter jetzt im Kampf und außerhalb. Deine Tastenbelegung funktioniert weiterhin, genau wie alle alten oder neuen Makros, die du benutzt."
L["How to use it:"] = "So nutzt du es:"
L["put /ssf delete on the line before the spells you cast most. Two or three macros are all you need:"] = "setze /ssf delete in die Zeile vor den Zaubern, die du am häufigsten wirkst. Zwei oder drei Makros reichen völlig:"
L["Tip:"] = "Tipp:"
L["/stopattack and /stopcasting make instant casts like %s go off on the first press, even while you're wanding or in melee:"] = "/stopattack und /stopcasting sorgen dafür, dass Spontanzauber wie %s schon beim ersten Druck wirken, auch während du mit dem Zauberstab schießt oder im Nahkampf bist:"
L["#showtooltip\n/ssf delete\n/stopattack\n/stopcasting\n/cast %s"] = "#showtooltip\n/ssf delete\n/stopattack\n/stopcasting\n/cast %s"
L["Note:"] = "Hinweis:"
L["I put /ssf delete into every offensive macro I use and it is working great."] = "Ich habe /ssf delete in jedes meiner Angriffsmakros gesetzt, und es funktioniert prima."

NS.AddLocaleStrings("deDE", L)
