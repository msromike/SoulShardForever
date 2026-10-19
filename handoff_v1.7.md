# Handoff 1.7: Options split, "?" help toggle

Written 2026-10-19, after 1.6.1 shipped. Four steps, in order. Each step's testing is
Mike's, in game; nothing moves to the next step without his "tested works".

Prose (README.md, CHANGELOG.md, media/curseforge.md, media/image_captions.txt) is NOT
kept up during steps 1 and 2. It is all written in step 3.

Nothing is pushed until step 4 is done. Then the release goes through the addon-release
skill (version picked there; a new feature, so the middle number).

## Why

- New players hover an option in the SSF window and get nothing. Every option is built
  tooltip-free on purpose (`descStyle = "hidden"`), because tooltips annoy anyone who
  already knows the addon. Mike's answer: a "?" button in the title bar next to the X
  that switches help on for the session. Off by default, so regulars never see tooltips;
  the "?" is the hint a confused player looks for (Blizzard's HelpPlate "?" works the same
  way). It backs the "Easy" in the CurseForge title ("Easy Soul Shard Manager").
- Options.lua (723 lines) does four jobs: the settings table, chat/status text, the
  window's life cycle, the window's styling. The feature lands in the table and the
  window code, so the window comes out first.

## Step 1: split Options.lua (internal refactor)

Rule: no behaviour change, nothing a player can see. Own commit.

