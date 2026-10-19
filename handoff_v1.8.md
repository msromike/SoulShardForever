# Handoff 1.8: teach the delete, make the macros, new gallery

Written 2026-10-19, after 1.7.0 shipped; was the 1.7.1 handoff until Mike rolled it up
into 1.8 the same day. Three parts, one release, one test round, one gallery shoot:
1. Delete Shard's help-mode tooltip teaches every way to delete, with two macros.
2. The first-load welcome carries the same text.
3. Macro buttons: SSF makes the Life Tap and Bane macros on a click.
Mike: "this is the bread and butter of the add-on." SSF's players are casual (dads
playing 90 minutes a night): setup has to be in front of them. Nothing moves to the next
step without his "tested works".

## The tooltip, final (Mike, 2026-10-19)

Shown only with help on (the "i"), hovering Delete Shard. Gold title, white text; the
paragraphs wrap on their own, the macro lines stay one per line. In this file the
paragraphs are wrapped for reading: a blank line is a real break, a wrapped line is not.

    Delete Shard
    Use your keybind, click this button, use a macro, or mix and match. Deletes one Soul
    Shard if you are over the cap.

    In a macro, put /ssf delete on the line before the ability:

    #showtooltip
    /ssf delete
    /cast Life Tap

    #showtooltip
    /ssf delete
    /cast Bane of Agony

    The Bane macro lets you delete on the move when you don't want to use Life Tap. Make
    sure you're not targeting an enemy with the Bane macro. Otherwise it won't delete
    because you'll be in combat before the delete fires.

Mike's mechanics, as he stated them (don't "correct" these): Life Tap never puts you in
combat, whatever you target. An offensive spell with no target never casts: no mana, no
combat, and the /ssf delete line still fires on every press, so it clears shards on the
move. With an enemy targeted, you're in combat before the delete fires.

## The same text in the first-load welcome (Mike, 2026-10-19)

The whole Delete Shard text also goes into the first-load welcome note, underneath
"You'll only see this once." One change: the top line says where the button is, since
the welcome isn't hovering it:

    Use your keybind, click Delete Shard, bottom left in the UI, or use a macro, or all of
    the above.

Everything after it is the tooltip's text unchanged (the "Deletes one Soul Shard…" line,
both macros, the Bane line, the warning). Seen once, it plants the idea even if they don't
read it.

Build note: the welcome's body is one line today and the note widens to its longest line;
with these paragraphs it needs a width limit and wrapping (macro lines stay one per line).

## Step 1: build

- `Modules/Window.lua`: one local builder, `DeleteHelp(firstLine)`, returns the whole
  block (firstLine, the existing "Deletes one Soul Shard…" line, a blank line, the Life
  Tap macro, a blank line, the Bane macro, a blank line, the Bane line, then the warning).
  `DressWindow` uses it for the Delete Shard tip (help on only, as now) with the tooltip's
  first line; the welcome uses it with the welcome's first line. The macro text itself
  (`#showtooltip`, `/ssf delete`, `/cast `) stays as code.
- Spell names by ID, so they show in the player's language: Life Tap 1454 (already in),
  Bane of Agony 980 (Classic calls it Curse of Agony). **Check first** in game, before
  building:

      /run print(C_Spell.GetSpellName(980))

  If it doesn't print "Bane of Agony", stop and ask: the macro and both Bane lines name it.
- Strings, new, in all six locales' `-- Tooltips` sections:
  - "Use your keybind, click this button, or use a macro, or all of the above."
    Tooltip only: it doesn't go into `/ssf help` (no button in chat). The existing
    "Deletes one Soul Shard…" line stays the `/ssf help` text, unchanged.
  - "The Bane macro lets you delete on the move when you don't want to use %s." (%s =
    Life Tap's name from 1454)
  - "Make sure you're not targeting an enemy with the Bane macro. Otherwise it won't
    delete because you'll be in combat before the delete fires."
  - "Bane": see Open, 1.
- The welcome note (`Window:LOADING_SCREEN_DISABLED`, `SSFWindow:ShowSidePanel`):
  `ShowSidePanel(title, body, note, extra)` gets a fourth block, `extra`, under the gold
  "You'll only see this once." line: left-justified (the macro lines read as code),
  wrapping. Its first line is the welcome's own ("…click Delete Shard, bottom left in the
  UI…", one more string in all six locales). Width: the note is never wider than the main
  window (`self.frame:GetWidth()`, no new magic number); `extra` wraps inside that. The
  OnShow height fit adds `extra`'s height and one more `SIDE_ROW_GAP`.
- Checks before handing over: `luac -p` on every changed file, no new globals, and the
  key check (every L[] key in the code exists in all six locales).
- `.docs/TOOLTIPS.md`: the Delete Shard entry and the welcome note updated to this text.

## Welcome re-pop for 1.8 (Mike, 2026-10-19)

Players who saw 1.7's welcome see the new one once; minor revs never re-pop it.
- The code keeps one number, `WELCOME_VERSION`: the SSF version the welcome last
  changed in, as an integer, two digits per part (1.8 = `10800`, 1.8.1 = `10801`,
  1.10 = `11000`). Plain math, no string parsing.
- Each character's profile keeps the last value it saw (`welcomed`). 1.7 saved `true`:
  read as older than any number. Nothing saved: also older.
- The note pops at load when the character's value is lower than `WELCOME_VERSION`, and
  stores `WELCOME_VERSION` once shown.
- A release that doesn't change the welcome leaves `WELCOME_VERSION` alone (1.8.1 keeps
  `10800`), so nothing pops. One that does sets it to its own version.
