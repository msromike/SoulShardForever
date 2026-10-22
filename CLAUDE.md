# Soul Shards Forever: the standard

This file is the contract for any AI session that edits this addon. The owner does not
write Lua; every line here is written and maintained by AI sessions that start with no
memory. The two rules below exist so that a session can change one thing by opening one
file and trusting APIs it already knows. Read ARCHITECTURE.md next: it maps every file to
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
- Any other published library that would replace a block is a suggestion for the owner,
  never something a session adds on its own.
- Custom AceGUI widgets (Widgets\) are extension-only: a widget wraps a stock AceGUI
  widget and adds to it. It never re-implements what the stock widget does. Where AceGUI
  has no base, the widget stands alone and stays small.
- Five documented exceptions, each explained in its own file header, and no others:
  DeleteButton's raw named frame (/click needs a global name), Counter's raw FontString
  and backing texture on a Blizzard bag button (nothing on the list draws on a foreign button), the title
  strip behind option groups in Window (AceConfigDialog hardcodes the group widget),
  the global name SSFFrame gives the stock Frame's frame (UISpecialFrames closes it
  on Escape; the stock Frame is unnamed and Escape has no other way in), and SSFFrame's
  copy of the stock Close click, used only when the stock button can't be found (else an
  AceGUI change would leave the window's X and Close dead).
- The stock Frame container is the window base: dialog-box art, resize disabled through
  its public EnableResize. Nothing styled like a different UI kit.
- Reading a library's internals (an AceGUI widget's label, frame or children, an
  AceConfigDialog field, AceDB's key for the character) is allowed only where no public
  API exists, only in Widgets\, the Window and Tooltip modules and Core's profile-key
  migration, and every such field is named in that file's header under "Lib internals"
  with what breaks when it moves. Libraries change only through a
  deliberate bump (below), so those lines can only break on a day someone tests them.

## Rule 2: one job per file

- One job per file. The file name is the retrieval key: a helper buried in a bigger file
  is invisible to the next session. "It only has one caller" is not a reason to keep a
  helper inline. One job is the test.
- Every file starts with the header contract, in this order, empty fields omitted:

      <Name>: what this file does, as the first paragraph (ARCHITECTURE.md reads it)
      Public:     methods other files may call, with their arguments and returns
      Listens:    events and SSF_* messages it handles
      Hooks:      what it hooks, through AceHook, and when the hook attaches
      Sends:      SSF_* messages it sends and their payload
      Lib internals: library fields it reads past the public API, and what breaks
      Reads:      which other modules' public methods, and which profile keys
      Saves:      which profile keys it writes
      Exceptions: anything that breaks Rule 1 or 2 on purpose, and why
      Then the line "Touches nothing else."

  The header is the test. Anything in a file the header does not describe is misplaced.
  A session may stop reading at the header and trust it.
- Modules talk only through AceEvent messages and public methods. No reaching into
  another module's tables or frames. The AceDB profile on the addon object is the one
  shared state and any module may read it; re-deriving another module's rule from it is
  a violation (ask that module).
- Before writing any helper, grep the addon for the thing it does. Most helpers already
  exist: bag queries are in Bags, thresholds in Cap, colors in Colors, chat and tooltip
  wording in Status, tooltips in Tooltip, the volume levels in Sounds. ARCHITECTURE.md lists
  the rest.
- A new job gets a new file, named for the job, with its header written before its code,
  and a line in ARCHITECTURE.md in the same commit.

## Libraries

Libs\ is committed and ships exactly as committed: .pkgmeta has no externals, so what was
tested is what the package holds. tools\externals.txt names each library's upstream; the
check script reports drift from it as information. A library changes only on purpose:
`python tools/sync_libs.py --apply`, an in-game pass, a commit of its own with a changelog
line. Never edit a file under Libs\ by hand. One exception: Libs\AceTab-3.0 carries a
local fix pending upstream, see tools/externals.txt. It is the only library edited by hand.

## Every commit

- Run the check script (luacheck, headless tests, locale completeness, regenerate
  ARCHITECTURE.md). A regenerated map that changed in a way the commit did not intend
  means something moved that should not have. Stop and report.
- One chunk of work per commit. The owner tests in game after any commit that changes
  behavior; say which tests, each command in its own paste block, and wait.
- Never tag, bump or publish without the owner's explicit yes.
