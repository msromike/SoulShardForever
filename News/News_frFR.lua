-- Soul Shards Forever (SSF). MIT, see LICENSE.
-- The current announcement's lines, French: the keys News\News.lua names. Added to the
-- frFR table through Locales\Register.lua. Touches nothing else.

local _, NS = ...
local L = {}

L["Delete in Combat is Live"] = "La suppression en combat est disponible"
L["SSF now deletes shards in and out of combat. Your keybind still works, and so do any old or new macros you might use."] = "SSF supprime désormais les fragments d'âme en combat comme hors combat. Votre raccourci fonctionne toujours, tout comme vos anciennes ou nouvelles macros."
L["New macros:"] = "Nouvelles macros :"
L["we reworked the recommended macros to go with it. There's a new %s macro, and an option to have the macro stop your wand."] = "nous avons retravaillé les macros recommandées en conséquence. Il y a une nouvelle macro %s, et une option pour que la macro arrête votre baguette."
L["How to get them:"] = "Comment les obtenir :"
L["click %s in the Help panel."] = "cliquez sur %s dans le panneau d'aide."
L["Note:"] = "Remarque :"
L["I put /ssf delete into every offensive macro I use and it is working great."] = "J'ai mis /ssf delete dans toutes mes macros offensives et ça marche très bien."

NS.AddLocaleStrings("frFR", L)
