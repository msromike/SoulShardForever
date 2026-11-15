-- Soul Shards Forever (SSF). MIT, see LICENSE.
-- The current announcement's lines, French: the keys News\News.lua names. Added to the
-- frFR table through Locales\Register.lua.

local _, NS = ...
local L = {}

L["Test announcement"] = "Annonce de test"
L["This is a sample announcement for testing. It is not part of any release."] = "Ceci est un exemple d'annonce pour les tests. Elle ne fait partie d'aucune version."
L["It shows on the left of the SSF window every time you log in, until you tick the box below."] = "Elle s'affiche à gauche de la fenêtre SSF à chaque connexion, jusqu'à ce que vous cochiez la case ci-dessous."

NS.AddLocaleStrings("frFR", L)
