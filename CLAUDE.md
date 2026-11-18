# Soul Shards Forever: the standard

This file is the contract for any AI session that edits this addon. Every line of Lua
here is written and maintained by AI sessions that start with no memory. The two rules
below exist so that a session can change one thing by opening one file and trusting APIs
it already knows. Read ARCHITECTURE.md next: it maps every file to
its job and every message to its sender and listeners.

## Rule 1: Ace everywhere

If a library on the named list does a job, call it. Never hand-roll the same thing, and
never reach around it.

Named list: every Ace3 package (AceAddon, AceEvent, AceTimer, AceBucket, AceHook, AceDB,
AceDBOptions, AceConsole, AceLocale, AceGUI, AceConfig with AceConfigCmd, AceConfigDialog
and AceConfigRegistry, AceTab, AceComm, AceSerializer) plus LibStub, CallbackHandler,
LibDataBroker, LibDBIcon, LibSharedMedia and its AceGUI widgets
(AceGUI-3.0-SharedMediaWidgets), LibCustomGlow.

- A lib on the list that is not yet embedded is still on the list: embed it (Libs\,
  embeds.xml) and use it. Size of the job does not matter; a three-line hook uses AceHook.
- Any other published library that would replace a block is a suggestion to raise,
  never something a session adds on its own.
- Custom AceGUI widgets (Widgets\) are extension-only: a widget wraps a stock AceGUI
  widget and adds to it. It never re-implements what the stock widget does. Where AceGUI
  has no base, the widget stands alone, and it still does one job (Rule 2).
- No insurance against a library changing behavior it has had for years. Use the library
  as it is, name the reach under "Lib internals", and let the library diff be the
  warning. A hand copy of library code kept "in case" is hand-rolling.
- Five documented exceptions, and no others. Each is explained in its file's header under
  Exceptions (a header with more than one numbers them: (1), (2)). The check counts this
  list against the headers, so it stays one per line, the file first:
    - DeleteButton: a raw named frame (/click needs a global name).
    - Counter: a raw FontString and backing texture on a Blizzard bag button (nothing on
      the list draws on a foreign button).
    - Window: the title strip behind option groups (AceConfigDialog hardcodes the group
      widget).
    - SSFFrame: the global name it gives the stock Frame's frame (UISpecialFrames closes
      it on Escape; the stock Frame is unnamed and Escape has no other way in).
    - Core: ApplyLanguage writes into AceLocale's own table (AceLocale has no way to
      switch language while the game runs).
- The stock Frame container is the window base: dialog-box art, resize disabled through
  its public EnableResize. Nothing styled like a different UI kit.
- Reading a library's internals (an AceGUI widget's label, frame or children, an
  AceConfigDialog field, AceDB's key for the character, a value AceConfig accepts but its
  spec does not name) is allowed only where no public API exists, only in Widgets\, the
  Window, Tooltip and Help modules and Core's profile-key migration, and every such
  field is named in that file's header under "Lib internals" with what breaks when it
  moves. The check holds the headers to that list of places, both ways, and holds the
  field to the code for every library object a file keeps from LibStub: a member it reads
  that is not one of that library's own functions must be named there.
- Blizzard's frames get the same treatment as a library's. A member read off a Blizzard
  global that Blizzard's API docs do not have (MacroFrame.MacroSelector, GameTooltip's
  SetOwner), a template a frame is created from, a parentKey read off a Blizzard button:
  each is a line in tools/blizzard_reaches.txt and is named in the file's header under
  "Game internals" with what breaks. The check finds the first two kinds by itself and
  searches every listed name in the client's own UI source on every run, so a game patch
  that renames one fails the check before a player meets it. A global the client has but
  its published source never mentions is on KNOWN_GLOBALS in tools/check.py with its
  proof from the game. Those lines are the break list for a library change,
  and a library change reaches players without any SSF release: LibStub runs the highest
  MINOR of each library across every addon on the player's install, and AceGUI swaps in
  any widget type that registers a higher Version. A newer AceGUI in any other addon runs
  SSF's widgets on code nobody tested. So when upstream moves (tools/sync_libs.py reports
  it), the diff is read against every "Lib internals" line before anything else.

