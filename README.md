# SoulShard Sort Forever (SSF)

Soul Shard cap for warlocks on WoW Forever. Set how many shards to keep, put one line in
your macros, and every press deletes one shard over the cap. Nothing else.

SSF is a fork of [SoulSort](https://www.curseforge.com/wow/addons/soulsort-easy-soul-shard-management)
by Anilusion, rewritten for WoW Forever on Ace3. It runs only on Forever (Interface 16001).
For Classic Era and its variants, use the original.

## Using it

Put `/ssf delete` on the line before the ability in a macro:

    /ssf delete
    /cast <ability>

Each press is one hardware event, and the game allows one item deletion per hardware event,
so each press removes at most one shard, and only when you are over the cap. At or under the
cap the line does nothing. Not for abilities on the global cooldown.

Shards in your regular bags are deleted before shards in a soul bag, so the soul bag stays
full and the loot space is what gets freed.

## Options

Open with `/ssf options`, the minimap button, or Interface Options > AddOns.

- **Shards to keep**: the cap, 1 to 100.
- **Match soul bag size**: while a soul bag is equipped, the cap is its slot count. Without
  a soul bag the slider rules. On by default.
- **Show shard count on bag bar**: one number on the far-left bag button.
- **Announce deletions in chat**: one chat line per deletion, off by default.
- **Minimap button**.
- **Delete Shard** button: same as `/ssf delete`.

## Commands

| Command | What it does |
|---|---|
| `/ssf` | List the commands |
| `/ssf delete` | Delete one shard if over the cap |
| `/ssf setmax N` | Set the cap (turns off Match soul bag size) |
| `/ssf announce on/off` | Chat line per deletion |
| `/ssf options` | Open the options window |

Settings are per character.

## License

GPLv3, see [LICENSE](LICENSE). SoulSort is copyright Anilusion and released under GPLv3;
SSF is a modified version, first published 2026, and stays GPLv3.

Bundles Ace3 and LibDBIcon (BSD-style), LibDataBroker and LibStub. Each keeps its own license.