Cut (each file one job, header contract, modules talk via messages and public methods
only; Ace3 for everything):
- **Options.lua keeps** the settings table: `BuildTable` and its helpers (`Toggle`,
  `Width`, `VolumeKey`), AceConfig registration, the chat commands, Tab completion,
  `Rebuild`, `TogglePause` (the key binding uses the chat command's path).
- **New Modules/Window.lua** ("Window" module): `Open`, `Toggle`, `Feed`, `Refresh`, the
  chat-change redraw (`OnOptionsChanged`) and bag-bucket refresh, `DressWindow`,
  `OpenKeyBindings`, and the title styling (class color, title bands,
  `StyleGroupTitles`, the AceConfigDialog Open hook). It reaches the table only through
  AceConfigRegistry (app "SSF"). Options tells it about a rebuild with a message
  (e.g. `SSF_OPTIONS_REBUILT`); Window re-dresses and refreshes on it.
- **New Modules/Status.lua** ("Status" module): `StatusText`, `PauseText`, the login and
  reload status lines (`PLAYER_ENTERING_WORLD`, `PrintLoginStatus`).
- A helper both sides need becomes a public method on its owner, never a copy.

**Window width fits the content (added 2026-10-19, found while testing the split).** The
window grew to its content in height but was fixed at 310 px wide, so a longer language
truncated section titles with "..." (Russian "Предупреждение об осколках..."), wrapped
labels, and the pause sound row (fixed 170 + 85 px) fit the box to 0.0001 px (measured),
so rounding decided whether the volume dropdown wrapped. Mike's rules:
1. The width is dynamic: measured from the content after every feed, like the height.
   No hand-picked minimum (310 goes): text pieces report their natural (unwrapped)
   width; full-width controls (sliders, dropdowns) declare the minimum they need, in the
   widget file that draws them. Capped at the screen width minus SCREEN_MARGIN, the same
   guard the height uses.
2. A language that comes out too wide gets a best-effort brevity pass on its strings.
3. No time sink: if it can't get narrower cheaply, that language gets a wider window.
   Never "..." and never clipped text.
The pause sound checkbox sizes to its own label instead of a fixed width.

Callers to move: Modules/Broker.lua:51 `Options:Toggle` → Window;
Modules/Trimmer.lua:44 and :58 `Options:StatusText` → Status; the bare `/ssf` output in
Options → Status. Bindings.xml:14 `Options:TogglePause` stays. The toc lists the two new
files after Options.lua.

Testing (Mike, in game):
1. The window opens from the minimap icon, `/ssf` and `/ssf options`, and closes the
   same ways as before.
2. It looks and behaves as before: section titles, title bands, Keybindings button,
   Delete Shard button, footer, sliders, dropdowns.
3. A language switch rebuilds it in the new language. Every one of the six languages:
   no "..." on any title, no clipped text, the volume dropdown on the Play pause sound
   row; a language that looks too wide gets a brevity pass (best effort, no time sink).
4. Announce line, login and reload status lines print as before.
5. The pause key binding works.
6. No BugSack errors.

## Step 2: the "?" help toggle (the feature)

Settled:
- "?" sits in the title bar beside the X. Click toggles help mode.
- Help mode is off at login and resets on /reload. Nothing saved (no SSF.db key).
  Closing and reopening the window keeps it on for the session.
- While on, hovering an option shows its name and a one-line description. While off, no
  option tooltips (today's behaviour).
- The "?" always has its own tooltip, showing the current state, and looks lit while on.
- Tooltip text lives in the six existing locale files, a `-- Tooltips` section in each,
  English text as the key like every other string (the AceLocale convention SSF already
  follows). No separate tooltip file. Rewording an English line = renaming that key in
  all six files, or the other five fall back to English.

Open (Mike decides, during this step):
1. **"?" button art.** Blizzard's round HelpPlate "?" if the Forever client has it, or an
   icon from wowhead (Mike picks from a list with file IDs).
2. **"?" tooltip wording.** Placeholder: off = "Help: off. Click to show help when you
   hover an option." / on = "Help: on. Click to hide it." Mike's alternative: "Toggle
   expanded tooltip help".
3. **Description wording.** Drafted into enUS first; Mike edits them in the VS Code diff
   view before they are translated into the other five.

How:
- **Session flag `Options.help`**, a plain module field, nil at load. Same pattern as
  `Options.loginStatusPrinted`: a /reload resets it for free.
- **Tooltips on and off.** AceConfigDialog reads `descStyle` at hover time from the live
  table (`OptionOnMouseOver`, AceConfigDialog-3.0.lua:495-533; only nil/"tooltip" shows
  one). `descStyle` must be a literal string, not a function (allIsLiteral :154-159).
  So one function in Options, run at the end of `BuildTable`, sets every entry that has a
  `desc` to `descStyle = Options.help and "tooltip" or "hidden"`; entries without `desc`
  keep "hidden".
- Public `Options:ToggleHelp()` flips the flag and calls the existing `Options:Rebuild()`.
  The language switch also goes through Rebuild, so help survives a language change.
  Window reads the state through `Options:IsHelpOn()` when it dresses the window.
- Settings.lua's GUI entries (Settings.lua:80-89) copy `desc = def.desc` like the cmd
  twins already do (:104); the descStyle walk covers them.
- **Descriptions**, `desc = L["<English line>"]` on each entry. Four already exist:
  - Shards to keep: "The cap. Shards over this number are deleted one per press."
  - Match soul bag size: "While a soul bag is equipped, the cap is its slot count.
    Without one, the slider rules." (translated in all six, used nowhere today)
  - Pause all SSF actions: "Stop every press from moving or deleting shards, until you
    turn it off."
  - Announce deletions in chat: "One chat line per deleted shard, for addons that watch
    chat."
  - New, about 11: Play pause sound, Log pause to chat, Low shard warn, Glow bag button
    when low, Show shard count on bag bar, Colorize bag count, Show on soul bag when
    equipped, Bag counter font, How shards move, Show minimap icon, Language.
  - No desc: the pause volume dropdown (empty name, so a blank tooltip title; Play pause
    sound's line covers volume), the status line, the gaps.
- **The "?" button** in Widgets/SSFWindow.lua, Constructor next to the X (:219-221):
  parented to `frame`, anchored left of the X, stored on the widget table like
  `closebutton`. The window only draws it. New method following `SetActionButton` /
  `SetFooter`, e.g. `SetHelpButton(onClick, isOn, tipText)`, called from
  `Window:DressWindow`; the click calls `Options:ToggleHelp()`. Lit while on
  (LockHighlight or the pushed texture). OnEnter shows its tooltip on GameTooltip; a
  click while hovered refreshes the text.
- Known limits (accepted): the font dropdown (LSM30_Font) only fires hover from its
  arrow; group headers fire nothing. The same table feeds Blizzard's AddOns options
  panel, so help mode shows there too while on.

Testing (Mike, in game):
1. `/ssf`: hover options, no tooltips. The "?" shows its own tooltip (help off).
2. Click "?": it lights; every option shows its name and line on hover.
3. Close and reopen the window: help still on.
4. Switch Language while help is on: tooltips stay on, in the new language.
5. `/reload`: help off, "?" unlit.
6. No BugSack errors.

## Step 3: prose

After step 2 tests out, write everything players and GitHub read, in one pass:
- CHANGELOG.md: the release entry (the "?" help toggle; the split is internal, not
  listed).
- README.md: the changelog line at the top (three kept), the "NEW" list, a line about
  the "?" in the options section.
- media/curseforge.md: a line about the "?" (QOL features).
- Screenshot: the window with the "?" lit and one tooltip showing, a new numbered file
  in media/ with its caption in media/image_captions.txt. Also owed from 1.6.1: retakes
  of 01, 02, 03, 04 and 06 (they show the v1.4.0 window) and a shot of the How shards
  move selector.

Mike reviews the prose in the VS Code diff view.

## Step 4: clean up

Once steps 1 to 3 are done and tested: delete this file and commit, before anything is
pushed. It is not in .pkgmeta's ignore list, so it would ship in the CurseForge zip if
it were still here at the tag. Then the release (addon-release skill).
