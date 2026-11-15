-- Soul Shards Forever (SSF). MIT, see LICENSE.
-- The current announcement's lines, Spanish: the keys News\News.lua names. Added to the
-- esMX table through Locales\Register.lua.

local _, NS = ...
local L = {}

L["Test announcement"] = "Anuncio de prueba"
L["This is a sample announcement for testing. It is not part of any release."] = "Este es un anuncio de ejemplo para pruebas. No forma parte de ninguna versión."
L["It shows on the left of the SSF window every time you log in, until you tick the box below."] = "Aparece a la izquierda de la ventana de SSF cada vez que inicias sesión, hasta que marques la casilla de abajo."

NS.AddLocaleStrings("esMX", L)
