-- Soul Shards Forever (SSF). MIT, see LICENSE.
-- The current announcement's lines, German: the keys News\News.lua names. Added to the
-- deDE table through Locales\Register.lua. Touches nothing else.

local _, NS = ...
local L = {}

L["Thanks for Trying the SSF Beta"] = "Danke, dass du die SSF-Beta ausprobierst"
L["SSF now deletes shards in and out of combat. Your keybind still works, and so do any old or new macros you might use."] = "SSF löscht Seelensplitter jetzt im Kampf und außerhalb. Deine Tastenbelegung funktioniert weiterhin, genau wie alle alten oder neuen Makros, die du benutzt."
L["How to use it:"] = "So nutzt du es:"
L["put /ssf delete on the line before the spells you cast most. Two little macros are all you need:"] = "setze /ssf delete in die Zeile vor den Zaubern, die du am häufigsten wirkst. Zwei kleine Makros reichen völlig:"
L["#showtooltip\n/ssf delete\n/cast %s"] = "#showtooltip\n/ssf delete\n/cast %s"
L["Tip:"] = "Tipp:"
L["/stopattack and /stopcasting make instant casts like %s go off on the first press, even while you're wanding:"] = "/stopattack und /stopcasting sorgen dafür, dass Spontanzauber wie %s schon beim ersten Druck wirken, auch während du mit dem Zauberstab schießt:"
L["#showtooltip\n/ssf delete\n/stopattack\n/stopcasting\n/cast %s"] = "#showtooltip\n/ssf delete\n/stopattack\n/stopcasting\n/cast %s"
L["1.16.0-beta.2 notes:"] = "Hinweise zu 1.16.0-beta.2:"
L["fixed race that could cause deletion below cap during rapid keypresses"] = "Race-Condition behoben, durch die bei schnellen Tastendrücken unter das Limit gelöscht werden konnte"
L["***"] = "***"
L["Thank you for giving our beta a try. Close to release, would like to see a few CurseForge comments first."] = "Danke, dass du unsere Beta ausprobierst. Die Veröffentlichung ist nah, vorher würden wir gern ein paar Kommentare auf CurseForge sehen."

NS.AddLocaleStrings("deDE", L)
