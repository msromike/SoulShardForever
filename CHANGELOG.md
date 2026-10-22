# Changelog

## 1.10.0 (2026-10-22)

- Guided onboarding that knows your level. Before you learn Drain Soul, SSF stays quiet:
  the count is white, nothing colors or glows, Delete Shard is greyed with "No Drain Soul
  yet" under it and in its tooltip, and the welcome screen says you'll see it again at
  level 10. Learn the spell, and the welcome comes back once to walk you through setup,
  right when shards start dropping.
- The welcome screen shows once more after this update, one last time.
- The count over the cap is a brighter yellow, and the low count a truer red, everywhere
  they show: the bag button, the window, the minimap tooltip and chat. The bag's picture
  is darkened under the number, so the count reads on a light bag.
- While paused, the count is white everywhere and the bag button's red border is off.
- The gold line that marks the cap on the Low shard warn slider is taller and runs a
  little below the track, so it's easier to spot. Typing a number past the cap into that
  box stops at the cap, like the thumb does. A greyed slider still shows its help tooltip.
- Under the hood: every color, size and wording lives in one place and the check script
  fails when one is typed twice; libraries updated to upstream; comments swept so they say
  what the code does. Nothing you see changed because of it.

## 1.9.0 (2026-10-21)

- Low shard warn stops at your cap. The part of its track past the cap is dimmed, with a
  gold line where the cap sits, and the thumb can't go past it. When the cap drops under
  your warn mark, the mark follows it down where you can see it, and stays there when the
  cap goes back up. Match soul bag size now writes the bag size into Shards to keep, so
  unticking it leaves the cap at the bag size instead of jumping back to an old number.
- The low glow on the bag button is a red running border on the button's own edge, the
  same red as the count. The game's gold spell glow it replaces spilled onto the bags
  beside it.
- The count on the bag button is smaller, with the bag showing around it. Before, it
  filled the button edge to edge and the digits ran together.
