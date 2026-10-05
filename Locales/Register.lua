-- Soul Shard Forever (SSF). MIT, see LICENSE.
--
-- Register: the one place a locale file hands in its strings. Loads before every locale.
--
-- Takes:   NS.RegisterLocale(code, nativeName, strings, isDefault) from each Locales\*.lua,
--          where strings is a plain table of L["English key"] = "translation" (the default
--          locale uses `true`, meaning the key is the string).
-- Keeps:   NS.locales[code] = { name = nativeName, strings = strings } for every locale,
--          and NS.localeOrder, the codes in load order. The Language setting
--          (Core:ApplyLanguage) switches the live table from these at runtime; AceLocale
--          alone would drop every locale but the client's at load.
-- Feeds:   AceLocale as a stock addon would, so with Language = Auto nothing differs from
--          plain AceLocale: the client's locale over the default.
-- Owns no state beyond those two tables, no events, no frames.

local ADDON, NS = ...

NS.locales = {}
NS.localeOrder = {}

function NS.RegisterLocale(code, nativeName, strings, isDefault)
    NS.locales[code] = { name = nativeName, strings = strings }
    NS.localeOrder[#NS.localeOrder + 1] = code

    local L = LibStub("AceLocale-3.0"):NewLocale(ADDON, code, isDefault)
    if not L then return end -- not the client's locale; kept in NS.locales for the Language setting
    for key, value in pairs(strings) do L[key] = value end
end
