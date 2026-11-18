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
--            any translation. label = a line (a button's or a control's own words) put
--            into the text's one %s the same way, looked up when shown, so a sentence
--            that names a button never carries a copy of its label. macro = true: the text is a macro to copy, drawn in its own
--            box in the code color. A macro names its spell and has no text: its text is
--            Macros' (BodyFor), never typed here or in a translation. lines = a list of
--            that macro's own lines, put before the cast (/stopattack). In any other text a command the player types (/ssf delete,
--            /stopattack) is drawn in that color by NewsShow; no line here or in a
--            translation carries a color.
-- Owns no state beyond that table, no events, no frames. Touches nothing else.

local _, NS = ...
local L = setmetatable({}, { __index = function(_, key) return key end })

-- The sixth announcement, with the reworked macros: delete in combat first, for a player
-- who skipped the release that brought it, then the new macros and where to get them (the
-- welcome note beside it shows the macros, so this one carries none). It replaced the
-- fifth (11602, delete in combat with three macros to copy and the /stopcasting tip),
-- which had replaced the two the beta carried (11600 and 11601,
-- thanks for trying the beta, with the second beta's note), which never shipped in a
-- full release. Before those: "*New* SSF Beta Available" (11502), which 1.15.2 shipped
-- to everyone, and the first, "Coming soon to SSF" (11400), shipped in 1.14.0 and
-- switched off in 1.15.1.
NS.news = {
    id = 11700,
    on = true,
    title = L["Delete in Combat is Live"],
    text = {
        { text = L["SSF now deletes shards in and out of combat. Your keybind still works, and so do any old or new macros you might use."], blank = true },
        { lead = L["New macros:"], text = L["we reworked the recommended macros to go with it. There's a new %s macro, and an option to have the macro stop your wand."], spell = "DRAIN_SOUL", blank = true },
        -- Names the welcome note's button by the first of its three labels, deliberate:
        -- that is what the button reads for a character that has not made the macros
        -- yet, which is who this line is for. An announcement is words for one release
        -- and is replaced, not kept in step with the button; nothing acts on the label.
        { lead = L["How to get them:"], text = L["click %s in the Help panel."], label = L["Create recommended macros"], blank = true },
        { lead = L["Note:"], text = L["I put /ssf delete into every offensive macro I use and it is working great."] },
    },
}
