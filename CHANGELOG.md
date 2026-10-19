# Changelog

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
