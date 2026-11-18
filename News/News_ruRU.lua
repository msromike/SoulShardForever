-- Soul Shards Forever (SSF). MIT, see LICENSE.
-- The current announcement's lines, Russian: the keys News\News.lua names. Added to the
-- ruRU table through Locales\Register.lua. Touches nothing else.

local _, NS = ...
local L = {}

L["Delete in Combat is Live"] = "Удаление в бою доступно"
L["SSF now deletes shards in and out of combat. Your keybind still works, and so do any old or new macros you might use."] = "Теперь SSF удаляет осколки душ и в бою, и вне боя. Ваша привязка клавиши по-прежнему работает, как и любые старые или новые макросы."
L["New macros:"] = "Новые макросы:"
L["we reworked the recommended macros to go with it. There's a new %s macro, and an option to have the macro stop your wand."] = "мы переработали рекомендуемые макросы под это. Появился новый макрос для «%s» и настройка, чтобы макрос останавливал жезл."
L["How to get them:"] = "Как их получить:"
L["click %s in the Help panel."] = "нажмите «%s» на панели помощи."
L["Note:"] = "Примечание:"
L["I put /ssf delete into every offensive macro I use and it is working great."] = "Я добавил /ssf delete во все свои атакующие макросы, и всё отлично работает."

NS.AddLocaleStrings("ruRU", L)
