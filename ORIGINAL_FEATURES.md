# SoulSort v1.5 (Anilusion): feature inventory

Taken from the source in `SoulSort_v1.5.zip` (`SoulSort.lua`, `SoulSort_Options.lua`).
Pick the rows you want in SSF.

## GUI (Interface Options > AddOns > SoulSort)

| # | Control | Label in the panel | Saved setting | Notes |
|---|---|---|---|---|
| G1 | Slider 0–100 | Max Soul Shards | `MaxShards` | 0 shows as "Infinite". Applies as you drag. Greyed out while G2 is on. |
| G2 | Checkbox | Automatic | `AutoMax` | Tooltip: "Fills your Soul Bag(s) or your last bag." Sets the cap to the total slots of all soul bags, or the last bag's slots if you have no soul bag. |
| G3 | Checkbox | Show Total Soul Shard count on Bag Bar | `ShowCounter` | Total shard count drawn on the last bag button. |
| G4 | Checkbox | Show Soul Shard count for non-Soul Bags | `ShowCounterPerBag` | Per-bag count drawn on the backpack and each non-soul bag button. Default on. |
| G5 | Checkbox | Fill bags from bottom to top | `SortReverse` | Sort fills the last slots of the last bag first instead of the first slots. |
| G6 | Checkbox | Show information about your Soul Shards in chat when sorting | `ShowSortInfo` | Prints "N Soul Shards deleted." after a sort that deleted any. |
| G7 | Checkbox | Disable warning when trying to sort Soul Shards in combat | `ShowCombatWarning` (inverted) | Warning text: "Cannot sort shards while in combat!" |
| G8 | Button | Sort Now | | Same as `/ss sort`. |
| G9 | Text | title, version, author, description | | |

No GUI control exists for AutoSort (slash only, S3).

## Slash commands (`/soulsort` or `/ss`)

| # | Command | Does | Notes |
|---|---|---|---|
| S0 | `/ss` | Prints the command list | |
| S1 | `/ss sort` | Deletes shards over the cap, then moves every shard to the back of the bags (or front, with G5) | Refuses in combat with the G7 warning. On Classic only one shard is deleted per press (hardware-event limit); the rest moves regardless. |
| S2 | `/ss max N` | Sets the cap; 0 = infinite | Turns AutoMax (G2) off. Bad or missing number prints usage plus the current cap. |
| S3 | `/ss autosort on/off` | Sets the "sort when leaving combat" flag | **Dead feature**: the flag is saved but nothing reads it and the combat-end event is never handled. Classic clients only. |
| S4 | `/ss automax on/off` | Same as G2 | Recomputes the cap immediately when turned on. |
| S5 | `/ss counter on/off` (also `count`) | Same as G3 | |
| S6 | `/ss reverse on/off` | Same as G5 | |
| S7 | `/ss combatwarning on/off` | Same as G7 (not inverted) | |
| S8 | `/ss showinfo on/off` | Same as G6 | |
| S9 | `/ss options` (also `settings`, `opt`) | Opens the options panel | |

No slash command exists for the per-bag counter (G4, GUI only).

## Behaviors with no control

| # | Behavior | Notes |
|---|---|---|
| B1 | LibDataBroker data source "SoulSort" | Text "Shards: N", red N when zero, " (Full)" when at the cap. Click opens the options panel. No minimap button of its own. |
| B2 | Counter refresh on every `BAG_UPDATE` | Counter text updates as you loot or move shards. |
| B3 | Soul bag detection by bag name | A bag counts as a soul bag if its name contains "Soul", "Felcloth" or "D'Sak's". |
| B4 | Shard = item ID 6265, bags 0–4 only | Bank is never touched. |
| B5 | Delete order | Scans bag 4 → 0, last slot first, KEEPS the first `MaxShards` shards it meets and deletes the rest. So the survivors are at the back of the bags and the deletions come from the backpack side. (Corrected 2026-09-27; the earlier note here had it backwards.) |
| B6 | Settings are per character | `SavedVariablesPerCharacter`. |
