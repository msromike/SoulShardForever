# SSF screenshot guide

The gallery sells; the README teaches. Five shots, one line each, in the order a cautious
player asks: what will I see, why do I care, will it be a pain. Same file names as
`image_captions.md`, which has the line for each. A shot is retaken over the old file,
same name. Decided 2026-10-22 with Amelia and Dustin, after 1.10.0 shipped; the old
eight-shot walkthrough is gone.

Two passes. **Pass one:** shoot and crop by hand, publish. **Pass two, whenever:** the
inset script (at the bottom) lays the bag bar into the window band from the same shot;
whichever reads better replaces the first, same names, same push.

## Rules for every shot

- **Set up once, before the first shot:** help off (the "i" gold), Language on Auto, a soul
  bag equipped, Pause off, Show shard count on bag bar on, Show on soul bag on. Drag the
  window down so it sits right above the bag bar; leave it there for every shot.
- **One place, one light.** Stand in the same spot for every shot, somewhere with a plain,
  dark, still backdrop and no NPCs walking through: an inn wall, a dark cave mouth. The
  gallery reads as one set when the backdrop is the same in all of them.
- **Same UI scale** for every shot.
- **Nothing else on screen.** Chat clear, no nameplates, no other addon windows, no tooltip
  except the one the shot is about.
- **Cursor out of frame**, except shot 5, where it has to be on the icon.
- **Capture with Win+Shift+S**, region, at native resolution, saved as PNG. No scaling, no
  JPEG. Crop in the Snipping Tool or afterwards; never resize.
- **Crop wide, never tall.** The window is a tall strip and a gallery thumbnail is a wide
  box. Each shot crops to the part that proves its line: the window's top band (title,
  count, Delete Shard, through the Soul shard cap box) plus the bag bar, never the whole
  window. 8 px of air all round. Landscape every time.
- **Shoot in this order.** It walks the count through green, yellow and red with the
  fewest changes. Start with more shards than your soul bag holds (bag 14, shards 19 is
  the set the old gallery used).

---

## Shot 1 of 5: `01_in_range.png` (hero; CurseForge shows this one first)

**Shows:** the count green at the top of the window, the same green number on the soul bag.

**Set up:** Match soul bag size off. Cap above your count, warn below it (cap 20, warn 16
with 19 shards).

```
/ssf setmax 20
```

Then drag Low shard warn to 16.

**Check:** count green at the top, 19 green on the soul bag, Delete Shard greyed with
"Under cap" under it.

**Crop:** wide. The window's top band through the Soul shard cap box, and the bag bar.

**Line:** Your shard count, on your bag, in one glance. Green means you're fine.

---

## Shot 2 of 5: `02_over_cap.png`

**Shows:** the count yellow at the top and on the bag, Match soul bag size ticked with the
cap at the bag size.

**Set up:** tick Match soul bag size. With a 14-slot bag and 19 shards the cap is 14 and
the count goes yellow.

**Check:** Shards to keep box reads 14 and is greyed, count yellow at the top and on the
bag, Delete Shard live.

**Crop:** wide, the same as shot 1.

**Line:** Yellow means you're carrying dead weight. One press deletes one, down to the cap
you set.

---

## Shot 3 of 5: `03_low.png`

**Shows:** the count red on the bag, with the red running border round the bag button.

**Set up:** untick Match soul bag size. Cap back above the count, then drag Low shard warn
above your count (cap 32, warn 24 with 19 shards). Glow bag button when low on.

```
/ssf setmax 32
```

**Check:** count red, red border on the soul bag button. Catch the border with its
segments spread round the button, not bunched in one corner: take two or three and keep
the best.

**Crop:** wide. The bag bar is the shot; the window's top band above it if it fits without
going tall.

**Line:** Red means go farm before the raid does it for you.

---

## Shot 4 of 5: `04_welcome.png`

**Shows:** the welcome note beside the window: the pointer at the "i", every way to
delete, the two macros in their boxes, the Create recommended macros button.

**Set up:** put Low shard warn back under the count first, so the count is green. Then
open the note:

```
/run LibStub("AceAddon-3.0"):GetAddon("SSF"):GetModule("Window"):SendMessage("SSF_SHOW_WELCOME")
```

**Check:** the note's title, the arrow and the "i", both macro boxes, "reloads your UI" in
green, the gold line last.

**Crop:** wide. The window's top third and the whole note beside it, down to the gold line
at the note's bottom. Close the note by its X afterwards.

**Line:** Install it and it walks you through: every way to delete, and the two macros made
for you with one click.

---

## Shot 5 of 5: `05_minimap.png`

**Shows:** the minimap icon with its tooltip: the title, the count in its color, then Soul
shard cap, Low shard warn, SSF paused.

**Set up:** as shot 1. Hover the SSF minimap icon.

**Check:** the count green in the tooltip, cap and warn in white, SSF paused a green No.

**Crop:** wide. The minimap and the tooltip, 12 px of air all round. Cursor on the icon is
fine.

**Line:** Count, cap, low mark, paused or not. Always there, never in your way.

---

## After the shots

Save the five into `media/` under the names above. Say "done": the files are checked as
new, the nine old gallery files are removed, the whole tree is committed and pushed to
GitHub with no tag (nothing rebuilds on CurseForge). Then paste each line from
`image_captions.md` into the gallery and replace the old images.

## Pass two: the inset

A Pillow script in this folder (beside `make_icon.py`): one full-screen shot per state in,
the window's top band with the bag bar laid into one corner out, thin border, the same
corner and size on every image. One source per shot, so scenery and light match. Shots 1
to 3 only; 4 and 5 have no bag in them. If the insets read better, they replace pass one's
files, same names, same push.
