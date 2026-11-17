-- Soul Shards Forever (SSF). MIT, see LICENSE.
-- The current announcement's lines, Russian: the keys News\News.lua names. Added to the
-- ruRU table through Locales\Register.lua. Touches nothing else.

local _, NS = ...
local L = {}

L["Thanks for Trying the SSF Beta"] = "Спасибо, что попробовали бету SSF"
L["SSF now deletes shards in and out of combat. Your keybind still works, and so do any old or new macros you might use."] = "Теперь SSF удаляет осколки душ и в бою, и вне боя. Ваша привязка клавиши по-прежнему работает, как и любые старые или новые макросы."
L["How to use it:"] = "Как пользоваться:"
L["put /ssf delete on the line before the spells you cast most. Two little macros are all you need:"] = "поставьте /ssf delete в строку перед заклинаниями, которые вы применяете чаще всего. Хватит двух маленьких макросов:"
L["#showtooltip\n/ssf delete\n/cast %s"] = "#showtooltip\n/ssf delete\n/cast %s"
L["Tip:"] = "Совет:"
L["/stopattack and /stopcasting make instant casts like %s go off on the first press, even while you're wanding:"] = "/stopattack и /stopcasting заставляют мгновенные заклинания вроде «%s» срабатывать с первого нажатия, даже пока вы стреляете из жезла:"
L["#showtooltip\n/ssf delete\n/stopattack\n/stopcasting\n/cast %s"] = "#showtooltip\n/ssf delete\n/stopattack\n/stopcasting\n/cast %s"
L["Thank you for giving our beta a try. Tell us how it went in the CurseForge comments."] = "Спасибо, что попробовали нашу бету. Расскажите, как всё прошло, в комментариях на CurseForge."

NS.AddLocaleStrings("ruRU", L)
