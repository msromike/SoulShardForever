-- Soul Shard Forever (SSF). MIT, see LICENSE.
-- Russian strings. Blizzard terms from the ruRU client: Осколок души (item 6265), Сумка душ
-- (the soul bag container type). Counts sit after a colon or in their own column, so no
-- string needs plural forms. Registered at the bottom through Locales\Register.lua.

local _, NS = ...
local L = {}

L["Soul Shard Forever"] = "Soul Shard Forever"
L["SSF"] = "SSF"
L["Soul Shard Forever (SSF) v%s by %s. Type /ssf for options."] = "Soul Shard Forever (SSF) v%s, автор %s. Введите /ssf, чтобы открыть настройки."
L["Deleted a Soul Shard."] = "Удален осколок души."
L["ON"] = "ВКЛ"
L["OFF"] = "ВЫКЛ"
L["Use: /ssf %s on|off"] = "Использование: /ssf %s on|off"
L["Use: /ssf %s %d-%d"] = "Использование: /ssf %s %d-%d"
L["Soul Shards: %s (cap %s)"] = "Осколки души: %s (лимит %s)"
L["(in bags: %s)"] = "(в сумках: %s)"
L["%s (cap %d)"] = "%s (лимит %d)"
L["Match soul bag size (no soul bag)"] = "По сумке душ (сумки нет)"

-- Options
L["Started as a fork of SoulSort by Anilusion."] = "Начинался как форк SoulSort от Anilusion."
L["Soul shard cap"] = "Лимит осколков души"
L["Delete Shard"] = "Удалить осколок"
L["Delete one Soul Shard if you are over the cap. In a macro, put /ssf delete on the line before the ability."] = "Удаляет один осколок души, если лимит превышен. В макросе поставьте /ssf delete строкой перед способностью."
L["Shards to keep"] = "Сколько осколков хранить"
L["The cap. Shards over this number are deleted one per press."] = "Лимит. Осколки сверх этого числа удаляются по одному за нажатие."
L["Match soul bag size"] = "По сумке душ"
L["While a soul bag is equipped, the cap is its slot count. Without one, the slider rules."] = "Пока надета сумка душ, лимит равен числу ее ячеек. Без нее действует ползунок."
L["Show shard count on bag bar"] = "Счетчик на панели сумок"
L["Shards in bag count"] = "Счетчик осколков"
L["Low shard glow"] = "Подсветка при нехватке"
L["Other settings"] = "Прочие настройки"
L["Colorize bag count"] = "Цветной счетчик"
L["Glow bag button when low"] = "Подсвечивать кнопку сумки"
L["Low shard warn"] = "Порог предупреждения"
L["Bag counter font"] = "Шрифт счетчика"
L["Announce deletions in chat"] = "Сообщать об удалении в чат"
L["One chat line per deleted shard, for addons that watch chat."] = "Одна строка в чате на каждый удаленный осколок, для аддонов, которые следят за чатом."
L["Minimap button"] = "Кнопка у миникарты"
L["Language"] = "Язык"
L["Auto"] = "Авто"
L["Open options"] = "Открыть настройки"
L["Open the options window."] = "Открывает окно настроек."
L["Same as options."] = "То же, что options."
L["Close"] = "Закрыть"
L["Full"] = "Заполнено"

-- Broker
L["Soul Shards"] = "Осколки души"
L["Cap"] = "Лимит"
L["Over by"] = "Сверх лимита"

NS.RegisterLocale("ruRU", "Русский", L)
