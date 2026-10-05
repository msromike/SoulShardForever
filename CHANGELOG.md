# Changelog

## 1.1.1 (2026-10-04)

- Same code as 1.1.0, repackaged. The 1.1.0 tag never reached CurseForge.

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
