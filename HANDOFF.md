# SSF: "SoulSort legacy method" setting

Code for the earlier "Fill backpack first" checkbox is in the working tree,
uncommitted, and gets reworked into this setting. Its test 1 (command and
checkbox) passed in game.

## Settled

- One toggle, off by default: SoulSort's legacy sort, on or off. It replaces
  "Fill backpack first", which is dropped. No other sort options: SSF's own
  sort stays the default, and SoulSort users switch to the behavior they
  know with one checkbox.
- Why: of the shard addons checked (SoulSort, DeleteSoulShard,
  SoulShardCapper), only SoulSort sorts, and it swaps shards with other
  items, with no option for it (SoulSort.lua:13-21 settings,
  SoulSort.lua:252-257 sort). No addon checked fills from the backpack.
- SoulSort has one sort option, `SortReverse` ("Fill bags from bottom to
  top"): slot order inside each bag. So the legacy setting is a checkbox
  plus a Normal / Reverse dropdown under it, covering every SoulSort state.
  The dropdown is greyed and blank until the checkbox is ticked. SSF's own
  sort is left alone.
- First entries in Other settings, above Announce deletions in chat.
- README credits SoulSort by Anilusion at this setting, in the same voice as
  the existing homage lines.

## Behavior

- **Off** (SSF, unchanged): soul bags, then bag 4 down to the backpack,
  bottom slot first inside each bag. Free slots only; non-shard items never
  move.
- **On** (SoulSort legacy): bag 4 down to the backpack. Normal: top slot
  first inside each bag (`SortReverse = false`). Reverse: bottom slot first
  (`SortReverse = true`, the same order as Off). Shards take every slot
  along that order, free or occupied; an item in the way swaps into the
  shard's old slot. Shards also move inside a bag.

- Label and command: "SoulSort legacy method", `/ssf soulsort on|off`.
- The Normal / Reverse dropdown is GUI-only, like Font and Language.
- Soul bags under On: fill first, as in Off. SoulSort itself ignored bag
  families.
- Special bags (herb, enchanting) under On: skipped, as in Off.
- Delete under On: SSF's rule, one shard per press from the far end of the
  order (Trimmer unchanged). SoulSort deleted in batches, keeping the first
  N shards met scanning bag 4 to 0, bottom slot first.

## Work

1. `Modules/Bags.lua`: revert the bag-direction change; bag order is bag 4
   to the backpack in every mode. `ForEachSlot` and `LastShard` take a
   `topFirst` flag (legacy on and Normal): top slot first inside regular
   bags when set. Bags reads no settings. Header sort-order paragraph covers
   every mode.
2. `Modules/Sorter.lua`: under `legacy`, targets are every non-shard,
   unlocked slot (free or occupied), and a shard pairs with a target that is
   earlier in the slot order, not only in an earlier bag. Snapshot planning,
   reruns and SSF_SORTED unchanged. Header states the swap.
3. `Modules/Trimmer.lua`: pass `topFirst` to `LastShard`. Sorter passes
   `topFirst` to `ForEachSlot` and uses `legacy` for the swap.
4. `Core.lua` defaults: rename `backpackFirst` to `soulsortLegacy`, default
   false; add `soulsortReverse`, default false.
5. `Modules/Options.lua`: rename the Define call to `soulsort`, keep its
   placement. Add a GUI-only select under it (Normal / Reverse), built like
   the Font dropdown: `disabled` while the checkbox is off, and `get`
   returns nil then so it shows blank. Other orders shift down one.
6. `Locales/*.lua` (every locale file): replace the two backpack-first
   strings with the new label and chat description.
7. README: options entry, commands row, sort paragraph, SoulSort credit.
8. CHANGELOG and toc version as one unit, after the in-game test passes
   and Mike says yes.

## Status

Done: 1.3.0, committed, not tagged. Every in-game step below passed: SSF
default fill and delete, legacy Normal, legacy Reverse, chat redraw.

Rides along in the same version: a chat command now redraws an open
window (Settings tags its SSF_OPTIONS_CHANGED with "chat"; Options
refreshes only on that tag, so slider drags never redraw).

## Test in game

One session, six steps, one at a time. Setup: cap above the shard count;
shards spread over bag 3 and the backpack; a non-shard item in one of bag
4's top slots.

1. `/ssf soulsort` naked: OFF. `/ssf options`: checkbox unticked, the
   SoulSort fill order dropdown greyed and blank.
2. `/ssf soulsort on`: ON. Reopen options: checkbox ticked, dropdown live,
   showing Normal.
3. Press once (Normal): shards fill bag 4 from its top-left; the item in
   the way swaps into a shard's old slot. Screenshot.
4. Dropdown to Reverse, press once: shards repack toward the bottom slots.
   Screenshot.
5. Cap one below the count, press once: the far-end shard is deleted (the
   top-most shard in the backpack-most bag that has one).
6. `/ssf soulsort off`, press once: no non-shard item moves; the dropdown
   greys and blanks again. Covers the default path.

Not tested, with the reason:

- Soul bag fills first: soul bags keep their walk in every mode, and a soul
  bag never holds a swappable item.
