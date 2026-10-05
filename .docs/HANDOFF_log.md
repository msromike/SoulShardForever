# SSF 1.1.0: soul bag fix, sort on delete, one number

Last updated: 2026-10-04. This file is the record. Every turn updates it:
settled items are closed here, new questions are added here, nothing open is
removed until Mike decides it. The earlier version of this file (per-bag
numbers, D1-D17) was replaced on 2026-10-04 by Mike's redirect (D18); the
IDs below keep their old numbers so the history stays greppable.

## QUESTIONS FOR MIKE (everything else in this file is record, not a question)

1. D14 CLOSED: no separate sort command. One command, /ssf delete: it sorts, it deletes.
2. D7 CLOSED: colorize and low glow stay on by default. Only the soul bag match defaults off.
3. D22 CLOSED: farming 20 shards (pouch 14 + 6). Mike went farming 2026-10-04.

Then: run spikes 3 and 4 (paste lines under "Unknown") and tell me what
happened. After that there is nothing left to ask; coding waits on your go.

## Start here (new session)

Mike says "start programming my SSF" or similar: read this whole file first,
then do the "Next action" below. Do not re-plan and do not re-derive what is
under Facts.

Where it stopped, 2026-10-04:

- No addon code has been changed. The SSF repo
  (`Interface\AddOns\SoulShardForever`) is clean at `cda7b7a` (v1.0.1), level
  with `origin/main`.
- Mike confirmed the redirect (D18): sort by default, one number, soul bags
  first, delete from non-soul bags first.
- Spikes 3 and 4 (below) have not been run, or their results have not been
  reported.
- Open decisions: none. All closed; see Settled and the closed D lines.
  the answer needed.

Next action:

1. Ask Mike for the results of spikes 3 and 4 and record them here.
2. (done) Every decision is closed.
   Problem / Options / Recommendation.
3. Only then, on his explicit go, start the work list: show before/after
   first, one file at a time.

Rules that apply (memory): own-addon-standards (Ace3, one job per file, header
contract), in-game-verification (no commit before "tested works", screenshot
for UI), own-addon-releases (toc + CHANGELOG together, lightweight tag),
turn-gate, plan-file-is-the-record, plusmouse-no-ai-agreement (Baganator was
read locally; S8 says copy nothing).

## Context

SSF 1.0.0 and 1.0.1 shipped with soul bag code that was never run against a
real soul bag and was left switched on. Mike's instruction was to keep it
disabled until tested. It is broken for anyone with a pouch: the shard count
ignores every shard in the pouch, the pouch is never detected as a soul bag,
and the cap and delete work from the wrong count.

Cause: Mike's Small Soul Pouch is equipped in the reagent bag slot (bag 5,
probe-confirmed), and SSF only scans the backpack and the four normal bag
slots (`Modules/Bags.lua` line 11, `FIRST_BAG, LAST_BAG = 0, 4`, re-checked
2026-10-02). The 0-4 range matches Classic Era SoulSort (B4 in
`.docs/ORIGINAL_FEATURES.md`); that SSF took it from there is inference.

Mike's redirect, 2026-10-04: the addon is meant to sort. It does not work
without sorting, and once it sorts, the per-bag display and everything it
dragged in (Blizzard's own numbers on the backpack and pouch, zeros, colors
per bag, which button glows) goes away.

## Facts from Mike's probes (2026-10-02, 14-slot pouch equipped and full)

| Bag | Slots | Free | Family |
|---|---|---|---|
| 0 | 20 | 0 | 0 |
| 1 | 10 | 0 | 0 |
| 2 | 8 | 5 | 0 |
| 3 | 8 | 8 | 0 |
| 4 | 8 | 5 | 0 |
| 5 (reagent slot) | 14 | 0 | 4 |

- `Enum.BagIndex.ReagentBag` is 5. `C_Item.GetItemFamily(6265)` is 4.
- Pouch family 4 matches shard family 4, so the family check in
  `Bags:IsSoulBag` is right. Only the scan range is wrong.
