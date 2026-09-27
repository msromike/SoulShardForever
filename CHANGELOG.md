# Changelog

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
