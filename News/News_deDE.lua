-- Soul Shards Forever (SSF). MIT, see LICENSE.
-- The current announcement's lines, German: the keys News\News.lua names. Added to the
-- deDE table through Locales\Register.lua.

local _, NS = ...
local L = {}

L["Test announcement"] = "Testankündigung"
L["This is a sample announcement for testing. It is not part of any release."] = "Dies ist eine Beispielankündigung zum Testen. Sie gehört zu keiner Veröffentlichung."
L["It shows on the left of the SSF window every time you log in, until you tick the box below."] = "Sie erscheint bei jeder Anmeldung links neben dem SSF-Fenster, bis du das Kästchen unten ankreuzt."

NS.AddLocaleStrings("deDE", L)