- Broker bars (Titan Panel, EllesmereUI's data bars and the like) show the count alone,
  in its color. Before it read "32 (cap 42)", with "Full" at the cap. The cap and the
  rest are in the tooltip.
- Delete Shard's tooltip says why it's grey: "Nothing to delete, SSF is paused." or
  "Nothing to delete, you are at or under the cap."
- The Keybindings button follows SSF's Language setting, like everything else in the
  window.
- The window is a touch darker, so its text reads better over bright ground.
- Your settings carry over the game's change to how it names characters. Without this,
  the update could show the welcome screen again and start you from the defaults.
- Under the hood: rebuilt on Ace3 end to end, one job per file with a header contract on
  each, duplicate code folded into single owners, custom widgets only as extensions of
  stock AceGUI ones, headless tests and luacheck on every push, libraries vendored and
  shipped inside the addon. Nothing you see changed because of it.
- Delete Shard greys out whenever a click can't delete, with the reason under it in gold:
  At cap, Under cap or SSF paused. Before, a click that couldn't delete did nothing, which
  looked like a broken button. While paused it always says SSF paused.
- The window closes by itself when a fight starts, and can't be opened until the fight is
  over. It doesn't reopen by itself afterwards.
- The welcome screen counts as seen only when you close it yourself, outside a fight. If a
  fight closes it, it comes back the next time the window opens, or at your next login or
  reload.

## 1.8.1 (2026-10-20)

- The welcome screen shows once more after this update, to show what moved. It was redone,
  and Delete Shard now sits at the top of the window.
- The name reads Soul Shards Forever everywhere, matching CurseForge: the window, the
  options panel, the minimap tooltip, the login line, the key bindings section and the
  AddOns list. Your settings, key bindings and enabled state carry over.
- Minimap tooltip: the same lines every time. Your shard count in its color (red below
  Low shard warn, green in range, yellow over the cap), then your settings: Soul shard
  cap, Low shard warn and SSF paused. The count is colored here even with Colorize bag
  count off, so the tooltip shows what the bag colors mean. The Over by line is gone.
- Pause reads one way everywhere: "SSF paused: Yes" in red while paused, "No" in green
  while running. /ssf pause, the pause key binding, a bare /ssf and the login lines all
  show it. Before, /ssf pause on answered "ON" in green.
- The window's top line shows only your shard count: the cap is the Shards to keep box
  right below it. The count's color shows what a cap or Low shard warn change does.
- Colorize bag count now applies only to the number on your bag. Everywhere else (the
  window, the minimap tooltip, chat) the count is always colored.
- Glow bag button when low moved to Soul shard counter, first under Show shard count on
  bag bar. It is part of the bag count now: with the count off, the bag no longer glows.
  Low shard warn can always be changed, even with the glow off: it sets where the count
  turns red everywhere.
- Welcome screen, easier to read: narrower, with more room at the sides. The help pointer
  is in gold, the opening says what SSF does first, and each macro sits in its own box.
  What the button does is above the button, with "reloads your UI" in green, the button
  is sized to its text, and the "won't see this again" line is last. Delete Shard's help
  tooltip opens the same way. The Bane macro's warning now says why: it puts you in combat,
  and SSF cannot delete a shard while in combat.
- Delete Shard moved from the bottom left of the window to the top, right beside your
  shard count: click it and watch the number drop. Create macros takes its place at the
  bottom left.
- Colorize bag count's help tooltip shows red, green and yellow in their own colors, the
  same shades as on the bag.
- How shards move's help tooltip shows SSF Mode in green, the safe pick that moves nothing
  else in your bags. The SoulSort choices stay gold.
- All new text in all six languages.

## 1.8.0 (2026-10-19)

- Delete Shard's help tooltip teaches every way to delete: your keybind, the button, or a
  macro. It shows two macros, /ssf delete before Life Tap and before Bane of Agony, and
  when to use the Bane one (on the move, with no enemy targeted).
- New welcome screen: the same text, and a Create recommended macros button. Players
  updating from 1.7 see it once.
- Create recommended macros makes the two macros (SSF_LT and SSF_BoA) in your
  character's macros, or in your account's if the character's are full, then reloads your
  UI and opens Blizzard's macro window on them. The reload is there because the game shows
  a brand-new macro with the wrong icon until one. Each macro not yet on a bar glows until
  you drag it onto one. With no free slots, a red message says so and nothing is made.
- Create macros: a button at the bottom of the SSF window while either macro is missing.
  It opens the welcome screen. Rename a macro and SSF counts it as missing.
- In combat the macro buttons do nothing.
- All new text in all six languages. Help tooltips keep their blank lines in every
  language.

## 1.7.0 (2026-10-19)

- In-game help: the gold "i" next to the window's X turns tooltip help on and off. While
  it is on (the "i" turns blue), hovering any option, Delete Shard or Keybindings shows
  what it does; Delete Shard's tip carries a sample macro. Off by default, and a /reload
  turns it off again.
- First-load welcome: the first time a character loads SSF, the window opens by itself
  with help on and a short note beside it pointing at the "i". You see it once per
  character, and players updating from 1.6 see it once too.
- The window's width now fits its contents in every language: no section title is cut
  short with "..." any more.
- How shards move: the always-on tooltips on its three choices are gone. With help on,
  the option's own tooltip describes all three.
- `/ssf help`: the cap, pause, announce and delete lines use the new tooltip wording.
- Russian: the Full volume level reads "Полная" (was "Макс.").

## 1.6.1 (2026-10-19)

- New defaults: Shards to keep is 8 (was 20), Show shard count on bag bar and Show on soul
  bag when equipped are on, and Play pause sound is off. A new install shows the colored
  count on your soul bag, or on your far-left bag without one, right away.
- These apply to you too wherever your setting was still the old default. If your Shards
  to keep was 20, it is now 8, and your next presses delete shards down to 8; set it back
  in the options window to keep more.

## 1.6.0 (2026-10-18)

- How shards move: one selector in Other settings replaces Use legacy SoulSort method and
  Legacy SoulSort fill order. Pick SSF Mode (the default), SoulSort Normal or SoulSort
  Reverse; hover a choice for a short description. Your setting carries over.
- SSF Mode moves shards only into free slots in your soul bag. Without a soul bag, or with
  a full one, nothing moves, and nothing else in your bags ever moves. Shards are no longer
  gathered into bag 4, and loose shards are deleted before your soul bag's. For one solid
  block, pick SoulSort Normal or Reverse.
- Fixed: a press over the cap always deletes a shard now, even when shards also need to
  move. Before, that press only moved them and the delete waited for a later press.
- `/ssf` opens the options window as well as printing the status. It only opens: an open
  window stays open. The minimap icon still opens and closes it.
- `/ssf soulsort` is gone. The mode is set in the options window.
- Options window: the section titles no longer flicker when you click a setting.
- Language: Auto always reads "Auto", like the language names, so you can find your way
  back from a language you can't read.
- Show minimap button is now Show minimap icon. All six languages updated.

## 1.5.1 (2026-10-17)

- Options window: three section titles renamed so the shard groups line up. Pause is now
  Pause SSF, Low shard glow is now Soul shard warning, and Shard bag counter is now Soul
  shard counter. All six languages updated.

## 1.5.0 (2026-10-16)

- Pause all SSF actions: a new Pause group at the top of the options window, `/ssf pause
  on|off`, and its own key binding. While paused a press neither sorts nor deletes, and
  the cap stays as it is. Play pause sound plays a soft bag thunk on every paused press,
  at Full, Loud, Medium or Quiet volume. Log pause to chat prints a line instead, or as
  well. In combat a press still does nothing.
- `/ssf` shows the pause state and the count. `/ssf help` (or `/ssf ?`) lists the
  commands. A mistyped command says so and lists them. The same two status lines print
  at login and reload.
- Options window: the two sliders sit together with their checkboxes under them, the
  section titles are larger and in the warlock color, every label lines up on the left,
  and several labels are clearer (Show minimap button, Use legacy SoulSort method,
  Legacy SoulSort fill order, Shard bag counter).
- Low shard warn goes up to 100, the same range as the cap, for warlocks who carry a lot of
  shards. While the cap is lower than it (Match soul bag size with a small pouch), the cap
  is used as the low mark, so the count and the glow always agree. Your setting comes back
  when the cap goes back up.
- The window remembers where you put it, never grows taller than the screen (it scrolls
  instead), and can't be dragged out of reach. The minimap button opens and closes it.
- The window's Close button is now Keybindings: it opens Blizzard's key binding page right
  at SSF's section, already expanded. The X and Escape still close the window.

## 1.4.0 (2026-10-16)

- Show on soul bag when equipped: a new tick under "Show shard count on bag bar". With it
  on, the count sits on your soul bag in whatever slot it's in, bag 1 to 4 or the reagent
  slot, and goes back to bag 4 when no soul bag is equipped. The low shard glow moves with
  it. Off by default.
- While the count sits on a soul bag, the game's own number on that bag button is hidden,
  so only one number shows. Any other bag in the reagent slot keeps the game's number.

## 1.3.1 (2026-10-12)

- A reagent bag in the reagent bag slot no longer causes "Only Reagents can be placed in
  Reagent Bags" errors. SSF took it for a regular bag and tried to sort shards into it on
  every press, and again on bag changes right after one (buying, selling, moving items).
  Shards now go to bag 4, 3, 2, 1, then the backpack, as 1.1.0 intended; the reagent slot
  is used only when a soul pouch is in it.

## 1.3.0 (2026-10-05)

- SoulSort legacy method (Other settings, `/ssf soulsort on|off`), off by default. Sorts
  the way SoulSort does: shards take every slot in order and an item in the way swaps
  into the shard's old slot. A dropdown picks SoulSort's Normal (top to bottom) or
  Reverse (bottom to top). A soul bag still fills first.
- A chat command now updates the options window while it is open.

## 1.2.1 (2026-10-05)

- Brazilian Portuguese and Russian, with Blizzard's own terms (Estilhaço de Alma, Осколок
  души).
