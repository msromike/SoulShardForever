# Handoff 1.8: teach the delete, make the macros, new gallery

Written 2026-10-19; rewritten the same day after the spikes and decisions, clean (only
what's settled). Read all of it before doing anything.

## Progress (update this first, every step)

Build in three rounds, each tested in game by Mike before the next. After each round's
"tested works": a local WIP commit (never pushed).

- [x] Spikes (seven, all passed; answers below)
- [x] Open decisions (all ten settled; in the design below)
- [ ] **Round 1: refactor only.** Move the welcome out of Window.lua into a new
      Welcome.lua; behavior identical to 1.7. Test: the 1.7 welcome still pops as before.
      Built 2026-10-19: Modules/Welcome.lua (new), Window.lua (welcome out, public
      `ShowNote(title, body, note)` in), .toc (+Welcome.lua after Window.lua), Core.lua
      (one comment). Tested works (Mike, 2026-10-19); committed `f821e46`.
- [x] **Round 2: Macros, DeleteHelp, the new welcome note.** Tested works (Mike,
      2026-10-19); committed `5c906d7`. Test: the tooltip text, the
      note's layout (also with the window at the screen's right edge), the note's create
      button makes the macros and opens the macro window.
      Built 2026-10-19: Macros.lua and DeleteHelp.lua (new), Welcome.lua (the new note,
      public `Show()`), Window.lua (tooltip from DeleteHelp; ShowNote passes extra and
      button through), SSFWindow.lua (note: extra block, button, wraps, capped at the
      window's width, `sidepanel:Fit()` for its height), enUS strings, .toc. Old "You'll
      only see this once." key still in the five translations (round 3 removes it). The
      Bane sentence is formatted (Life Tap, Bane): English's plain %s takes Life Tap and
      ignores the rest; translations use %1$s/%2$s (no skipped positions). Checks pass.
      Mike's test: tooltip and note text right; macros made, macro window opens on them.
      Reload flow built (checks pass, waiting on Mike's re-test): Macros:Create makes,
      sets profile.macroWindowAfterReload, ReloadUI; LOADING_SCREEN_DISABLED opens the
      window. Test B lines out. Note button greyed while both exist, small line under it.
      ShowSidePanel/ShowNote now take (title, body, note, opts).
      **To do (Mike, 2026-10-19): remove the welcome note's pixel glow.** At the note's new
      size it looks garish. (LCG.PixelGlow_Start/Stop in SSFWindow's side panel.)
      Fixes built after it:
      - Note width: it came out ~10% wider than the window (sized before the window's
        one-frame-later re-fit). Now `LayoutSidePanel` runs on show and on every window
        width change (OnWidthSet).
      - Stale macro icon: a freshly made macro showed another macro's icon (Summ's, 136223)
        until a reload; GetMacroInfo itself reported it. Repro: delete both in the macro
        window, reload, create. Failed: re-saving the text; Blizzard's own two-step
        (CreateMacro with no body, then EditMacro with the body); the icon as the path
        "Interface\Icons\INV_Misc_QuestionMark" (GetMacroInfo gave nil). Worked (Mike,
        2026-10-19): after creating, `EditMacro(index, nil, 134400)` once per new macro.
        But only until the next click in the macro window, then stale again; and macros
        made by hand in Blizzard's window do the same. Hence the reload flow.
      - Never hard-code the spell's icon (Mike: breaks macros players extend with
        modifiers). Mike tests his way: he deletes macros in the macro window and reloads
        himself; give him only the lines to paste after that.
- [x] **Round 3: "Create macros" in the main window, the 1.7 re-pop, MacroGlow, six
      languages.** Tested works (Mike, 2026-10-19); committed (see git log, "WIP 1.8
      round 3"). Still open: the help line for "Create macros" (Mike's words).
      Built 2026-10-19 (checks pass, waiting on Mike's test): SSFWindow SetMiddleButton
      (centered; FitWidth counts it) and pixel glow removed; Window shows "Create macros"
      while Macros:AnyMissing(), click sends SSF_SHOW_WELCOME, re-dresses on
      SSF_MACROS_CHANGED; Welcome WELCOME_VERSION 10800 and listens SSF_SHOW_WELCOME;
      Macros sends SSF_MACRO_WINDOW_SHOWN, public Names(); MacroGlow.lua (new); five
      translations, old "only once" key gone; .docs/TOOLTIPS.md updated. Open: a help
      line for "Create macros" (every bottom button has one while help is on; Mike's words).
      Mike's test so far: re-pop, no pixel glow, greyed button, glow on both (SSF_LT was
      not on a bar: deleting a macro clears it from bars), glow follows tabs, stops on drop,
      "Create macros" gone after; German and Russian tooltips fit. Found: the tooltip
      dropped the blank line between the two macros in English and German (not Russian).
      Fix: ButtonTip adds one tooltip line per text line, blank ones as " " spacers.
      Still to see: the fix in English, and "Create macros" in the bottom row.
- [ ] Gallery and prose (Step 3)
- [ ] Release (Step 4)

## Start here

**State.** SSF 1.7.0 is shipped (commit `d339d62`, tag `v1.7.0`, pushed). An earlier
version of this handoff is committed locally as `bdb9252`; this rewrite isn't committed.

**What 1.8 is.** One release, one gallery shoot:
1. Delete Shard's help-mode tooltip teaches every way to delete, with two macros.
2. The first-load welcome note carries the same text, and re-pops once for 1.7 players.
3. One click makes the two macros and opens Blizzard's macro window.
4. The new eight-shot gallery, shot after testing, ships in the same release.

**Who it's for.** SSF's players are casual (dads playing 90 minutes a night). Setup has
to be in front of them, plain. Mike: "this is the bread and butter of the add-on."

**How Mike works** (also in Claude's memory; follow it):
- Say what a command does before running it. Plain words, no jargon: he asked for
  English twice this session.
- His text is his: "fix" means typos, punctuation and spacing only, in his words. Never
  rewrite it into yours. A claim that looks wrong may be a mechanic he knows: ask first.
- Nothing is committed before his "tested works"; nothing is pushed or tagged before his
  explicit yes (the addon-release skill does the release).
- One decision per question, real choices only, with a recommendation.
- One job per file (his addon standards). He was angry that 1.7 put the welcome inside
  Window.lua; don't pile unrelated jobs into an existing module.

## The text (Mike's, final)

A blank line is a real break; wrapped lines here are for reading only.

**Delete Shard tooltip** (help on, hover Delete Shard; gold title, white text, paragraphs
wrap by themselves, macro lines one per line):

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

**Welcome note**, top to bottom: title "Welcome to SSF", divider, arrow and "i", "Click for
in-game tooltip help." (all as in 1.7), then the gold line:

    You won't see this welcome screen again on this character unless you click Create macros in the UI.

then the Delete Shard block above with its own first paragraph:

    Use your keybind, click Delete Shard, bottom left in the UI, use a macro, or mix and
    match. Deletes one Soul Shard if you are over the cap.

then a wide button: **Create recommended macros**.

The gold line replaces 1.7's "You'll only see this once." It is true in every case today:
alts each get the note once; the main-window button is gone once both macros exist. A
future release that re-pops the note rewrites the line then.

**Main window button:** **Create macros**.

**No free slot** (red error text): **No free macro slots. Delete a macro and try again.**

**Mike's mechanics, as he stated them. Do not "correct" them.** Life Tap never puts you
in combat, whatever you target. An offensive spell with no target never casts (no mana, no
combat) and the /ssf delete line still fires every press, so it clears shards on the move.
With an enemy targeted, you're in combat before the delete fires.

## Settled design

**Module layout.** One job per file, calls one way only:

    Welcome    -> Window      open, and show this note
    Welcome    -> DeleteHelp  give me the help text
    Welcome    -> Macros      create the macros
    Window     -> DeleteHelp  give me the tooltip text
    Window     -> Macros      is one missing? (show or hide the button)
    DeleteHelp -> Macros      give me the macro text
    Macros     -> nobody

- `Modules/Macros.lua` (new): makes the two macros, says whether each exists, holds the
  macro text (a public method returns each body). Announces an SSF macros-changed message
  from a bucketed UPDATE_MACROS (it fires in bursts of ~5, even on clicking a macro in
  Blizzard's window).
- `Modules/DeleteHelp.lua` (new): builds the Delete Shard help text for a given first
  paragraph; asks Macros for the macro text. Change the macro text once, both follow.
  Macros already in a player's list stay as made.
- `Modules/Welcome.lua` (new): when the note pops (WELCOME_VERSION), what it says, its
  create button. The 1.7 welcome code moves here from Window.lua: `LOADING_SCREEN_DISABLED`
  (opens the window, turns help on, shows the note) and the `welcomed` check in OnEnable.
  It must be switched off for non-warlocks like every module (Core's gate).
- `Modules/Window.lua`: the window only: options, bottom buttons, the Delete Shard tooltip
  (asks DeleteHelp), "Create macros" shown while Macros says one is missing. Its click
  sends an SSF "show the welcome" message; Welcome listens. Window never calls Welcome.
- `Widgets/SSFWindow.lua`: the note's frame stays here (drawn as part of the window);
  Welcome fills it. Gains the middle bottom-row button and the note's new parts.
- `Modules/MacroGlow.lua` (new, round 3; Mike, 2026-10-19: "chef's kiss"): when SSF
  opens Blizzard's macro window on its macros, the SSF_LT and SSF_BoA buttons glow
  (LibCustomGlow) until the cursor touches each. Blizzard's grid reuses its button frames
  on every redraw (tab switch, scroll, UPDATE_MACROS bursts), so after each redraw it
  re-checks: glow the frames now holding an untouched SSF macro, clear the rest. Buttons
  from `MacroFrame.MacroSelector:EnumerateButtons()`, macro name in `button.Name`. The
  macro window isn't secure, so hooks can't taint. Macros tells it to start (message or
  public call, one way).
- `.toc`: Macros, DeleteHelp before Window; Welcome after Window.

**Spell names** by ID in the client's language: `C_Spell.GetSpellName(1454)` (Life Tap)
and `(980)` (Bane of Agony on this client), each with its English fallback. This client has
no `GetSpellInfo`.

**Strings** (in all six locales' `-- Tooltips` sections; English is the key):
- "Use your keybind, click this button, use a macro, or mix and match. Deletes one Soul
  Shard if you are over the cap."
- "Use your keybind, click Delete Shard, bottom left in the UI, use a macro, or mix and
  match. Deletes one Soul Shard if you are over the cap."
- "In a macro, put /ssf delete on the line before the ability:"
- The two Bane sentences. English keeps Mike's word "Bane"; the five translations put in
  the game's full name from 980. The first is formatted with (Life Tap, Bane): English's
  plain `%s` takes Life Tap; a translation uses `%1$s` (Life Tap) and `%2$s` (Bane). The
  second is formatted with (Bane): English has no `%s`; a translation uses one.
- The gold line, replacing "You'll only see this once." (remove the old key).
- "Create recommended macros", "Create macros", "No free macro slots. Delete a macro and
  try again."
- `/ssf help` is unchanged: its existing "Deletes one Soul Shard if you are over the cap.
  In a macro, put /ssf delete on the line before the ability." string stays.

**Welcome note frame.** `SSFWindow:ShowSidePanel` gains the long text block under the gold
line (left-justified, wrapping) and the wide button under it. The note is never wider than
the main window (`self.frame:GetWidth()`, no new constant); the gold line wraps too. The
panel's OnShow height adds the new parts and their `SIDE_ROW_GAP`s. Too near the right
screen edge, the window moves to the center as in 1.7.

**Welcome re-pop.** `WELCOME_VERSION`, an integer, two digits per part: 1.8 = `10800`.
Each character's `profile.welcomed` keeps the last value it saw; 1.7 saved `true`, and
`true`, `false` or nothing counts as older. The note pops at load when the saved value is
lower, then stores `WELCOME_VERSION`. A release that doesn't change the welcome leaves the
number alone. `Core.lua` keeps `welcomed = false` as the default. The note is always the
same box, every way it opens; a re-pop from the button doesn't touch `welcomed`.

**Macros.**
- Names `SSF_LT` and `SSF_BoA`, the same in every language. Found by name in both
  sections (`GetMacroIndexByName`, 0 = missing), so a renamed one counts as missing.
- Bodies: `#showtooltip`, `/ssf delete`, `/cast <Life Tap>`; the same with Bane of Agony.
  Icon: file ID 134400 (the question mark, which with `#showtooltip` shows the spell's
  icon). The name "INV_MISC_QUESTIONMARK" gave a purple night sky in spike 2; check the
  icon at test.
- One click makes the missing ones only. Never split: all missing ones go to the
  character's macros if it has a free slot for each, else the account's if it has, else
  the red error and nothing made (one free slot with both missing: the error). Counts:
  `local a,c = GetNumMacros()`; limits: `Constants.MacroConsts.MAX_ACCOUNT_MACROS` (120)
  and `MAX_CHARACTER_MACROS` (30). Character macros are global indices 121 to 150.
  Error: `UIErrorsFrame:AddExternalErrorMessage(msg)` (shows 2 s plus a 0.5 s fade; no
  per-message time exists, so the text stays short).
- Then open Blizzard's macro window on the tab they went into, a new macro selected:
  `ShowMacroFrame()`, then `MacroFrame:ChangeTab(2)` (character) or `(1)` (account), then
  `MacroFrame:SelectMacro(index - base, true)`, base 120 on the character tab, 0 on the
  account tab. Proven in spike 5. The player drags them; SSF never puts a macro on a bar.
- The main window's "Create macros" sits in the middle of the bottom row, between Delete
  Shard (far left) and Key Bindings (far right), shown only while either macro is missing
  (checked when the window opens and on Macros' changed message). The window's width
  counts the bottom buttons (FitWidth), so it may widen while the button shows. Its click
  pops the welcome note; it never creates anything itself. No option to hide it.
- **Reload flow** (Mike, 2026-10-19; the stale-icon bug hits hand-made macros too, and a
  reload is the only thing that cures it): the note's button makes the missing macros,
  saves a flag ("open the macro window after the reload"), and reloads. After the loading
  screen, Macros sees the flag, clears it, and opens the macro window on the new macros
  (right icons, ready to drag). The welcome doesn't re-pop. No slots: red error, no
  reload. The note's button is greyed out while both macros exist. Under the button, a
  small line (Mike's words; "restart" → "the reload", Claude's one-word fix, Mike didn't
  object): "Creates the macros, reloads your UI and opens the macro box after the
  reload." The tab comes from the slot number (121 and up = character), nothing saved
  but the flag. Macros owns all of it. The Test B
  `EditMacro(index, nil, 134400)` lines come out (they only hid the bug until the next
  click in the macro window). The name stays the fingerprint: no hash comment (Mike asked;
  a hash breaks when players extend the macro).
- In combat every macro button is dead: no message, no popup.
- Scope stops there: no macro editor, no custom spells, no placing on bars.

**Docs.** `.docs/TOOLTIPS.md` is the master list of all tooltip text (local only, never
committed): update the Delete Shard and welcome entries to the final text.

**Checks before handing over code:** `luac -p` on every changed file; no new globals
(`luac -l -p file | grep SETTABUP`); every `L["…"]` key the code uses exists in all six
locales.

## Glow spikes (before building MacroGlow; SSF_LT and SSF_BoA must exist)

G1. Find our buttons in Blizzard's grid by name. Must print "found" twice and a count.

    /run ShowMacroFrame() MacroFrame:ChangeTab(2) local n=0 for b in MacroFrame.MacroSelector:EnumerateButtons() do n=n+1 local t=b.Name:GetText() if t=="SSF_LT" or t=="SSF_BoA" then print("found",t) end end print("buttons",n)

    Answer (2026-10-19): found both, 18 buttons. Works.

G2. Glow them (test global SSFG keeps the buttons for G3). Both must glow.

    /run SSFG=SSFG or {} local G=LibStub("LibCustomGlow-1.0") for b in MacroFrame.MacroSelector:EnumerateButtons() do local t=b.Name:GetText() if t=="SSF_LT" or t=="SSF_BoA" then G.PixelGlow_Start(b) SSFG[b]=true end end

    Answer (2026-10-19): both glow, but stock PixelGlow is too subtle (Mike). Switched to
    ButtonGlow (the golden proc glow, as LowGlow uses): "the glow looks good." MacroGlow
    uses ButtonGlow. (Icons were the stale Summon ones: no reload in the spike, expected.)

    /run local G=LibStub("LibCustomGlow-1.0") for b in pairs(SSFG) do G.PixelGlow_Stop(b) G.ButtonGlow_Start(b) end

G3. **Changed (Mike, 2026-10-19): the glow stops when the macro is dropped on an action
bar, not on hover.** Fallback if drop can't be detected: stop on hover. A macro already
on a bar when the window opens doesn't glow; picked up and let go elsewhere, it keeps
glowing. Spike: print what lands in a bar slot, then drag SSF_LT to an empty slot. Must
print the slot and something naming SSF_LT (macro type, its index, or the action text).

    /run local f=CreateFrame("Frame") f:RegisterEvent("ACTIONBAR_SLOT_CHANGED") f:SetScript("OnEvent",function(_,_,s) local t,id,sub=GetActionInfo(s) print(s,t,id,sub,GetActionText(s)) end)

    Answer (2026-10-19): works. Dropping printed "68 macro 698 spell SSF_LT" and
    "69 macro 698 spell SSF_BoA". The id is NOT the macro index: it's the spell the macro
    resolves to (698 = Ritual of Summoning, the stale-icon bug again; one plain macro gave
    "1 macro 121 BofA", the index, no subtype). Match on `GetActionText(slot)`, the macro
    name, which was exact every time. Noise: a conditional macro (Fear, slot 164) fires
    ACTIONBAR_SLOT_CHANGED constantly, so check only the changed slot's text. At window
    open, scan the bar slots for the names: a macro already on a bar doesn't glow. Hover
    fallback not needed.

Hover fallback, only if drop fails (not needed):

    /run local G=LibStub("LibCustomGlow-1.0") for b in pairs(SSFG) do b:HookScript("OnEnter",function(s) G.ButtonGlow_Stop(s) end) end

G4. Frame reuse. Run G2 again, click the General tab, then the character tab: does the
glow stay on SSF_LT/SSF_BoA, move to other macros, or vanish?

    Answer (2026-10-19): the glow stayed on the frames, which then showed empty slots. The
    glow follows the frame, not the macro, as expected.

G5. Re-check on every fill. Blizzard's grid calls `MacroFrame.MacroSelector:RunSetup(button,
index)` for each button it fills (looked up as a method each call, so a hooksecurefunc on
the instance catches it). Hook it: SSF name → glow, anything else → clear. Then switch
tabs: the glow must follow SSF_LT/SSF_BoA and the empty slots must clear.

    /run local G=LibStub("LibCustomGlow-1.0") hooksecurefunc(MacroFrame.MacroSelector,"RunSetup",function(_,b) local t=b.Name:GetText() if t=="SSF_LT" or t=="SSF_BoA" then G.ButtonGlow_Start(b) else G.ButtonGlow_Stop(b) end end)

    Answer (2026-10-19): works. **All glow spikes done; MacroGlow's design is proven:**
    ButtonGlow; hook RunSetup to glow by name after each fill; stop a macro's glow when
    ACTIONBAR_SLOT_CHANGED shows its name in the changed slot (`GetActionText`); at start,
    skip any macro already on a bar.

## Spike answers (2026-10-19, all on this client)

1. `C_Spell.GetSpellName(980)` = "Bane of Agony".
2. Two `CreateMacro` calls in one `/run` both worked (132, 133); no click per call.
3. `GetMacroIndexByName`: the index if found, 0 if not.
4. Counts 5 account, 15 character (13 + the two tests). `MAX_ACCOUNT_MACROS` /
   `MAX_CHARACTER_MACROS` globals are nil even after loading Blizzard_MacroUI; the limits
   are `Constants.MacroConsts` (120, 30). Source: Gethe/wow-ui-source, `forever` branch
   (1.60.1, build 70450), Blizzard_MacroUI.lua.
5. Proven: `ShowMacroFrame() local m,i=MacroFrame,GetMacroIndexByName("SSFtest1")
   m:ChangeTab(2) m:SelectMacro(i-Constants.MacroConsts.MAX_ACCOUNT_MACROS,true)` opened
   the character tab with SSFtest1 selected. Opening always lands on the account tab
   first (OnShow calls `ChangeTab(1)`).
6. UPDATE_MACROS fires, in bursts (see Macros.lua above).
7. Test macros deleted; both look up as 0.

## Step 2: test (Mike, in game; round 3 runs all of it)

1. Help on (the "i"), hover Delete Shard: the tooltip reads as above.
2. Welcome:

       /run LibStub("AceAddon-3.0"):GetAddon("SSF").db.profile.welcomed=nil ReloadUI()

   The note shows the block and the create button, no wider than the window, wrapped,
   macros one line each. Also with the window dragged to the screen's right edge first.
3. Re-pop for a 1.7 player:

       /run LibStub("AceAddon-3.0"):GetAddon("SSF").db.profile.welcomed=true ReloadUI()

   It pops once; reload again, it doesn't.
4. Macros: click the welcome's button; both macros exist and the macro window opens on
   the tab they went into (character, or account if the character's lacked room for
   both); drag them to a bar; the main-window button is gone. With no room for both in
   either section: the red error, nothing made. Delete one, reopen SSF: the button is
   back; its click pops the note (the same box); the note's button makes only the missing
   one. In combat a click does nothing.
5. Language through all six: spell names are the game's own, nothing cut off.
6. No BugSack errors. Then "tested works" and a local WIP commit.

## Step 3: gallery and prose

- **Gallery:** `.docs/SCREENSHOTS.md` lists the eight shots in order. Mike shoots them in
  that order (they land in `Pictures\Screenshots` or `media/`); Claude renames them by
  creation time to `01_welcome.png` … `08_minimap_tooltip.png` in `media/` (Mike says if
  any was retaken or extra). The old gallery files listed there come out of `media/`.
  Captions: Mike's lines in `.docs/captions_edit.md` go into `media/image_captions.txt`,
  in gallery order.
- **Prose** (the addon-release skill's Propose step drafts it): CHANGELOG 1.8.0 (the
  Delete Shard text and welcome, the macro button, the welcome re-pop, the new gallery);
  README "Using it" already shows both macros, check it matches; curseforge.md only if
  the drafts touch it.

## Step 4: release

Before the release commit, delete this file (not in `.pkgmeta`'s ignore list, it would
ship) and `.docs/SCREENSHOTS.md`; keep `.docs/captions_edit.md`, `.docs/TOOLTIPS.md` and
`.docs/BAG_API_NOTES.md`. Then the addon-release skill: version 1.8.0 (a new feature), the
new gallery replaces the old one on CurseForge.
