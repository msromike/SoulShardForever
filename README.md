# Soul Shards Forever (SSF)

**\*\*\* Changelog \*\*\***

1.10.0: Guided onboarding that knows your level: before Drain Soul, SSF stays quiet, and the welcome comes back when you learn it. A brighter yellow over the cap, a truer red when low, and the number on a darkened bag. The welcome shows once more after this update.

1.9.0: Low shard warn stops at your cap: the slider dims the track past the cap, with a gold line where the cap sits. A red border on the bag button when you're low, a smaller count, and the count alone on data broker bars. Delete Shard greys out when a click can't delete, and says why. The window closes itself when a fight starts.

1.8.1: Delete Shard sits beside your shard count. A minimap tooltip that always shows your count, cap, low mark and pause. "SSF paused: Yes / No" everywhere, and an easier welcome screen.

[..] [Full changelog](https://github.com/msromike/SoulShardForever/blob/main/CHANGELOG.md)

---

- **NEW: Guided onboarding that knows your level: before Drain Soul, SSF stays quiet; learn it, and the welcome walks you through setup.**
- **NEW: Low shard warn stops at your cap: the slider shows the cap in gold and dims the track past it.**
- **NEW: Shard count on data broker bars (Titan Panel, EllesmereUI's data bars and the like).**
- **NEW: Delete Shard sits right beside your shard count at the top of the window.**
- **NEW: The minimap tooltip shows your count, cap, low mark and pause, every time.**
- **NEW: One click makes the recommended macros: Create macros, at the bottom left of the window.**
- **NEW: In-game tooltip help: click the "i" in the window.**
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

  Life Tap never puts you in combat. The Bane one deletes on the move: with no target it
  doesn't cast, but the delete still fires. Don't use it with an enemy targeted, or you're
  in combat before the delete fires.

  Or let SSF make both: click **Create macros** at the bottom left of the window (it shows
  while either is missing), then **Create recommended macros**. SSF makes them as SSF_LT
  and SSF_BoA, reloads your UI, and opens the macro window with them glowing until you
  drag them onto a bar.

- **The Delete Shard button** in the GUI window, right beside your shard count. When a click can't delete, it's greyed out with the reason under it: At cap, Under cap, SSF paused or No Drain Soul yet. The window closes itself when a fight starts and opens again only after it.

Every press deletes first if you're over the cap: the shard nearest the backpack goes, so loose shards go before your soul bag's. Then it moves loose shards into free slots in your soul bag, bottom slots first. No soul bag, or a full one? Nothing moves. Nothing else in your bags is touched unless in SoulSort Mode.

- **Pause all SSF actions** stops every press from moving or deleting, for when you want to stockpile shards (raid night: soulstones, healthstones, summons). Your cap stays as it is. While paused the count goes white everywhere and the bag button's red border stays off: you're stockpiling on purpose, so no red and no yellow until you unpause. **Colorize bag count** and **Glow bag button when low** grey out and keep their ticks. **Play pause sound** plays a soft bag thunk on every paused press, at the volume you pick. **Log pause to chat** prints a line to chat as well. In combat a press does nothing, paused or not.
- **Shards to keep** is the cap, 1 to 100. Use the slider or use the − and + to fine tune.
- **Match soul bag size** ties the cap to your soul bag's slot count while one is equipped (all of them, if you carry more than one), and writes that number into Shards to keep, so unticking it leaves the cap at the bag size.
- **Low shard warn** is your low mark, 1 to 100. Below it the shard count turns red and the bag button gets a red border. It can't go above the cap: the slider stops there, the track past the cap is dimmed with a gold line where the cap sits, and if the cap drops under your mark, the mark follows it down and stays. Same slider and − and + as the cap.
- **Show shard count on bag bar** is on by default. It puts the number on your far-left bag. Green in range, yellow over the cap, red when you're low, white while paused or before you learn Drain Soul. Pick the font, or turn the colors off on the bag (the window, tooltip and chat keep them).
- **Glow bag button when low**, under the count, puts a red running border on the bag button while you're under the low mark, so you remember to farm shards before you run out. It shows only while the count shows. **Show on soul bag when equipped** is on by default too: the number sits on your soul bag instead, in whatever slot it's in. Untick it to keep the number on your far-left bag.
- **How shards move** is SSF Mode by default: shards move into your soul bag, and nothing else in your bags moves. **SoulSort Normal** and **SoulSort Reverse** sort the way Anilusion's SoulSort does, moving your other items aside so the shards sit in one solid block, from the top down or the bottom up. A soul bag still fills first. With help on, its tooltip describes each choice.
- **Announce deletions in chat** is off by default. Turn it on to see a chat line for each deleted shard, or for addons that watch chat (like MSBT).
- **Language** is Auto by default, which follows your game client. Pick English, Deutsch, Français, Español, Português or Русский to override it.

The gold "i" next to the window's X turns tooltip help on: hover any option, Delete Shard or Keybindings to see what it does. It turns blue while on, and it's off again after a /reload. The first time a character loads SSF, the window opens with help already on and a welcome screen beside it: every way to delete, and a button that makes the two macros. You see it once per character, and once more when a new version changes it. Create macros brings it back. Before you learn Drain Soul, SSF stays quiet: the count is white and the welcome says so; learn the spell, and the welcome comes back once, when shards start dropping.

The minimap icon opens and closes the window. Its tooltip always shows the count in its color, your cap, your low shard warn and whether SSF is paused. On a data broker bar (Titan Panel, EllesmereUI's data bars and the like) SSF shows the count alone in its color, with the same tooltip and click. Settings are per character.

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
