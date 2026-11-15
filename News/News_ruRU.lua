-- Soul Shards Forever (SSF). MIT, see LICENSE.
-- The current announcement's lines, Russian: the keys News\News.lua names. Added to the
-- ruRU table through Locales\Register.lua.

local _, NS = ...
local L = {}

L["Test announcement"] = "Тестовое объявление"
L["This is a sample announcement for testing. It is not part of any release."] = "Это пример объявления для проверки. Оно не входит ни в один выпуск."
L["It shows on the left of the SSF window every time you log in, until you tick the box below."] = "Оно показывается слева от окна SSF при каждом входе в игру, пока вы не отметите флажок ниже."

NS.AddLocaleStrings("ruRU", L)