- The test paste (`welcomed=nil`) still works: nothing saved reads as older.

Open: **the gold "You'll only see this once." line for returning players.** Recommended:
hide it when the character had seen an earlier welcome (they already read that promise),
the same as on a re-pop from the main-window button.

## Macro buttons (Mike, 2026-10-19)

Settled:
- One button, one click makes both macros: Life Tap and Bane of Agony. The macro text is
  the one in the tooltip (`#showtooltip`, `/ssf delete`, `/cast <spell>`, spell names by
  ID). Per character.
- The click creates them (a missing one only; an existing one is left alone), then opens
  Blizzard's own macro window on the character tab; the player drags them wherever they
  want. SSF never places a macro on a bar.
- Where (Mike, 2026-10-19): the create button lives in the welcome note only, right under
  the macros it shows ("Create the recommended macros above", or close to it). The main
  window gets a "Create recommended macros" button at the bottom, shown only while either
  macro is missing; its click pops the welcome note (same panel, same glow, same text),
  it never creates anything itself. One explanation, one code path, nothing to edit twice.
- No option to hide the main-window button (Mike): players with their own macros just
  don't click it; they're rarely in the window anyway.
- Re-popped from that button, the note hides its gold "You'll only see this once." line
  (true only on the first load). It doesn't set or clear the welcomed flag.
- Missing means not found by name. Once both exist the main-window button goes away (the
  welcome's own button is only ever seen inside the note). If
  the player deletes one, the button shows again (checked when the window opens, and on
  the game's macro-change event while it's open). A macro is never made without a click.
- In combat: the button is dead. No message, no popup.
- Scope stops there: no macro editor, no custom spells, no placing on bars.

Open (Mike decides, before building):
1. **Macro names:** what the player sees in their macro list (e.g. "SSF Life Tap",
   "SSF Bane"). The name is also how SSF finds them, so a renamed macro counts as missing.
2. **No free macro slot** (out of combat): say so in chat, or stay silent like combat.
3. **The welcome button's exact words** (Mike's: "create the recommended macros above").

Check on Forever first (one `/run` each, before building): `CreateMacro` works from an
addon; the macro window opens from an addon and can select a per-character macro (the
exact call differs by client version).

Build: a new `Modules/Macros.lua` (one job: make the two macros and report whether each
exists; public methods only), the two buttons (welcome and main window), button labels
and any message in all six locales.

## Step 2: test (Mike, in game)

1. Help on, hover Delete Shard: the tooltip reads as above, macros one line each.
2. Clear the welcome flag and reload: the note shows the Delete Shard text under "You'll
   only see this once.", no wider than the window, wrapped, macros one line each. Also
   with the window dragged to the right edge first (it centers, the note fits).

       /run LibStub("AceAddon-3.0"):GetAddon("SSF").db.profile.welcomed=nil ReloadUI()

3. Switch Language through all six: the spell names are the game's own, nothing cut off.
4. Macro buttons: click the welcome's button, both macros appear and the macro window
   opens on the character tab; drag them to a bar; the main-window button is gone.
   Delete one in the macro window, reopen SSF: the main-window button is back; its click
   pops the welcome note (no "only see this once" line); the note's button makes only the
   missing one. In combat a click does nothing.
5. No BugSack errors. Then "tested works" and a WIP commit (local, no push).

## Step 3: prose

- CHANGELOG 1.8.0: the Delete Shard tooltip and the welcome show every way to delete,
  both macros and the no-target tip; the macro buttons; the new gallery.
- README "Using it" already shows both macros: check it still matches.
- Screenshots: the whole new gallery (`.docs/SCREENSHOTS.md`, eight shots) is shot once,
  after step 2 tests out, and ships with this release at the publish skill's screenshot
  step. The shots show this text and the macro buttons, so not before. Mike shoots
  them in order; Claude renames them by creation time to `01_welcome.png` …
  `08_minimap_tooltip.png` in
  `media/` (Mike says if any shot was retaken or extra). The old gallery files listed in
  SCREENSHOTS.md come out of `media/`. Captions: `.docs/captions_edit.md` (Mike's lines)
  go into `media/image_captions.txt`, in gallery order. On CurseForge the new eight
  replace the old gallery.

## Step 4: clean up

Delete this file and commit, before anything is pushed: it is not in .pkgmeta's ignore
list. Then the release (addon-release skill): a new feature, so the middle number.

## Open (Mike decides)

1. **"Bane" in other languages.** Recommended: English keeps Mike's "Bane"; each
   translation writes its own short name for the spell. Alternative: fill in the full
   spell name from 980 in every language ("The Bane of Agony macro…"), which changes
   Mike's English wording.
2. **After the release:** `.docs/SCREENSHOTS.md` and `.docs/captions_edit.md` have done
   their job. Recommended: delete both in step 4, like the 1.7 temporaries; keep
   TOOLTIPS.md and BAG_API_NOTES.md.
