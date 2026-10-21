## <span style="color:#8788EE">Summary</span>

This addon helps you prune excess Warlock Soul Shards held in your bags in WoW Forever. Set the cap, tap a key (or macro), and done. Works out of the box with minimal setup. Doesn't sort shards in your bags unless you want it to. Multi-language support.

## <span style="color:#8788EE">Description</span>

Keeps your Soul Shards at the cap you set, one press at a time, but not in combat (Blizzard limitation). Displays shard count, and can be paused.

## <span style="color:#8788EE">Why this one</span>

There are other shard addons. This one is built to disappear.

- Made for the Forever client, not ported to it.
- “It just works™.” Install it and the defaults get you going.
- One job: keep shards at your cap, a warning when you're low. Pause whenever you need. Nothing else.
- SSF is bag safe. Impossible for it to delete anything but a Soul Shard.

## <span style="color:#8788EE">Feature set</span>

### <span style="color:#8788EE">Core features</span>

- Deletes shards with a key, a macro, or the UI button next to your count.
- Displays shard count on the bag bar, and offers some placement and appearance options.
- Warns you when you're running low (red count, and the bag button can glow).
- Offers a "pause" feature. Use it for raid night or whenever you need to farm shards for healthstones and summons duty.

### <span style="color:#8788EE">QOL features</span>

- Cap follows your soul bag size, if you want it.
- In-game help: click the "i" in the window, then hover any option to see what it does.
- Closes its window by itself when combat starts, so it's never in your way in a fight.
- Makes the recommended macros for you with one click, and shows you where they were created.
- For those who like CLI, SSF has slash commands too. Type `/ssf help` for the list. Tab can complete commands.
- Shows your count on a data broker bar (Titan Panel, EllesmereUI's data bars and the like), with your cap and settings in a tooltip.
- Speaks your language. Follows your game client, or pick English, Deutsch, Français, Español, Português or Русский.

## <span style="color:#8788EE">Set it up</span>

Click the SSF icon on the minimap (or type `/ssf`). Then:

- Set *Shards to keep*.
- Click *Keybindings*, bind *Delete Shard*, and bind *Pause all SSF actions* if you want.

## <span style="color:#8788EE">Keep shards at your cap</span>

Every keybind press or macro click deletes one shard if you're over the cap, and tucks loose shards into your soul bag. By default your other items never move around in your bags.

- In a macro put `/ssf delete` on a line above a spell you spam, and then forget about it.

  ```
  #showtooltip
  /ssf delete
  /cast Life Tap
  ```

- Or let SSF make it: click *Create macros* at the bottom of the window. It makes the Life Tap macro and a Bane of Agony macro, then opens your macro window so you can drag them onto your bars.
- Or tap your keybind whenever.
- Set the cap with the slider, or tick *Match soul bag size*: a 14-slot bag means a cap of 14.
- SoulSort Mode, if you prefer it. It sorts your bags the same way SoulSort does.

## <span style="color:#8788EE">See how many you have</span>

Displays shard count:

- On your bag bar or on your soul bag.
- Green in range, yellow over the cap, red when low.
- Glow the bag button when you're low.
- Your font, or no colors, or no count at all. Up to you.

## <span style="color:#8788EE">Pause for raid night</span>

When you're stockpiling for soulstones, healthstones and summons, SSF stops deleting.

- Pause and unpause with a key, or the checkbox in the window.
- A soft thunk and a chat line, if you want them, so you know it's paused.
- The count goes white, no red, no yellow, no border, until you unpause.
- Your cap stays where it was when you resume SSF.

This is only for WoW Forever. On Classic Era use SoulSort by Anilusion, which the idea for SSF came from.

The code lives on [GitHub](https://github.com/msromike/SoulShardForever). Have a look, tell me what you'd change, or send a PR. Happy to hear from you.
