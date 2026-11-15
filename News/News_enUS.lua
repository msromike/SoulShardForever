-- Soul Shards Forever (SSF). MIT, see LICENSE.
-- The current announcement's lines, English: the keys News\News.lua names. Added to the
-- enUS table through Locales\Register.lua.

local _, NS = ...
local L = {}

L["Test announcement"] = true
L["This is a sample announcement for testing. It is not part of any release."] = true
L["It shows on the left of the SSF window every time you log in, until you tick the box below."] = true

NS.AddLocaleStrings("enUS", L)