- Scanning bag 5 by item ID found all 14 shards.
- `CharacterReagentBag0Slot` exists and is shown, 45 x 45, directly left of
  `CharacterBag3Slot` (also 45 x 45). A test number drawn on the pouch button
  shows centered.
- Texts on the buttons (P0): the backpack carries Blizzard's free-slot total
  "(18)" for the backpack and four normal bags, reagent slot excluded
  (confirmed by Mike). The pouch button carries a Blizzard number "14"
  (`CharacterReagentBag0SlotCount`; slots or shards, untested, no longer
  matters). `CharacterBag3Slot` carries no Blizzard text, only SSF's own
  number.

## How Baganator sorts (read 2026-10-02 at Mike's request; it works on his install)

Files: `Baganator/Sorting/OrderBags.lua` (`ApplyBagOrdering`),
`Baganator/Sorting/BagUsageChecks.lua`, `Baganator/ItemViewCommon/Utilities.lua`
(`AddBagSortManager`), `Baganator/ItemViewCommon/BackpackView.lua` (`DoSort`).

1. One pass works out where every item should end up and builds a list of
   moves. Moves into empty slots first, swaps second.
2. A move is `C_Container.PickupContainerItem` on the source,
   `C_Container.PickupContainerItem` on the target, `ClearCursor()`. Every
   move in the list fires in the same pass.
3. A slot the server still has locked (`C_Item.IsLocked`) is skipped.
4. The pass reports moved / locked / waiting on item data / complete.
5. A manager re-runs the whole pass until complete: after the next bag update
   or a 1 second timer when something moved, every frame when something was
   locked. Each pass starts from the bags as they are then.
