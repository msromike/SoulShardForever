-- Soul Shards Forever (SSF). MIT, see LICENSE.
-- The current announcement's lines, Brazilian Portuguese: the keys News\News.lua names. Added to the
-- ptBR table through Locales\Register.lua. Touches nothing else.

local _, NS = ...
local L = {}

L["Delete in Combat is Live"] = "Excluir em combate já está disponível"
L["SSF now deletes shards in and out of combat. Your keybind still works, and so do any old or new macros you might use."] = "O SSF agora exclui Estilhaços de Alma dentro e fora de combate. Seu atalho de teclado continua funcionando, assim como qualquer macro antiga ou nova que você use."
L["How to use it:"] = "Como usar:"
L["put /ssf delete on the line before the spells you cast most. Two or three macros are all you need:"] = "coloque /ssf delete na linha antes dos feitiços que você mais usa. Duas ou três macros bastam:"
L["Tip:"] = "Dica:"
L["/stopattack and /stopcasting make instant casts like %s go off on the first press, even while you're wanding or in melee:"] = "/stopattack e /stopcasting fazem feitiços instantâneos como %s saírem no primeiro toque, mesmo enquanto você atira com a varinha ou está em corpo a corpo:"
L["Note:"] = "Nota:"
L["I put /ssf delete into every offensive macro I use and it is working great."] = "Coloquei /ssf delete em todas as macros ofensivas que uso e está funcionando muito bem."

NS.AddLocaleStrings("ptBR", L)
