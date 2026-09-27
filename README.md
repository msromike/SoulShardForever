# Soul Shard Forever (SSF)

A Soul Shard cap for warlocks on WoW Forever. Set how many shards to keep; every press of
the delete command removes one shard over the cap. A count on your bag bar, a glow when
you're running low, and nothing else.

SSF runs only on WoW Forever (Interface 16001). For Classic Era and its variants, use
[SoulSort](https://www.curseforge.com/wow/addons/soulsort-easy-soul-shard-management) by Anilusion,
which SSF started from.

## Deleting shards

The game allows one item deletion per keypress or click, and none at all in combat (the
server puts the shard back when combat ends). So SSF deletes one shard per press, only when
you are over the cap, and does nothing in combat. Three ways to press:

- **A key binding.** Escape > Options > Key Bindings, find "Soul Shard Forever", bind a key
  to Delete Shard. No macro needed.
- **A macro line.** Put `/ssf delete` on the line before an ability you use often:

      /ssf delete
      /cast <ability>

  Every press of that macro trims one shard if you're over the cap. Not for abilities on the
  global cooldown.
- **The Delete Shard button** in the options window.

Keybind and macro addons that can `/click` a button but can't run slash commands can use
`/click SSFDelete`; it's the same action.

Shards in your regular bags are deleted before shards in a soul bag, so the soul bag stays
full and the loot space is what gets freed.

## The window

`/ssf options`, `/ssf settings`, or click the minimap button. Also under Interface Options >
AddOns.

- **Shards to keep**: the cap, 1 to 100. Slide roughly, then use the − and + buttons.
- **Match soul bag size**: while a soul bag is equipped, the cap is its slot count and the
  slider is greyed. Without one, the slider rules. On by default.
- **Show shard count on bag bar**: one number on the far-left bag button, sized to fit it.
  **Colorize** makes it grey at zero, green at or under the cap, yellow over. **Bag counter
  font** picks the face from your shared-media fonts.
- **Glow bag button when low**: the bag button glows while your count is under the **Low
  shard warn** mark, and stops when you're back over it. A glance says "farm shards".
- **Announce deletions in chat**: one chat line per deletion, off by default.
- **Minimap button**: its tooltip shows count and cap; any broker bar shows "N (cap M)".

## Commands

| Command | What it does |
|---|---|
| `/ssf` | Current count and cap, then this list |
| `/ssf delete` | Delete one shard if over the cap |
| `/ssf setmax` | Show the cap and the count in bags; `/ssf setmax N` sets the cap |
| `/ssf announce` | Show the announce setting; `/ssf announce on` or `off` sets it |
| `/ssf options` | Open the window (`/ssf settings` does the same) |

Tab completes the command words and `on`/`off`. Settings are per character.

## License

MIT, see [LICENSE](LICENSE).

SSF started as a fork of [SoulSort](https://www.curseforge.com/wow/addons/soulsort-easy-soul-shard-management)
by Anilusion and was rewritten from scratch; no original code remains.

Bundles Ace3, LibDBIcon, LibSharedMedia and LibCustomGlow (BSD-style and MIT), LibDataBroker
and LibStub. Each keeps its own license.
