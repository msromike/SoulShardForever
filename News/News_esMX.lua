-- Soul Shards Forever (SSF). MIT, see LICENSE.
-- The current announcement's lines, Spanish: the keys News\News.lua names. Added to the
-- esMX table through Locales\Register.lua. Touches nothing else.

local _, NS = ...
local L = {}

L["Delete in Combat is Live"] = "Eliminar en combate ya está disponible"
L["SSF now deletes shards in and out of combat. Your keybind still works, and so do any old or new macros you might use."] = "SSF ahora elimina fragmentos de alma dentro y fuera de combate. Tu atajo de teclado sigue funcionando, igual que tus macros viejas o nuevas."
L["How to use it:"] = "Cómo usarlo:"
L["put /ssf delete on the line before the spells you cast most. Two or three macros are all you need:"] = "pon /ssf delete en la línea antes de los hechizos que más lanzas. Bastan dos o tres macros:"
L["Tip:"] = "Consejo:"
L["/stopattack and /stopcasting make instant casts like %s go off on the first press, even while you're wanding or in melee:"] = "/stopattack y /stopcasting hacen que los hechizos instantáneos como %s salgan a la primera pulsación, incluso mientras disparas con la varita o estás en cuerpo a cuerpo:"
L["Note:"] = "Nota:"
L["I put /ssf delete into every offensive macro I use and it is working great."] = "Puse /ssf delete en todas las macros ofensivas que uso y funciona muy bien."

NS.AddLocaleStrings("esMX", L)
