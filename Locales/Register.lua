-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Register: the one place a locale file hands in its strings. Loads before every locale.
-- Feeds AceLocale as a stock addon would, so with Language = Auto nothing differs from
-- plain AceLocale: the client's locale over the default. Keeps every locale's table too,
-- so the Language setting (Core:ApplyLanguage) can switch the live table at runtime;
-- AceLocale alone would drop every locale but the client's at load. A second file may add
-- strings to a locale already registered (the announcement's lines, News\News_<code>.lua), so
-- they live apart from the main string tables and switch with the Language setting too.
--
-- Public:  NS.RegisterLocale(code, nativeName, strings, isDefault), called by each
--            Locales\*.lua, where strings is a plain table of L["English key"] =
--            "translation" (the default locale uses `true`, meaning the key is the string).
--          NS.AddLocaleStrings(code, strings), called by each News\News_<code>.lua after its
--            locale is registered: the same kind of table, merged into that locale's.
--          NS.locales[code] = { name = nativeName, strings = strings, isDefault = bool }
--            for every locale.
--          NS.localeOrder, the codes in load order (Options' Language list).
-- Owns no state beyond those two tables, no events, no frames. Touches nothing else.

local ADDON, NS = ...

NS.locales = {}
NS.localeOrder = {}

-- AceLocale keeps a locale only when it is the client's or the default; its write table is
-- good for one NewLocale call (another addon's call redirects it), so it is asked for
-- again on every feed.
local function Feed(code, strings)
    local L = LibStub("AceLocale-3.0"):NewLocale(ADDON, code, NS.locales[code].isDefault)
    if not L then return end -- not the client's locale; kept in NS.locales for the Language setting
    for key, value in pairs(strings) do L[key] = value end
end

function NS.RegisterLocale(code, nativeName, strings, isDefault)
    NS.locales[code] = { name = nativeName, strings = strings, isDefault = isDefault }
    NS.localeOrder[#NS.localeOrder + 1] = code
    Feed(code, strings)
end

function NS.AddLocaleStrings(code, strings)
    local into = NS.locales[code].strings
    for key, value in pairs(strings) do into[key] = value end
    Feed(code, strings)
end
