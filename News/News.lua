-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- News: the current announcement, and nothing else. One at a time: publishing a new one
-- means rewriting this file and the six News\News_<code>.lua beside it and giving it a higher
-- id. An announcement is never removed, only replaced or switched off (on = false: nobody
-- is shown it, ticked or not, and its lines stay in the files). NS.news = nil means no
-- announcement was ever shipped. NewsShow decides when it shows.
--   The lines are written as L["..."] so the check script reads them as keys every
-- News\News_<code>.lua must carry, but L here hands the key back unchanged: NewsShow looks the
-- key up when it shows, so the Language setting applies. A lookup made here, at load,
-- would freeze the announcement in the language the client loaded in.
--
-- Public:  NS.news = { id, on, title, text } or nil. id: a number in the welcome's scheme
--            (two digits per version part, 1.14.0 = 11400), higher than every id before
--            it; a character that ticked "Don't show this again" saved the id it saw. on:
--            the switch. title: the panel's title. text: the paragraphs, in order, each
--            a line (drawn white) or a table { lead = line, text = line, blank = true }:
--            the lead is drawn in gold, the text in white after it on the same paragraph,
--            and either may be left out (a lead alone is a paragraph all in gold, a text
--            alone a white one); blank = true leaves one blank line under the paragraph.
--            So a white paragraph that needs a blank line under it is { text = ...,
--            blank = true }.
-- Owns no state beyond that table, no events, no frames. Touches nothing else.

local _, NS = ...
local L = setmetatable({}, { __index = function(_, key) return key end })

-- The first announcement: a short roadmap, its wording deliberate. Shipped switched on in
-- 1.14.0 and 1.15.0; switched off in 1.15.1.
NS.news = {
    id = 11400,
    on = false,
    title = L["Coming soon to SSF"],
    text = {
        { lead = L["Two things you've asked for are on the way."], blank = true },
        { lead = L["Delete in combat:"], text = L["SSF will be able to delete a Soul Shard over your cap while you are in combat."] },
        { lead = L["Delete as you play:"], text = L["An optional mode that deletes Soul Shards over your cap automatically during normal gameplay without using a macro or keybind."], blank = true },
        L["Each one comes out first as a beta on CurseForge. We'll tell you here when they are ready."],
    },
}
