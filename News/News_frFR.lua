-- Soul Shards Forever (SSF). MIT, see LICENSE.
-- The current announcement's lines, French: the keys News\News.lua names. Added to the
-- frFR table through Locales\Register.lua. Touches nothing else.

local _, NS = ...
local L = {}

L["Thanks for Trying the SSF Beta"] = "Merci d'essayer la bêta de SSF"
L["SSF now deletes shards in and out of combat. Your keybind still works, and so do any old or new macros you might use."] = "SSF supprime désormais les fragments d'âme en combat comme hors combat. Votre raccourci fonctionne toujours, tout comme vos anciennes ou nouvelles macros."
L["How to use it:"] = "Comment l'utiliser :"
L["put /ssf delete on the line before the spells you cast most. Two little macros are all you need:"] = "placez /ssf delete sur la ligne avant les sorts que vous lancez le plus. Deux petites macros suffisent :"
L["#showtooltip\n/ssf delete\n/cast %s"] = "#showtooltip\n/ssf delete\n/cast %s"
L["Tip:"] = "Astuce :"
L["/stopattack and /stopcasting make instant casts like %s go off on the first press, even while you're wanding:"] = "/stopattack et /stopcasting font partir les sorts instantanés comme %s dès le premier appui, même pendant que vous tirez à la baguette :"
L["#showtooltip\n/ssf delete\n/stopattack\n/stopcasting\n/cast %s"] = "#showtooltip\n/ssf delete\n/stopattack\n/stopcasting\n/cast %s"
L["1.16.0-beta.2 notes:"] = "Notes de la 1.16.0-beta.2 :"
L["fixed race that could cause deletion below cap during rapid keypresses"] = "correction d'une situation de concurrence qui pouvait supprimer en dessous de la limite lors d'appuis rapides"
L["***"] = "***"
L["Thank you for giving our beta a try. Close to release, would like to see a few CurseForge comments first."] = "Merci d'essayer notre bêta. La sortie approche ; nous aimerions d'abord voir quelques commentaires sur CurseForge."

NS.AddLocaleStrings("frFR", L)
