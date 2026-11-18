-- Soul Shards Forever (SSF). MIT, see LICENSE.
-- The current announcement's lines, Russian: the keys News\News.lua names. Added to the
-- ruRU table through Locales\Register.lua. Touches nothing else.

local _, NS = ...
local L = {}

L["Delete in Combat is Live"] = "Удаление в бою доступно"
L["SSF now deletes shards in and out of combat. Your keybind still works, and so do any old or new macros you might use."] = "Теперь SSF удаляет осколки душ и в бою, и вне боя. Ваша привязка клавиши по-прежнему работает, как и любые старые или новые макросы."
L["How to use it:"] = "Как пользоваться:"
L["put /ssf delete on the line before the spells you cast most. Two or three macros are all you need:"] = "поставьте /ssf delete в строку перед заклинаниями, которые вы применяете чаще всего. Хватит двух-трёх макросов:"
L["#showtooltip\n/ssf delete\n/cast %s"] = "#showtooltip\n/ssf delete\n/cast %s"
L["Tip:"] = "Совет:"
L["/stopattack and /stopcasting make instant casts like %s go off on the first press, even while you're wanding or in melee:"] = "/stopattack и /stopcasting заставляют мгновенные заклинания вроде «%s» срабатывать с первого нажатия, даже пока вы стреляете из жезла или в ближнем бою:"
L["#showtooltip\n/ssf delete\n/stopattack\n/stopcasting\n/cast %s"] = "#showtooltip\n/ssf delete\n/stopattack\n/stopcasting\n/cast %s"
L["Note:"] = "Примечание:"
L["I put /ssf delete into every offensive macro I use and it is working great."] = "Я добавил /ssf delete во все свои атакующие макросы, и всё отлично работает."

NS.AddLocaleStrings("ruRU", L)
