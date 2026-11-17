-- Soul Shards Forever (SSF). MIT, see LICENSE.
-- The current announcement's lines, Spanish: the keys News\News.lua names. Added to the
-- esMX table through Locales\Register.lua. Touches nothing else.

local _, NS = ...
local L = {}

L["Thanks for Trying the SSF Beta"] = "Gracias por probar la beta de SSF"
L["SSF now deletes shards in and out of combat. Your keybind still works, and so do any old or new macros you might use."] = "SSF ahora elimina fragmentos de alma dentro y fuera de combate. Tu atajo de teclado sigue funcionando, igual que tus macros viejas o nuevas."
L["How to use it:"] = "Cómo usarlo:"
L["put /ssf delete on the line before the spells you cast most. Two little macros are all you need:"] = "pon /ssf delete en la línea antes de los hechizos que más lanzas. Bastan dos pequeñas macros:"
L["#showtooltip\n/ssf delete\n/cast %s"] = "#showtooltip\n/ssf delete\n/cast %s"
L["Tip:"] = "Consejo:"
L["/stopattack and /stopcasting make instant casts like %s go off on the first press, even while you're wanding:"] = "/stopattack y /stopcasting hacen que los hechizos instantáneos como %s salgan a la primera pulsación, incluso mientras disparas con la varita:"
L["#showtooltip\n/ssf delete\n/stopattack\n/stopcasting\n/cast %s"] = "#showtooltip\n/ssf delete\n/stopattack\n/stopcasting\n/cast %s"
L["Thank you for giving our beta a try. Tell us how it went in the CurseForge comments."] = "Gracias por darle una oportunidad a nuestra beta. Cuéntanos cómo te fue en los comentarios de CurseForge."

NS.AddLocaleStrings("esMX", L)
