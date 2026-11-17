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
--            a line (drawn white) or { lead = line, text = line }: the lead is drawn in
--            gold, the text in white after it on the same paragraph; a lead with no text
--            is a paragraph all in gold; blank = true leaves one blank line under the
--            paragraph.
-- Owns no state beyond that table, no events, no frames. Touches nothing else.

local _, NS = ...
local L = setmetatable({}, { __index = function(_, key) return key end })

-- The second announcement: the delete-in-combat beta is out, and how to get it. It replaces
-- the first one, "Coming soon to SSF" (11400), which shipped in 1.14.0 and was switched
-- off in 1.15.1.
NS.news = {
    id = 11502,
    on = true,
    title = L["*New* SSF Beta Available"],
    text = {
        { lead = L["SSF Delete in Combat beta is now available on CurseForge."], blank = true },
        { lead = L["What's different:"], text = L["your delete key and your SSF delete macros now work in combat."], blank = true },
        { lead = L["We've been playing on it with no problems."], text = L["The full release is coming soon."], blank = true },
        { lead = L["Want it early?"], text = L["In the CurseForge app, right-click on the addon, select Release Type and choose Beta."] },
    },
}