## Rule 2: one job per file

- One job per file. The file name is the retrieval key: a helper buried in a bigger file
  is invisible to the next session. "It only has one caller" is not a reason to keep a
  helper inline. One job is the test.
- Every file starts with the header contract, in this order, empty fields omitted:

      <Name>: what this file does, as the first paragraph (ARCHITECTURE.md reads it)
      Public:     methods other files may call, with their arguments and returns
      Listens:    events and SSF_* messages it handles
      Hooks:      what it hooks, through AceHook, and when the hook attaches. Each hook is
                  written Owner.Method or Owner's OnScript; the check reads those two
                  forms and holds them to the code both ways
      Sends:      SSF_* messages it sends and their payload
      Lib internals: library fields it reads past the public API, and what breaks
      Game internals: what it reads off Blizzard's own frames past the documented API
                  (a frame global's member, a template, a parentKey), and what breaks
      Reads:      which other modules' public methods, and which profile keys
      Saves:      which profile keys it writes
      Acts on:    what it does to the game beyond its own frames and the profile: items
                  moved or deleted, macros made, sounds muted or played, a Blizzard frame
                  opened or drawn on, a global name set, a table handed to a library, a
                  script set (SetScript) on a frame the file did not create
      Exceptions: anything that breaks Rule 1 or 2 on purpose, and why
      Then the line "Touches nothing else."

  The header is the test. Anything in a file the header does not describe is misplaced.
  A session may stop reading at the header and trust it: the check holds every field
  that code can show to the code (Public, Listens, Hooks, Sends, Reads, Saves, Acts on,
  Lib internals, Game internals, Exceptions), both ways wherever it can.
- Modules talk only through AceEvent messages and public methods. No reaching into
  another module's tables or frames. A module is asked for by its quoted name,
  SSF:GetModule("Bags"), and called at once or kept in a local alias (`local Bags = ...`
  or `local function Bags() return ... end`); the check follows nothing else. The AceDB profile on the addon object is the one
  shared state and any module may read it; re-deriving another module's rule from it is
  a violation (ask that module).
- Before writing any helper, grep the addon for the thing it does. Most helpers already
  exist: bag queries are in Bags, thresholds in Cap (IsOver is the delete gate), the two
  combat questions in Combat, the pause gate in Trimmer (Paused), colors in Colors, chat and tooltip
  wording in Status, tooltips in Tooltip, the pause sound's notches in Sounds. ARCHITECTURE.md lists
  the rest.
- A macro the player copies looks the same on every panel: dark box, code color. A
  module hands the panel a macro block ({ text, macro = true }) and SSFSideNote draws
  the box; no caller paints a macro itself. Colors:Code is for the tooltip's one
  string (DeleteHelp), where no box can be drawn. The check fails on any other call.
- No pass-through files: a module whose every function only calls another module adds a
  hop and no job. The check fails on one; its callers ask the other module directly.
- A new job gets a new file, named for the job, with its header written before its code.
  ARCHITECTURE.md is generated from the headers and the code: run the check, never edit
  the map by hand.

## Libraries

Libs\ is committed and ships exactly as committed: .pkgmeta has no externals, so what was
tested is what the package holds. tools\externals.txt names each library's upstream; the
check script reports drift from it as information. A library changes only on purpose:
`python tools/sync_libs.py --apply`, an in-game pass, a commit of its own with a changelog
line. Never edit a file under Libs\ by hand. One exception: Libs\AceTab-3.0 carries a
local fix pending upstream, see tools/externals.txt. It is the only library edited by hand.

## Every commit

- Run `python tools/check.py` (about five seconds); it must end ALL PASS. Its steps, in
  order: luacheck; the headless tests (tests/run.lua); the real options window against
  tests/window_controls.txt; every locale carries every key and keeps its placeholders;
  every L[...] the code looks up exists; colors typed only in Colors; the header layout;
  the headers' claims against the code; the toc against the files on disk; Bindings.xml
  against what it calls; the exceptions and Lib internals counted against this file;
  Acts on; Hooks; Public; the rules (one value, one home: the same constant name with the
  same value typed in two files; the shard id only in Core;
  every message has a sender; combat asked only of Combat; "paused" asked only of
  Trimmer:Paused (the saved key read only there and in the pause setting's own get and
  apply); a macro in a panel handed over as a macro block, never painted by the
  caller; no pass-through module; every
  widget type used); Blizzard's names (no deprecated call, every global proven, every
  reach into Blizzard's frames listed); ARCHITECTURE.md regenerated; the libraries'
  drift from upstream (information, never a failure). A regenerated map that changed in
  a way the commit did not intend means something moved that should not have. Stop and
  report.
- What is in the options window is a fact, not a reading of the code. The check opens the
  real window outside the game (tests/window.lua) and holds it to
  tests/window_controls.txt. Anything that says what a player sees or clicks there (a
  test card, a README line, a comment, a reply in chat) names only controls that file
  lists as shown. A name in the code is not evidence: SSFFrame once called its
  Keybindings button "closebutton", and a test card sent the tester looking for Close.
  When a change to the window is meant, accept the new list with
  `python tools/check.py --accept-window` and read its diff. The list cannot say where a
  control sits or how it looks; that takes a look in game or a screenshot.
- The check is itself checked. tools/selftest.py breaks one thing at a time on purpose and
  fails unless the check catches it for the expected reason. At the desk, run it after a
  change to tools\ or tests\, in the background (about 20 seconds: it runs the cases in
  parallel in copies of the addon outside this folder, so the folder the game loads is
  never broken). Any other change gets the check alone: GitHub runs the self-test on every
  push, and a release is tagged only on a green run (addon-release skill), so a case left
  behind by a code edit is still caught before anything ships. A case finds its break by
  the exact text it changes, so a code edit can leave a case pointing at text that is gone
  ("SETUP WRONG"), and the case is followed to the new text in the same commit. A new step in
  the check gets a case there in the same commit: a step nobody has seen fail proves
  nothing.
- One chunk of work per commit. Any commit that changes behavior is tested in game
  before the next; say which tests, each command in its own paste block, and wait.
- Never tag, bump or publish without an explicit yes.

## What ALL PASS does not cover

The check is static and Lua has no types, so some things only a test or a reader can
hold. Each was weighed and left out on purpose; none is an oversight to patch around.

- Arguments, returns and message payloads. Public, Sends and the map compare names only:
  reorder a payload or change what a method returns and every listener still passes the
  check. A regex cannot count Lua arguments soundly (varargs, optional arguments, a call
  built at run time). The tests hold a payload where a scene depends on it. So a change
  to a payload or a return is followed to every listener the map names, and their tests
  read.
- Library internals read off an object a library hands back (an AceGUI widget's frame or
  label, a status table). The check follows a library object a file keeps from LibStub,
  not the values it returns, because nothing static can tell which local holds a
  library's object. Those reads are listed by hand under Lib internals, and a library
  bump is read against every such line (Rule 1).
- The same number under two names. One value, one home is the same constant name with
  the same value in two files. Every number shared between two names today means two
  different things (pixel gaps, library versions, a debug window's height and the main
  window's width), so a rule on the number alone would flag only coincidences.
- Whether the check ran before a commit. There is no pre-commit hook: hooks are not
  versioned, so one would not reach the next session. GitHub runs the check and the
  self-test on every push, and a release tags only a commit GitHub passed. Locally, a
  failed pull of the client's UI source says "offline, using the copy on disk" and checks
  against that copy; GitHub always clones the current one.
- How the window looks and where a control sits: the window list names what is there
  (tests/window_controls.txt), never where. That takes a screenshot or a look in game.
