-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Register: the one place a locale file hands in its strings. Loads before every locale.
-- Feeds AceLocale as a stock addon would, so with Language = Auto nothing differs from
-- plain AceLocale: the client's locale over the default. Keeps every locale's table too,
-- so the Language setting (Core:ApplyLanguage) can switch the live table at runtime;
-- AceLocale alone would drop every locale but the client's at load.
--
-- Public:  NS.RegisterLocale(code, nativeName, strings, isDefault), called by each
--            Locales\*.lua, where strings is a plain table of L["English key"] =
--            "translation" (the default locale uses `true`, meaning the key is the string).
--          NS.locales[code] = { name = nativeName, strings = strings } for every locale.
--          NS.localeOrder, the codes in load order (Options' Language list).
-- Owns no state beyond those two tables, no events, no frames. Touches nothing else.

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
