# SSF 1.1.0 plan

Status 2026-10-04: code written, T1 through T10 plus the auto cap test passed in game.
Shipping. Found during tests and fixed: the announce line read the bags right after the
delete and showed the old count; it now prints the count the Trimmer knows. Unexplained,
not reproduced: once, after unequipping the pouch with auto ticked, the slider read 61
with auto still ticked. The only write path to the slider value unticks auto, so the
likely sequence is a stray slider change while the pouch was out, then re-tick. Watch for
it. The how-we-got-here notes are in
`.docs/HANDOFF_log.md`; nobody needs them to execute this.

## What is wrong

A soul bag on Forever (Small Soul Pouch, 14 slots) equips in the reagent bag
slot, bag 5. SSF scans bags 0-4 only (`Modules/Bags.lua`, `LAST_BAG = 4`).
So with a pouch: shards in it are not counted, it is never detected as a
soul bag, and the cap and delete work from the wrong count. Broken for every
pouch user since 1.0.0.

## What 1.1.0 does

One command, `/ssf delete` (key binding, macro line, window button). Out of
combat it:

1. **Sorts.** Moves every shard into the first free slot it can, in this
   order: soul bags, then bag 4, 3, 2, 1, then the backpack. Inside a bag,
   bottom slot first. Only into free slots; other items are never moved;
   shards already in the right bag stay put. A locked slot is skipped and
   the sort re-runs on the next bag update until nothing is left to move.
   Nothing runs in combat; nothing is queued; the next press out of combat
   finishes it.
2. **Deletes one shard** if the count is over the cap: the shard furthest
   along that order (backpack first, then bag 1, 2, 3, 4, then soul bags;
   top-most shard in a bag). Always the same spot after a sort.

In combat the press does nothing (as today).

Other rules:

- **One number**, the total shard count, on bag position four
  (`CharacterBag3Slot`), bag or no bag in that slot. Backpack button only
  when the bag bar is collapsed. Colors and low glow unchanged.
- **Soul bag** = a bag whose family matches the Soul Shard's family, in any
  slot. An herb bag in the reagent slot is not one. Four pouches are four.
- **"Match soul bag size"**: default OFF. Greyed with no soul bag. When on,
  the slider greys and the cap is the total slots of all soul bags.
- No sort options. No separate sort command. No other defaults change.
- Sort code is written fresh from the Blizzard calls; nothing copied from
  Baganator.

## Facts (probe-confirmed 2026-10-02)

- `Enum.BagIndex.ReagentBag` = 5. Pouch: 14 slots, family 4.
  `C_Item.GetItemFamily(6265)` = 4. The existing family check is right.
- `CharacterReagentBag0Slot` is the pouch's button, 45x45, directly left of
  `CharacterBag3Slot` (45x45). `CharacterBag3Slot` carries no Blizzard text.
- Moves are `C_Container.PickupContainerItem(src)`,
  `C_Container.PickupContainerItem(dst)`, `ClearCursor()`; `C_Item.IsLocked`
  says whether to skip. Baganator does batches of these from timers and bag
  updates on this install, so moves need no key press.
- Delete is one per key press, needs a key press, reverts in combat
  (`.docs/BAG_API_NOTES.md`).

## Spikes (Mike, in game, before any code)

Need: pouch equipped, 20 shards, one free slot in the pouch (drag one out).

**Spike 3.** Paste. Expect: the shard goes back into the pouch, nothing left on
the cursor.

```
/run local C=C_Container local I,P=C.GetContainerItemID,C.PickupContainerItem for b=4,0,-1 do for s=C.GetContainerNumSlots(b),1,-1 do if I(b,s)==6265 then for t=1,14 do if not I(5,t) then P(b,s) P(5,t) ClearCursor() return end end end end end
```

**Spike 4.** Drag one shard out again. Two-line macro, press once (254 chars,
one under the limit; say if the box cuts it off). Expect: one shard deleted
AND one moved into the pouch, from the one press. SSF must think it is over
the cap: it still sees only bags 0-4, so with cap 6 a seventh shard outside
the pouch does it.

```
/ssf delete
/run local C=C_Container local I,P=C.GetContainerItemID,C.PickupContainerItem for b=4,0,-1 do for s=C.GetContainerNumSlots(b),1,-1 do if I(b,s)==6265 then for t=1,14 do if not I(5,t) then P(b,s) P(5,t) ClearCursor() return end end end end end
```

Results 2026-10-04: both passed. Spike 3: shard moved into the pouch, cursor
clean. Spike 4: one press printed "Deleted a Soul Shard. Soul Shards: 20
(cap 1)" and moved a shard into the pouch. Macro box took both lines.
Sorting by addon code and the one-per-press delete coexist in one hardware
event. Code is a go.

## Work list (on Mike's go; before/after shown per file; one file at a time)

| File | Change |
|---|---|
| `Modules/Bags.lua` | Scan 0 through `Enum.BagIndex.ReagentBag`. Add: bag walk in sort order, free-slot finder, "furthest shard" finder for delete. Header updated. |
| `Modules/Sorter.lua` (new) | One pass as described above. Re-run on bucketed `BAG_UPDATE` while moves remain. Never in combat. Sends `SSF_SORTED` when it moved something. Reads Bags only. |
| `Modules/Trimmer.lua` | `Delete()` = Sorter pass, then delete the furthest shard if over the cap. Uses the new finder; `deleteOrder` gone. |
| `Core.lua` | `autoMax` default false. Remove `deleteOrder`. |
| `Modules/Options.lua` | No change expected (checkbox already greys with no soul bag). |
| `Modules/Counter.lua` | No change unless T9 shows Blizzard hides the empty slot button; then anchor to the position without the `IsShown` check. |

Ace3 everywhere, one job per file, header contract, modules talk through
messages and public methods (memory: own-addon-standards).

## Tests (Mike, in game; no commit before "tested works")

| # | Do | Expect |
|---|---|---|
| T1 | Pouch full, look at the number and `/ssf` | Total includes the 14 in the pouch |
| T2 | `/ssf options` on a fresh character | "Match soul bag size" off, clickable; on: slider greyed, cap 14 |
| T3 | Two shards out of the pouch into regular bags, count over cap, press once | Both go back in; one regular-bag shard deleted; pouch full |
| T4 | Same, count under cap | Both go back in; nothing deleted |
| T5 | Pouch full, overflow in backpack and bag 1, bag 4 has room, press once | Overflow lands in bag 4, bottom slots; the backpack-side shard is the one deleted |
| T6 | Pouch full plus overflow, press repeatedly | One per press, stops at the cap, pouch stays full |
| T7 | Checkbox off, cap below 14, nothing outside the pouch, press | Shards leave the pouch down to the cap |
| T8 | `/reload` with pouch equipped | Count and cap right immediately |
| T9 | Press in combat; unequip the bag in position four | Nothing moves or deletes; number stays over the empty slot |
| T10 | Screenshot, number and low glow on | Number centered on position four, right color, glow draws |

## Ship

1. `SoulShardForever.toc` `## Version: 1.1.0` + `CHANGELOG.md` 1.1.0 entry,
   same step.
2. `README.md`: drop the "to be added" / "coming real soon" lines; say the
   press sorts then deletes.
3. `.docs/BAG_API_NOTES.md`: bag range, reagent slot, move calls marked tested.
4. Commit on `main`, lightweight tag `v1.1.0`, push main and the tag. The
   CurseForge webhook packages it. Mike re-pastes the README into CurseForge.

Each step on Mike's explicit go.
