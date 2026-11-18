-- Soul Shards Forever (SSF). MIT, see LICENSE.
-- The current announcement's lines, French: the keys News\News.lua names. Added to the
-- frFR table through Locales\Register.lua. Touches nothing else.

local _, NS = ...
local L = {}

L["Delete in Combat is Live"] = "La suppression en combat est disponible"
L["SSF now deletes shards in and out of combat. Your keybind still works, and so do any old or new macros you might use."] = "SSF supprime désormais les fragments d'âme en combat comme hors combat. Votre raccourci fonctionne toujours, tout comme vos anciennes ou nouvelles macros."
L["How to use it:"] = "Comment l'utiliser :"
L["put /ssf delete on the line before the spells you cast most. Two or three macros are all you need:"] = "placez /ssf delete sur la ligne avant les sorts que vous lancez le plus. Deux ou trois macros suffisent :"
L["#showtooltip\n/ssf delete\n/cast %s"] = "#showtooltip\n/ssf delete\n/cast %s"
L["Tip:"] = "Astuce :"
L["/stopattack and /stopcasting make instant casts like %s go off on the first press, even while you're wanding or in melee:"] = "/stopattack et /stopcasting font partir les sorts instantanés comme %s dès le premier appui, même pendant que vous tirez à la baguette ou êtes au corps à corps :"
L["#showtooltip\n/ssf delete\n/stopattack\n/stopcasting\n/cast %s"] = "#showtooltip\n/ssf delete\n/stopattack\n/stopcasting\n/cast %s"
L["Note:"] = "Remarque :"
L["I put /ssf delete into every offensive macro I use and it is working great."] = "J'ai mis /ssf delete dans toutes mes macros offensives et ça marche très bien."

NS.AddLocaleStrings("frFR", L)
