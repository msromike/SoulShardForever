-- Soul Shards Forever (SSF). MIT, see LICENSE.
-- The current announcement's lines, Brazilian Portuguese: the keys News\News.lua names. Added to the
-- ptBR table through Locales\Register.lua. Touches nothing else.

local _, NS = ...
local L = {}

L["Thanks for Trying the SSF Beta"] = "Obrigado por testar a beta do SSF"
L["SSF now deletes shards in and out of combat. Your keybind still works, and so do any old or new macros you might use."] = "O SSF agora exclui Estilhaços de Alma dentro e fora de combate. Seu atalho de teclado continua funcionando, assim como qualquer macro antiga ou nova que você use."
L["How to use it:"] = "Como usar:"
L["put /ssf delete on the line before the spells you cast most. Two little macros are all you need:"] = "coloque /ssf delete na linha antes dos feitiços que você mais usa. Duas macros pequenas bastam:"
L["#showtooltip\n/ssf delete\n/cast %s"] = "#showtooltip\n/ssf delete\n/cast %s"
L["Tip:"] = "Dica:"
L["/stopattack and /stopcasting make instant casts like %s go off on the first press, even while you're wanding:"] = "/stopattack e /stopcasting fazem feitiços instantâneos como %s saírem no primeiro toque, mesmo enquanto você atira com a varinha:"
L["#showtooltip\n/ssf delete\n/stopattack\n/stopcasting\n/cast %s"] = "#showtooltip\n/ssf delete\n/stopattack\n/stopcasting\n/cast %s"
L["Thank you for giving our beta a try. Tell us how it went in the CurseForge comments."] = "Obrigado por dar uma chance à nossa beta. Conte como foi nos comentários do CurseForge."

NS.AddLocaleStrings("ptBR", L)