6. Nothing in combat or while dead ("Sorting breaks during combat due to
   Blizzard restrictions").
7. Special bags are decided by the same family match SSF uses; items that fit
   a special bag are placed there first.
8. Pickup sounds are muted for the length of a pass.

Evidence this gives (not yet run by us): a batch of moves in one go works
(U1); a move does not need a key press (U3); nothing stays on the cursor.

## Settled

- S3. "Match soul bag size" defaults off, and is greyed while no soul bag is
  equipped.
- S4. A soul bag is decided by family match only, never by slot. An herb bag
  in the reagent slot is not a soul bag (holds no shards, never a sort
  target). A soul pouch in a normal slot is a soul bag. Four pouches are four
  soul bags.
- S6. Auto mode ("Match soul bag size" ticked): the cap is the sum of the slot
  counts of every equipped soul bag. One 14-slot pouch = 14; four = 56. No
  soul bag = the slider value. `Cap:Get()` and `Bags:SoulBagSlots()` already
  do this; the sum must include the reagent slot.
- S8. SSF's sort is written fresh from the Blizzard calls Baganator uses; no
  Baganator code is copied. SSF is a published addon.
- S9 (D18, Mike, 2026-10-04). Sort by default. One number: the total shard
  count. Sort puts every shard into the soul bags first. Delete takes from
  the non-soul bags first. Sort is not an option; it is what the delete press
  does: out of combat, sort first, then delete one shard if the count is
  over the cap. Because the bags are sorted, delete looks for the first
  eligible shard and it is always in the same place. With a slider cap below
  the soul bag total, delete comes out of the soul bags once nothing is
  outside them.
- S11 (Mike, 2026-10-04). Sort order, no options: soul bags first, then bag
  4, bag 3, bag 2, bag 1, then the backpack, skipping any that does not
  exist or cannot hold shards (S4). Shards sort to the bags, not the backpack
  first. No "top of bag / bottom of bag" setting, ever.
- S12 (Mike, 2026-10-04, restating S3 and S6 as one). Auto mode is the
  "Match soul bag size" checkbox: with a soul bag equipped it greys the
  slider and the cap is the total of all soul bag slots; nothing else.
- S10 (Mike, 2026-10-04). The number stays where it is now: on bag position
  four, the far-left normal bag slot, bag or no bag in it. Drawn by position,
  not by bag. That is already how Counter works: it anchors to
  `CharacterBag3Slot` (`Modules/Counter.lua` line 48), which is the slot
  button, not the bag; the frame exists whether or not a bag is equipped.
  Today it falls back to the backpack button only when that slot button is
  not shown (collapsed bag bar). One thing to confirm in test T9: that
  Blizzard keeps the empty slot button shown on Forever's bar; if it hides
  it, Counter drops the `IsShown` check and anchors to the position anyway.
- Replaced by S9 and S10: S1 (per-bag numbers), S2 (display first, sort
  second), S7 (sort on delete as an option). Closed as no longer applicable:
  D3, D4, D5, D6, D8, D9 (one release), D10 (answered by S9), D11 (answered
  by S9), D12, D16, D17. Unknowns U4, U5, U6 no longer matter.

## Open (Mike decides; nothing here is written into code before he does)

- D7 CLOSED (Mike, 2026-10-04): no change; colorize and low glow stay on. Was: does "no defaults on for anything" also turn off the other defaults
  that are on today (colorize bag count, low glow)? Answer needed: only the

- D14 CLOSED (Mike, 2026-10-04): NO. One command. /ssf delete sorts, then deletes. No /ssf sort, no Sort binding. Was: is there also `/ssf sort` (and the Blizzard key binding row) for a
  sort without a delete? Proposal: yes, same code path minus the delete.

- D15 CLOSED (settled with D19, 2026-10-04): no sort in combat. Was: does the sort part of the press run in combat? Proposal: no; in
  combat the press does nothing, as today (Baganator's author found sorting
  breaks in combat).
- D19 CLOSED (Mike, 2026-10-04): re-run on the next bag update until nothing is left; in combat a run does nothing, nothing is queued or remembered, the next press out of combat finishes it. Was: after the press, the sort may have moves left (a locked slot, a
  shard still in flight). Proposal: the Sorter re-runs its pass on the next
  bag update, out of combat, until nothing is left to move, the way Baganator
  does; no timer, no frame loop.

- D20 CLOSED (Mike, 2026-10-04): reverse of the sort order; deleteOrder goes. Was: delete
  takes the shard furthest along the sort order (backpack side first, then
  bag 1, 2, 3, 4, then soul bags), so the one deleted is always the last one
  sorted in. This replaces the hidden `deleteOrder` profile value
  (`Core.lua`, "front" = backpack slot 1 outward), which becomes "reverse of
  the sort order" with no setting.
- D21 CLOSED (Mike, 2026-10-04): free slots only. Was: a shard moves only into a free
  slot of a bag earlier in the sort order; no swapping with other items, no
  shuffling within a bag.
- D23 CLOSED (Mike, 2026-10-04): bottom, as SoulSort did. Was: inside a
  bag, do shards fill from the top (slot 1, top-left of the bag window) or
  the bottom (last slot, bottom-right)? Proposal: the bottom, the last free
  slot first. Reasons: it is what SoulSort did by default ("moves every
  shard to the back of the bags", S1 in `.docs/ORIGINAL_FEATURES.md`), so
  it is what Mike's hands know; it keeps the top of each bag, where the eye
  lands, for other items; and with delete taking the reverse of the fill
  order (D20) the next shard to go is the highest one in the backpack-most
  bag, always the same spot.
- D22 CLOSED (Mike, 2026-10-04): 20. Was: shards to farm for the tests, pouch size plus six (20
  for the 14-slot pouch): enough overflow to see a sort across two regular
  bags and several deletes.

## Unknown, needs a spike before code

- U2. Whether a soul pouch can be equipped in a normal bag slot on Forever.
  The code path is the same either way; nothing blocks on it.
- Spike 3 (P1). With one free slot in the pouch, paste. Moves the last shard
  in the regular bags into the pouch's first free slot. Result: not run.
  `/run local C=C_Container local I,P=C.GetContainerItemID,C.PickupContainerItem for b=4,0,-1 do for s=C.GetContainerNumSlots(b),1,-1 do if I(b,s)==6265 then for t=1,14 do if not I(5,t) then P(b,s) P(5,t) ClearCursor() return end end end end end`
- Spike 4 (P3 core). A two-line macro pressed once, with one free slot in the
  pouch and SSF over its cap: line 1 `/ssf delete`, line 2 the spike 3 line.
  254 characters in total, one under the macro limit. Pass = one shard
  deleted and one moved into the pouch from the same press. Result: not run.
- Not run unless spike 3 or 4 surprises us: a move fired from a timer,
  several moves in one pass (Baganator's evidence covers both). The in-combat
  case is not run unless D15 is answered yes.

## Work list (only on Mike's go; before/after shown first, one file at a time)

1. `Modules/Bags.lua`: scan bags 0 through `Enum.BagIndex.ReagentBag`.
   `ForEachShard`, `Count`, `SoulBagSlots` and `PickVictim` all read the same
   range, so the count, detection, cap and delete order are fixed by this
   one change. Add the two queries the Sorter needs: stray shards (in
   non-soul bags) and free soul bag slots. Header contract updated.
2. `Modules/Sorter.lua` (new; one job): one pass walks the bags in sort
   order (S11); every shard that sits later in the order than a free slot is
   picked up, placed there, cursor cleared; locked slots skipped (D21). Never
   in combat. Re-run per D19. Sends `SSF_SORTED` when a pass moved something.
   Reads Bags only.
3. `Modules/Trimmer.lua`: the press becomes sort, then delete. `PickVictim`
   takes the shard furthest along the sort order (D20); `deleteOrder` goes.
4. `Modules/Options.lua`: "Match soul bag size" greyed
   with no soul bag (already so) and default off (S3) in `Core.lua`; other
   defaults per D7.
5. `Modules/Counter.lua`: no change unless T9 shows the empty slot button
   hidden (S10).

## In-game test (Mike), nothing committed before "tested works"

| # | Do | Expect |
|---|---|---|
| T1 | Pouch full, look at the number and `/ssf` | Number and `/ssf` show the total including the 14 in the pouch |
| T2 | `/ssf options` on a character that never touched the setting | "Match soul bag size" unticked, clickable; ticked: slider greyed, cap 14 |
| T3 | Pull two shards out of the pouch into regular bags, press delete once (count over the cap) | Both move back into the pouch; one shard from a regular bag is deleted; pouch full |
| T3b | Pouch full, overflow shards scattered in the backpack and bag 1, bag 4 has free slots, press delete once | Overflow shards move to bag 4 (then 3, 2, 1); the deleted one is the backpack-side one |
| T4 | Same, count under the cap | Both move back; nothing deleted |
| T5 | Pouch full plus extras in regular bags, press delete repeatedly | One regular-bag shard per press; stops at the cap; pouch still full |
| T6 | Untick, cap below 14, nothing outside the pouch, press delete | Shards leave the pouch down to the cap |
| T7 | `/reload` with the pouch equipped | Count and cap right straight away |
| T8 | Press delete in combat | Nothing moves, nothing deleted |
| T9 | Unequip the bag in position four | Number stays at position four over the empty slot |
| T10 | Screenshot of the bag bar with the number and low glow on | Number centered on position four, right color, glow draws |

## Wording, same step as the version bump

- `SoulShardForever.toc` `## Version: 1.1.0` and the `CHANGELOG.md` 1.1.0
  entry together: soul bag in the reagent slot counted, detected and capped;
  the press sorts shards into soul bags before deleting.
- `README.md`: drop the two "to be added" / "coming real soon" asides;
  describe sort on the press.
- `.docs/BAG_API_NOTES.md`: bag range, reagent slot facts, the probe values
  above and the move calls marked tested; remove "Not yet testable".
- CurseForge description is the README pasted by hand; Mike re-pastes it.

## Release (each step on Mike's explicit go)

1. Commit on `main`.
2. Lightweight tag `v1.1.0`.
3. `git push origin main`, `git push origin v1.1.0`. The CurseForge webhook
   packages from the tag.

## Done means

Spikes 3 and 4 reported; T1-T10 reported passing by
Mike; the T10 screenshot reviewed; `v1.1.0` on origin.
