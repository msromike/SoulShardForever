# SSF: "Fill shards from" setting

Not started. No code changed.

## Spec

- Dropdown "Fill shards from", two choices for the regular bags:
  - **Last bag** (default, current behavior): bag 4 down to the backpack.
  - **Backpack**: backpack up to bag 4.
- A soul bag always fills first when one is equipped.
- Free slots only. Non-shard items never move.
- Delete takes the shard at the far end of the order (Trimmer unchanged).
- GUI only, no slash command (`Settings:Define` only does toggle and range).

## Work

1. `Modules/Bags.lua` `SortOrder()`: the regular-bag loop (line 76) runs
   either direction. Bags reads no settings, so the direction is passed in;
   `ForEachSlot` and `LastShard` carry it. Update the header's sort-order
   paragraph.
2. `Core.lua` defaults: new profile key, default = last bag.
3. `Modules/Options.lua`: a select under Other, built like Language (line 207).
4. `Locales/*.lua` (every locale file): label plus the two choices. esMX terms: bolsa,
   mochila.
5. README options list, CHANGELOG, toc version, as one unit.

## Test in game

- Last bag, no soul bag: identical to 1.2.0.
- Backpack: shards fill the backpack's free slots first; the delete removes
  from the bag 4 side.
- Soul bag equipped: fills first under both choices.
- Non-shard items never move.
