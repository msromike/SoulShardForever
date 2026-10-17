## <span style="color:#8788EE">Summary</span>

This addon helps you prune excess Warlock Soul Shards held in your bags in WoW Forever. Set the cap, tap a key (or macro), done. Works out of the box with minimal setup. Multi-language support.

## <span style="color:#8788EE">Description</span>

Keeps your Soul Shards at the cap you set, one press at a time. Never in combat (Blizzard limitation). Displays shard count, and can be paused.

## <span style="color:#8788EE">Why this one</span>

There are other shard addons. This one is built to disappear.

- Made for the Forever client, not ported to it.
- “It just works™.” Install it and the defaults get you going.
- One job: keep shards at your cap, a warning when you're low. Pause whenever you need. Nothing else.

## <span style="color:#8788EE">Feature set</span>

### <span style="color:#8788EE">Core features</span>

- Delete shards with a key or a macro.
- Display shard count on your bag bar or your soul bag (optional).
- Warn you when you're running low (red count, and the bag button can glow).
- Pause for raid night (farming shards for healthstones and summons duty).

### <span style="color:#8788EE">QOL features</span>

- Cap follows your soul bag size, if you want it.
- Speaks your language. Follows your game client, or pick English, Deutsch, Français, Español, Português or Русский.
- For those who lean that way, the everyday actions have slash commands too. Type `/ssf help` to see them, and Tab completes the command words.

## <span style="color:#8788EE">Set it up</span>

Click the SSF button on your minimap. Then:

- Set *Shards to keep*.
- Click Keybindings and bind *Delete Shard* and, if you want it, *Pause all SSF actions*.

## <span style="color:#8788EE">Keep shards at your cap</span>

Every keybind press or macro click sorts your shards into your soul bag (if equipped) and deletes one if you're over the cap.

- Put `/ssf delete` on the line above a spell you spam, and forget it.

  ```
  #showtooltip
  /ssf delete
  /cast Life Tap
  ```

- Or tap your keybind whenever.
- Set the cap slider or select use soul bag size(s) as cap: a 24-slot bag means a cap of 24, no slider.
- Legacy SoulSort layout, if that's what you prefer.

## <span style="color:#8788EE">See how many you have</span>

Displays shard count:

- On your bag bar, on your soul bag.
- Green in range, yellow over the cap, red when low.
- Glow the bag button when you're low.
- Your font, or no colors, or no count at all. Up to you.

## <span style="color:#8788EE">Pause for raid night</span>

When you're stockpiling for soulstones, healthstones and summons, SSF stops deleting.

- Pause and unpause with a key, or the checkbox in the window.
- A soft thunk and a chat line, if you want them, so you know it's paused.
- Your cap stays where it was when you resume SSF.

This is only for WoW Forever. On Classic Era use SoulSort by Anilusion, which the idea for SSF came from.

The code lives on [GitHub](https://github.com/msromike/SoulShardForever). Have a look, tell me what you'd change, or send a PR. Happy to hear from you.
