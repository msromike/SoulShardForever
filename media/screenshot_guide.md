# SSF screenshot guide

How to take and crop each gallery shot, in gallery order. Same file names as
`image_captions.md`, which has the caption for each. A shot is retaken over the old file,
same name; a new one gets the next number. Every shot in the gallery was taken before the
1.8 window, so all of them are owed; 08 (Blizzard's keybinding page) only needs its section
name checked.

## Rules for every shot

- **One place, one light.** Stand in the same spot for every shot, somewhere with a plain,
  dark, still backdrop and no NPCs walking through: an inn wall, a dark cave mouth. The
  gallery reads as one set when the backdrop is the same in all of them.
- **Same UI scale as the old shots.** The window about 590 px wide in the final crop,
  tall, as 01 is now. Do not change UI scale between shots.
- **Nothing else on screen.** Chat frame scrolled clear (or hidden, except in 03), no
  nameplates, no other addon windows, no tooltips except the one the shot is about. Help
  ("i") off except where the shot shows a help tooltip.
- **Cursor out of frame**, except where it has to be over something (07, 10, 11).
- **Capture with Win+Shift+S**, region, at native resolution, saved as PNG. No scaling,
  no JPEG. Crop in the Snipping Tool or afterwards; never resize.
- **Crop rule for window shots** (01, 02, 04, 05, 06, 09): from 8 px above the window's
  top border to 8 px below the bag bar, 8 px either side of the window. The bag bar sits
  directly under the window, so the number on the bag and the slider that drives it are
  in one frame. Move the window so it sits right above the bag bar before you shoot.
- **Crop rule for small shots** (07, 10, 11): tight around the thing and its tooltip,
  12 px of air all round. Landscape is fine here.
- **Shoot in this order.** It walks the count and the cap through every state with the
  fewest changes. Start with more shards than your soul bag holds (bag 14, shards 19 is
  the set the old gallery used).

## 01_window_in_range_green.png (hero; CurseForge shows this one first)

Shows: the whole window, the count green, the warn slider stopping at the cap with the dim
track and the gold line, and the same number on the soul bag.

Set up: Match soul bag size off. Cap above your count, warn below it (cap 20, warn 16 with
19 shards). Pause off. Show shard count on bag bar on, Show on soul bag on.

```
/ssf setmax 20
```

Then drag Low shard warn to 16. Check: count green at the top, 19 green on the soul bag,
Low shard warn's track dim right of 20 with the gold line, Delete Shard greyed with "Under
cap" under it.

Crop: window rule.

## 02_pause_off.png

Shows: Pause all SSF actions unticked, Play pause sound and Log pause to chat greyed, the
rest as in 01.

Set up: same as 01. Make sure both pause options are ticked (they keep their tick while
greyed; that is the point of the shot).

Crop: window rule.

## 03_pause.png

Shows: paused, and what the player sees when they press: the chat line and the status
`/ssf` prints. This is the one shot that keeps the chat frame.

Set up: tick Pause all SSF actions, Play pause sound on, Log pause to chat on. Press your
Delete Shard key once so the chat shows the paused line, then:

```
/ssf
```

Check: count white at the top and on the bag, no border, "SSF paused: Yes" in red in
chat, Delete Shard greyed with "SSF paused" under it, Colorize bag count and Glow bag
button when low greyed with their ticks.

Crop: window rule, widened to the left to take in the chat frame with those lines, as the
old 03 does. Scroll the chat so only SSF's lines show.

## 04_match_soul_bag_over_cap.png

Shows: Match soul bag size ticked, Shards to keep greyed at the bag size, the warn thumb
pinned at the bag size on the gold line with the dim track past it, the count yellow.

Set up: untick Pause. Tick Match soul bag size. With a 14-slot bag and 19 shards the cap is
14 and the count goes yellow; Low shard warn drops to 14 by itself if it was above.

Check: Shards to keep box reads 14 and is greyed, Low shard warn thumb on the gold line at
14, count yellow at the top and on the bag, Delete Shard live.

Crop: window rule.

## 05_low_shard_glow.png

Shows: the low state. Count red at the top, red on the bag button with the red running
border round the button, Low shard warn visible above the count's line so the eye connects
the two.

Set up: untick Match soul bag size. Cap back above the count, then drag Low shard warn
above your count (cap 32, warn 24 with 19 shards). Glow bag button when low on.

```
/ssf setmax 32
```

Check: count red, red border on the soul bag button, no gold spell glow. Catch the border
with its segments spread round the button, not bunched in one corner: take two or three
and keep the best.

Crop: window rule.

## 06_language_menu.png

Shows: the Language dropdown open with all six choices.

Set up: as 01 (put the warn back under the count first, so the count is green). Click the
Language dropdown and leave it open.

Crop: window rule. The open list must be inside the crop.

## 07_minimap_tooltip.png

Shows: the minimap icon with its tooltip: the title, the count in its color, then Soul
shard cap, Low shard warn, SSF paused.

Set up: as 01. Hover the SSF minimap icon.

Crop: small rule: the minimap icon and the tooltip, nothing else of the minimap if you can
help it. Cursor on the icon is fine.

## 08_keybinding.png

Shows: Blizzard's keybinding page at the Soul Shards Forever section, Delete Shard bound,
Pause all SSF actions bound.

Set up: click Keybindings in the window. Scroll so the section heading is at the top.

Crop: the keybinding window, tight. Check the heading reads "Soul Shards Forever"; if it
does, the old shot is fine and this one can be skipped.

## 09_soul_bag_counter.png

Shows: Show on soul bag when equipped unticked: the count on the far-left bag, the soul bag
showing the game's own number again.

Set up: as 01, then untick Show on soul bag when equipped.

Crop: window rule. The far-left bag and the soul bag both in frame.

## 10_broker_bar.png (new)

Shows: the SSF block on a data broker bar, the count in its color, the tooltip open under
it. The bag bar in the same frame if the layout allows, so the two numbers match.

Set up: as 01. In EllesmereUI's data bar settings the SSF block's Strip Colors is off, so
the count shows green. Hover the block.

Crop: small rule, landscape: the bar from one block left of SSF to one block right, and
the whole tooltip. If the bag bar fits in the same crop without stretching it, include it.

## 11_delete_shard_greyed.png (new)

Shows: Delete Shard greyed with "At cap" under it, and the help tooltip saying why:
"Nothing to delete, you are at or under the cap."

Set up: cap equal to your count (19 shards, cap 19). Help on (the "i"). Hover Delete Shard.

```
/ssf setmax 19
```

Crop: small rule: the top of the window from the title to just under the count row, with
the tooltip. Cursor on the button is fine.

## After the shots

Save each over the old file (01 to 09) or under the new name (10, 11) in `media/`. Say
"done": the files are checked as new, committed with the captions, and pushed to GitHub
with no tag. Then paste each caption from `image_captions.md` into the gallery.
