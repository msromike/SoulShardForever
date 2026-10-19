# Soul Shard Forever (SSF)

**\*\*\* Changelog \*\*\***

1.6.0: SSF Mode moves shards into your soul bag and nothing else. One selector for how shards move. `/ssf` opens the window.

1.5.1: Clearer section titles in the options window.

1.5.0: Option to pause all SSF actions, with an optional sound and chat line. UI rework and polish. Added button to open keybinds from GUI.

[..] [Full changelog](https://github.com/msromike/SoulShardForever/blob/main/CHANGELOG.md)

---

- **NEW: SSF Mode: shards move into your soul bag, and nothing else in your bags moves.**
- **NEW: Pause all SSF actions so you can stockpile for raid night.**
- **NEW: Shard count on your soul bag.**
- **NEW: SoulSort Mode.**
- **NEW: Language localization.**
- **NEW: Soul Bag support!**

## Description

A Warlock addon that keeps your Soul Shards at a cap you set. Each press of a key, a macro line or a button deletes one shard if you're over the cap and moves shards into your soul bag, but never in combat. It can show your shard count on the bag bar, color-coded, and glow the bag button when you're running low. A new feature is a pause so you can stockpile for an instance or summoning session without dragging your sliders around.

Why did I write it? I used SoulSort for a long time, but it's not ported to Forever. There are a handful of addons that do shard management, but they tend to be hard to configure or have features not related to the task at hand. So this addon is focused on one thing only: deleting soul shards and warning you when low.

This is for Forever only. I will not backport it because the original works well. On Classic Era use [SoulSort](https://www.curseforge.com/wow/addons/soulsort-easy-soul-shard-management) by Anilusion, which is the addon SSF started from.

## Using it

The game lets an addon destroy one item per keypress, and none in combat. SSF deletes one shard per event, but only when you're over the cap, and it does nothing while you're fighting. It always moves shards into your soul bag when out of combat and not paused, cap or not. Call it however you like:

- **A key.** Open the options window (`/ssf`, or the minimap icon) and click Keybindings. Bind Delete Shard, and Pause all SSF actions if you want it.
- **From chat.** `/ssf delete`
- **A macro.** On the line before an ability you spam. Every press trims one shard when you're over the cap, and moves shards into your soul bag.

  ```
  #showtooltip
  /ssf delete
  /cast Life Tap
  ```

  ```
  #showtooltip
  /ssf delete
  /cast Bane of Agony
  ```

- **The Delete Shard button** in the GUI window.

Every press deletes first if you're over the cap: the shard nearest the backpack goes, so loose shards go before your soul bag's. Then it moves loose shards into free slots in your soul bag, bottom slots first. No soul bag, or a full one? Nothing moves. Nothing else in your bags is touched unless in SoulSort Mode.

- **Pause all SSF actions** stops every press from moving or deleting, for when you want to stockpile shards (raid night: soulstones, healthstones, summons). Your cap stays as it is. **Play pause sound** plays a soft bag thunk on every paused press, at the volume you pick. **Log pause to chat** prints a line to chat as well. In combat a press does nothing, paused or not.
- **Shards to keep** is the cap, 1 to 100. Use the slider or use the − and + to fine tune.
- **Match soul bag size** ties the cap to your soul bag's slot count while one is equipped (all of them, if you carry more than one).
- **Low shard warn** is your low mark, 1 to 100. Below it the shard count turns red and the bag button can glow. If your cap is lower than this, the cap is used as the low mark until the cap goes back up. Same slider and − and + as the cap.
- **Glow bag button when low** lights the bag button while you're under the low mark, so you remember to farm shards before you run out.
- **Show shard count on bag bar** is off by default. It puts the number on your far-left bag. Green in range, yellow over the cap, red when you're low. Pick the font, or turn the colors off. Tick **Show on soul bag when equipped** and the number sits on your soul bag instead, in whatever slot it's in.
- **How shards move** is SSF Mode by default: shards move into your soul bag, and nothing else in your bags moves. **SoulSort Normal** and **SoulSort Reverse** sort the way Anilusion's SoulSort does, moving your other items aside so the shards sit in one solid block, from the top down or the bottom up. A soul bag still fills first. Hover a choice for a short description.
- **Announce deletions in chat** is off by default. Turn it on to see a chat line for each deleted shard, or for addons that watch chat (like MSBT).
- **Language** is Auto by default, which follows your game client. Pick English, Deutsch, Français, Español, Português or Русский to override it.

The minimap icon opens and closes the window. Its tooltip shows the count and the cap, and indicates paused status. Settings are per character.

## Commands

| Command | What it does |
|---|---|
| `/ssf` | Opens the options window, and shows pause state, count and cap |
| `/ssf help` | This list (`/ssf ?` does as well) |
| `/ssf delete` | Delete one shard if over the cap, then move shards |
| `/ssf pause on/off` | Pause all SSF actions. Naked shows status |
| `/ssf setmax N` | Set the cap, and turn off Match soul bag size. Naked shows cap |
| `/ssf announce on/off` | Chat line per deletion. Naked shows status |
| `/ssf options` | Opens the GUI window (`/ssf settings` does as well) |

Tab autocompletes the SSF commands in chat (try it, I hate typing). `/click SSFDelete` does the same as `/ssf delete` (for keybind addons that can't run slash commands).

## License

MIT, see [LICENSE](https://github.com/msromike/SoulShardForever/blob/main/LICENSE). Started as a fork of SoulSort by Anilusion, rewritten from scratch. No original code remains.

Bundles Ace3 (with CallbackHandler), AceGUI-3.0-SharedMediaWidgets, LibSharedMedia, LibCustomGlow, LibDataBroker, LibDBIcon and LibStub. Each keeps its own license.
