# Handoff: SSF 1.6.0 (SSF mode + one shard-mode selector)

Status: plan approved by Mike, nothing built yet. Build on his "build" or "go".
Before tagging: this file is not in `.pkgmeta`'s ignore list, so it would ship in the
CurseForge zip. Delete it or add it to the ignore list.

## Why

CurseForge comments (https://www.curseforge.com/wow/addons/soul-shards-forever-ssf/comments):
pickadoll asked, *"is sorting necessary or can I trigger deletion of excess shards without
sorting somehow?"* Mike replied that it doesn't sort unless legacy mode is on, that it moves
shards into the soul bag, and that with the defaults nothing else in the bags changes.

The code (1.5.1) does a bit more than that reply says. In default mode every press runs a
Sorter pass before the delete. That pass carries shards into empty slots along soul bag →
bag 4 → 3 → 2 → 1 → backpack, so even with no soul bag a backpack shard moves to bag 4.
Other items never move. There is no way to delete without the move except Pause, which stops
deleting too.

Players who keep pots and bandages in fixed spots in Blizzard's bags read "sorts" as
"rearranges my bags" and walk away. Bag-addon users (Baganator, BetterBags, Bagnon) gain
nothing from the gather. The CurseForge description says "sorts your shards into your soul
bag (if equipped)" and never promises that other items stay put.

Outcome: default mode moves shards only into a soul bag. Without one, SSF never moves
anything. Legacy SoulSort stays for anyone who wants the block. The legacy checkbox and
fill-order dropdown become one three-position selector. No new setting.

## Settled

- **SSF mode** (default): delete over the cap, and move shards only into empty soul bag
  slots. With no soul bag, nothing moves.
- **SoulSort Normal / Reverse**: legacy behavior, unchanged.
- Choice labels are short: "SSF mode", "SoulSort Normal", "SoulSort Reverse". The default
  carries the addon's name, so newcomers read it as the intended setting and leave it. The
  per-choice hover tooltip carries all the explanation.
- Legacy choices use SoulSort's own words: Normal and Reverse.
- One player-facing name for legacy: "SoulSort mode" (pairs with "SSF mode") in chat, the
  description, the summary and the README. Internal names (`soulsortLegacy`) and past
  CHANGELOG entries stay.
- Selector label: "How shards move". Read with the selected choice, it makes a sentence.
- Selector stays in Other settings, in the slot of the current checkbox and dropdown pair,
  defaulting to SSF mode.
- No saved-variables conversion. The selector reads and writes the existing
  `soulsortLegacy` and `soulsortReverse` (defaults in `Core.lua:34-35` already give SSF
  mode). Legacy users stay on legacy.
- `/ssf soulsort on|off` stays as is: on = legacy in the last picked order.
- No gather-into-bag-4 option. Anyone who wants shards in one block uses SoulSort mode.

## Code changes

1. **`Modules/Sorter.lua:51`**: non-legacy targets become free slots in soul bags only:
   `elseif legacy and (Bags:IsFreeAt(bag, slot) or Bags:IsSwappableAt(bag, slot))
    or (not legacy and Bags:IsSoulBag(bag) and Bags:IsFreeAt(bag, slot)) then`
   Reuses `Bags:IsSoulBag` (`Bags.lua:64`). Pairing loop and rank logic are unchanged.
   Header lines 3-8 are rewritten: default mode moves shards into free soul bag slots only.
2. **`Modules/Options.lua`**:
   - Stop placing `soulsortGui` in `other.args` (line 357). Keep `Settings:Define("soulsort")`
     for `soulsortCmd` (line 423), which the chat command still needs.
   - `soulsortorder` (lines 360-381) becomes `shardmode`: label `L["How shards move"]`, values
     `ssf / normal / reverse`, sorting `{ "ssf", "normal", "reverse" }`, no `disabled`.
     Labels: ssf → "SSF mode", normal → "SoulSort Normal", reverse → "SoulSort Reverse".
     get: `not legacy → "ssf"`, else `reverse and "reverse" or "normal"`.
     set: `soulsortLegacy = value ~= "ssf"`. For normal/reverse, also set `soulsortReverse`.
     For ssf, leave it, so `/ssf soulsort on` brings back the last order. `changed("shardmode")`.
   - Comments: lines 15-16, line 21, line 154 (Other order), lines 358-359. Also
     `Trimmer.lua:10-11` and `Core.lua:37` ("sorts" → "moves").
3. **`Modules/Trimmer.lua:3-6`** and **`Modules/Bags.lua:127-130`**: drop "after a sort
   this is always the same spot". In SSF mode the delete takes the top-most shard in the
   backpack-most bag holding one, so loose shards go first and a soul bag's last.
4. **Per-choice hover tooltip** (new file `Widgets/SSFDropdownItemTip.lua`, added to the toc
   after the other widgets): a dropdown item widget that otherwise works like AceGUI's
   `Dropdown-Item-Toggle` (`Libs/AceGUI-3.0/widgets/AceGUIWidget-DropDown-Items.lua:325-380`).
   AceGUI's Dropdown gives each item `userdata.value` (`AceGUIWidget-DropDown.lua:565-569`), and
   AceConfigDialog passes the custom item type through `itemControl`
   (`AceConfigDialog-3.0.lua:1277`). On OnEnter the item shows GameTooltip anchored
   `ANCHOR_RIGHT` to itself. The text comes from `option.arg[userdata.value]`, read
   through the parent dropdown's `option` user data. On OnLeave the tooltip hides.
   Use `arg`, not a custom key: AceConfigRegistry rejects unknown option keys
   (`AceConfigRegistry-3.0.lua:238-241`), which would break the window and every `/ssf`
   command, `/ssf delete` macros included. `arg` accepts any value (line 93).
   `shardmode` sets `itemControl = "SSFDropdownItemTip"` and `arg`:
   - ssf → "Shards go into empty slots in your soul bag. Nothing else in your bags moves.
     Without a soul bag, nothing moves."
   - normal → "Shards collect into one block from the top of your bags. Anything in the
     way swaps into the shard's old slot."
   - reverse → "Shards collect into one block from the bottom of your bags. Anything in
     the way swaps into the shard's old slot."
   The closed dropdown keeps `descStyle = "hidden"`, like every other control in the window.
5. **Locales (all six)**:
   - Remove `Legacy SoulSort fill order`, `Normal (top to bottom)`, `Reverse (bottom to top)`.
   - Add `How shards move`, the three choice labels from step 2, and the three tooltip strings
     from step 4.
   - Reword the pause description (not a tooltip: `Settings.lua:84` hides it in the window, so
     it only shows in `/ssf help`): "Stop every press from moving or deleting shards, until
     you turn it off."
   - Rename `Use legacy SoulSort method` to `SoulSort mode`. The chat command uses it as its
     name, so `/ssf soulsort` replies "SoulSort mode: ON" and `/ssf help` lists it that way.
     The desc string stays, because the chat command still uses it.

## Wording (after the in-game test passes)

- `media/curseforge.md`: line 41 →
  "Every keybind press or macro click deletes one shard if you're over the cap, and moves
  shards into your soul bag if there's space. No soul bag? Nothing moves. Nothing else in
  your bags moves, except in SoulSort mode."
  Line 53 → "SoulSort mode, if you prefer it. It moves other items aside, the way SoulSort
  did."
  Add to *Why this one*, as its last bullet: "SSF is bag safe. Impossible for it to delete anything but a
  Soul Shard." This is already true of 1.5.1 and isn't tied to the code changes, but it goes
  on the page only with this 1.6 description update. "Bag safe" means it never deletes
  anything else; moving items is a separate question, which the SoulSort line covers. The
  code behind it: the only `DeleteCursorItem` in the addon is `Modules/Trimmer.lua:52`,
  right after the item-ID check at lines 46-51. The Sorter picks up and drops items but
  never deletes. Re-check this before publishing if the delete path changes.
- `README.md` lines 17, 23, 31, 35, 51, 59, 71, 75: same promise, with no "sorts" for SSF
  mode, and "SoulSort mode" wherever it says legacy.
- `SoulShardForever.toc` Notes (all locales), `media/image_captions.txt` lines 8 and 23.
- CurseForge project summary (set in CF project settings, not in the repo). Replace only
  the fourth sentence. The full new summary:
  "Warlock Soul Shard manager for WoW Forever. Deletes shards over your cap with a keybind
  or macro. Shows number of shards on hand. Moves shards into your soul bag if equipped.
  Nothing else in your bags moves. SoulSort mode as an option. Multi-language support."
- CHANGELOG entry at release time. It says plainly that default-mode users no longer get
  shards gathered into bag 4: without a soul bag nothing moves, and with a full soul bag the
  overflow stays where it is (and is deleted first). SoulSort mode gives the block.

## Verification (in game, Mike)

1. No soul bag, SSF mode, shards spread across backpack and bag 2, bag 4 has free slots:
   press → nothing moves. Over the cap → top-most backpack shard deleted.
2. Soul bag with free slots, shards in regular bags: press → shards move into the soul bag,
   and no other item moves.
3. Full soul bag with extra shards in the backpack, over the cap: the backpack shard goes
   first.
4. SoulSort Normal and Reverse: same block and swaps as 1.5.1.
5. Open the selector and hover each line: the tooltip shows to the right with the matching
   text, and it hides when the mouse leaves the line or the list closes.
   Switch through all three modes. With the window open, `/ssf soulsort on` → the
   selector shows the last legacy order; `/ssf soulsort off` → SSF mode.
6. A profile that was on legacy before the update shows its legacy order after it.
7. `/ssf language deDE` (or another locale): selector labels and tooltips show translated.

Commit after "tested works". Release (1.6.0) only on an explicit yes.
