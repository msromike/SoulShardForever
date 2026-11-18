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
--            blank = true }. spell = a key of SSF.SPELLS (Core) puts that spell's
--            name, as the game gives it in the client's language, into the text's one
--            %s: a macro's /cast line, right in every language, with no spell name in
--            any translation. macro = true: the text is a macro to copy, drawn in its own
--            box in the code color. A macro with a spell and no text is the recommended macro
--            for that spell, whose text is Macros' (BodyFor): it is never typed here. In any other text a command the player types (/ssf delete,
--            /stopattack) is drawn in that color by NewsShow; no line here or in a
--            translation carries a color.
-- Owns no state beyond that table, no events, no frames. Touches nothing else.

local _, NS = ...
local L = setmetatable({}, { __index = function(_, key) return key end })

-- The fifth announcement, with the full release of delete in combat: what it is and how
-- to use it, for every player. It replaced the two the beta carried (11600 and 11601,
-- thanks for trying the beta, with the second beta's note), which never shipped in a
-- full release. Before those: "*New* SSF Beta Available" (11502), which 1.15.2 shipped
-- to everyone, and the first, "Coming soon to SSF" (11400), shipped in 1.14.0 and
-- switched off in 1.15.1.
NS.news = {
    id = 11602,
    on = true,
    title = L["Delete in Combat is Live"],
    text = {
        { text = L["SSF now deletes shards in and out of combat. Your keybind still works, and so do any old or new macros you might use."], blank = true },
        { lead = L["How to use it:"], text = L["put /ssf delete on the line before the spells you cast most. Two or three macros are all you need:"], blank = true },
        { spell = "LIFE_TAP", macro = true, blank = true },
        { spell = "DRAIN_SOUL", macro = true, blank = true },
        { lead = L["Tip:"], text = L["/stopattack and /stopcasting make instant casts like %s go off on the first press, even while you're wanding or in melee:"], spell = "BANE_OF_AGONY", blank = true },
        { text = L["#showtooltip\n/ssf delete\n/stopattack\n/stopcasting\n/cast %s"], spell = "BANE_OF_AGONY", macro = true, blank = true },
        { lead = L["Note:"], text = L["I put /ssf delete into every offensive macro I use and it is working great."] },
    },
}