- The Spanish (Spain) client now gets Spanish. Before, it fell back to English.
- Language setting: Português and Русский added to the list.

## 1.2.0 (2026-10-05)

- German, French and Latin American Spanish. SSF follows the client language; Blizzard's
  own terms (Seelensplitter, Fragment d'âme, Fragmento de alma) throughout.
- Language setting under Other settings: Auto, English, Deutsch, Français, Español. Takes
  effect at once; the Interface Options category name follows after a reload.
- The options window sizes itself to its content, so it never shows a scrollbar. A label
  too long for its row wraps and the row grows. The Delete Shard and Close buttons size to
  their text, and Close is translated.

## 1.1.1 (2026-10-04)

- Same code as 1.1.0, repackaged after the 1.1.0 tag was pushed twice.

## 1.1.0 (2026-10-04)

- Soul bags work. On Forever a soul pouch equips in the reagent bag slot, which SSF did
  not scan; its shards were not counted and it was never seen as a soul bag. Every count,
  the cap and the delete now cover all bags, backpack through the reagent slot.
- Every press sorts first: each shard outside a soul bag moves into a free soul bag slot,
  then into free slots in bag 4, 3, 2, 1, then the backpack; bottom slots first. Only free
  slots are used; nothing else in your bags is touched. Then, if you are over the cap, one
  shard is deleted: the top-most shard in the bag nearest the backpack, which after a sort
  is always the same spot. Nothing moves or deletes in combat.
- "Match soul bag size" is off by default and, when on, the cap is the slot total of every
  equipped soul bag.
- The chat line after a delete showed the count before the delete; it now shows the count
  after.
- Removed the hidden `deleteOrder` setting; the delete spot follows the sort order.

## 1.0.1 (2026-09-28)

- Non-warlock characters no longer get Lua errors from SSF at login ("attempt to index
  field 'db'" in Cap, Broker, Counter and LowGlow). The warlock check now switches off
  every module too, so on other classes SSF sets up nothing: no `/ssf`, no Interface
  Options entry, no minimap button, no `SSFDelete` button.

## 1.0.0 (2026-09-27)

Initial release. WoW Forever only.

- Soul Shard cap: one shard over the cap deleted per press, never in combat.
- Three ways to press: a Blizzard key binding (Delete Shard), `/ssf delete` in a macro, or
  the Delete Shard button. `/click SSFDelete` for keybind addons.
- Shards in regular bags are deleted before shards in a soul bag.
- Match soul bag size: the cap follows an equipped soul bag's slot count.
- Shard count on the far-left bag button: green in range, yellow over the cap, red when low;
  font from LibSharedMedia; colors can be turned off.
- Bag button glows while the count is under the low mark.
- Minimap button and LibDataBroker text ("N (cap M)", "Full" at the cap).
- `/ssf` commands with Tab completion; stateful commands report when typed naked.
- Optional chat line per deletion.
- Settings are per character.

Soul bag handling is built but not yet verified on Forever; 1.1.0 follows once it is.
