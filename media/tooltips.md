# SSF tooltips

The master list of every tooltip's text (English), in window order, then the minimap
tooltip and the welcome note. Kept in media/: on GitHub, never packaged. Items marked * are also the
chat command's help text in /ssf help. Shown only while help is on (the "i"), except the
"i" itself and the minimap tooltip. Plain sentences: the tooltip wraps them itself, no line
breaks, except where a list needs them (How shards move, the Delete Shard macros).

Rebuilt 2026-10-19 from the 1.8.0 code after the local .docs folder was lost; updated
2026-10-20 for 1.8.1 (Delete Shard to the top row, the glow under the counter, the minimap
tooltip, the welcome layout).

## Help button ("i")

### Help off

Help OFF: Click to show tooltip help when you hover over an option.

### Help on

Help ON: Click to hide tooltip help.

## Delete Shard * (top row, beside the count)

SSF deletes one Soul Shard when you're over the cap. Use the Delete Shard keybind, this button, a macro, or mix and match.

In a macro, put /ssf delete on the line before the ability:

    #showtooltip
    /ssf delete
    /cast Life Tap

    #showtooltip
    /ssf delete
    /cast Bane of Agony

The Bane macro lets you delete on the move when you don't want to use Life Tap. Make sure you're not targeting an enemy with the Bane macro, because it puts you in combat. SSF cannot delete a shard while in combat.

Built by DeleteHelp (Blocks, joined by Text) from this first paragraph; the macro text
comes from Macros (spell names by ID, 1454 and 980, in the player's language). Shown
through AceConfigDialog's option tooltip (Options' deletebutton). /ssf help keeps its own
older line: "Deletes one Soul Shard if you are over the cap. In a macro, put /ssf delete on
the line before the ability."

## Pause SSF

### Pause all SSF actions *

Pause stops SSF from moving or deleting shards until you unpause.

### Play pause sound

Each press while paused plays a sound.

### Volume (the pause sound's dropdown)

Sets how loud the pause sound is.

### Log pause to chat

Each press while paused prints a chat line.

## Soul shard cap

### Shards to keep *

Your shard cap. Shards over this number are deleted one per press.

### Match soul bag size

Sets cap automatically to the size of all soul bags (one or multiple).

## Soul shard warning

### Low shard warn

If shard count is lower than this, you will be notified with a red color change (and glow if enabled).

Never greyed: it sets where red starts everywhere.

## Soul shard counter

### Show shard count on bag bar

Shows your shard count on a bag button (soul bag by default, left bag slot otherwise).

### Glow bag button when low

The bag button glows while you are below "Low shard warn".

"Low shard warn" is filled in from its own label. First under Show shard count on bag bar,
greyed with it off (the glow needs the count).

### Colorize bag count

Red when below "Low shard warn," green in range, and yellow over the cap.

Each color word is drawn in its own color, the bag's shades (red ff4040, green 00ff00,
yellow ffd100); the color codes are in each translation.

### Show on soul bag when equipped

Moves the counter to your soul bag, whatever slot it's in.

### Bag counter font

The font used on the shard counter.

## Other settings

### Show minimap icon

Enables SSF minimap icon.

### Announce deletions in chat *

Writes a line to chat every time a shard is deleted.

### How shards move

    How a macro or keybind moves shards. Shards move to soul bag.

    • SSF Mode: SSF does not sort (does NOT change item positions in bags).

    • SoulSort Normal: Shards sort top down (CHANGES item positions in your bags).

    • SoulSort Reverse: Shards sort bottom up (CHANGES item positions in your bags).

SSF Mode's name is drawn green (the safe pick); the SoulSort names are gold.

### Language

Auto uses game client language.

## Bottom buttons

### Create macros (bottom left)

Shown only while SSF_LT or SSF_BoA is missing; opens the welcome note.

Opens the welcome screen to create the recommended macros.

### Keybindings (bottom right)

Opens WoW's key bindings menu to bind Delete Shard and Pause all SSF actions.

The two names are filled in from their own labels and drawn gold.

## Minimap tooltip (always, help on or off)

The same lines every time; labels grey, values as noted:

    Soul Shards Forever      warlock purple
    Soul Shards        13    red below warn / green in range / yellow over cap, always
    (blank line)             the count above, the settings below
    Soul shard cap     16    white
    Low shard warn      6    white, the setting as set
    SSF paused         No    green No / red Yes

## Welcome note (first load, once per welcome version per character; also from Create macros)

### Title (warlock purple)

Welcome to SSF

In panel order, top to bottom. The panel is 86% of the window's width.

### Body (gold)

Click for in-game tooltip help.

### Delete help (left-justified, each macro in its own box)

The Delete Shard block above, with its own first paragraph:

SSF deletes one Soul Shard when you're over the cap. Use the Delete Shard keybind, the Delete Shard button, a macro, or mix and match.

### Line above the button (two lines, the break is in the string; "reloads your UI" in green, the color code is in each translation)

Creates the macros, reloads your UI
and opens the macro box after the reload.

### Button (as wide as its text; greyed out while both macros exist)

Create recommended macros

### Gold line (last)

You won't see this welcome screen again on this character unless you click Create macros in the UI.

## Red error text (top of the screen)

No free macro slots. Delete a macro and try again.
