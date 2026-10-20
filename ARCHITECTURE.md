# Soul Shards Forever: architecture map

One line per file and one row per message. Written by hand on 2026-10-20 from the file
headers; from chunk 0.03 on it is regenerated from the headers by the check script and
must not be edited by hand. If a file or message is missing here, its header is missing
the line that says so.

## Files, in load order

Widgets (custom AceGUI widgets, used from the options table through dialogControl):

- Widgets\SSFStepperSlider.lua: the stock Slider with - and + buttons framing the value box.
- Widgets\SSFWindow.lua: the options window container (currently a copy of AceGUI's Frame; being rebuilt as an extension of it).
- Widgets\SSFCentered.lua: five stock widgets repositioned: count button, centered label, centered checkbox, unlabeled dropdown, indented checkbox.

Core and modules:

- Core.lua: the addon object, the warlock gate, the AceDB profile, the language switch, the class color.
- Modules\Bags.lua: read-only bag queries and the one sort order every module uses.
- Modules\Cap.lua: what the cap is right now, and the low mark in use.
- Modules\Sorter.lua: one pass moving shards into free soul bag slots.
- Modules\Sounds.lua: SSF's sounds in LibSharedMedia and playing one by name.
- Modules\Trimmer.lua: the press: delete one shard over the cap, then one sort pass.
- Modules\DeleteButton.lua: the global button SSFDelete that /click targets.
- Modules\Settings.lua: turns one setting definition into its GUI entry and its chat command.
- Modules\Options.lua: the one settings table and the /ssf command.
- Modules\Status.lua: the chat status lines and when they print at login.
- Modules\Macros.lua: the two recommended macros: text, existence, creation, opening the macro window on them.
- Modules\MacroGlow.lua: glow on SSF's macros in Blizzard's macro window until they are on a bar.
- Modules\DeleteHelp.lua: the text that teaches every way to delete a shard.
- Modules\Window.lua: SSF's options window: open, feed, refresh, dress.
- Modules\Welcome.lua: the first-load welcome note beside the window.
- Modules\Broker.lua: the LibDataBroker object and the minimap icon.
- Modules\Counter.lua: the shard count drawn on one bag button.
- Modules\LowGlow.lua: glow on that bag button while the count is below the low mark.

Locales: Locales\Register.lua registers the seven AceLocale tables (enUS, deDE, frFR,
esMX, esES via esMX, ptBR, ruRU) and keeps the list the Language option shows.

## Messages (AceEvent, prefix SSF_)

| Message | Sender | Listeners | Payload |
|---|---|---|---|
| SSF_CAP_CHANGED | Cap | Counter, Broker | cap |
| SSF_SHARD_DELETED | Trimmer | Counter, Broker, LowGlow, Window | count, cap |
| SSF_OPTIONS_CHANGED | Options, Settings | Counter, Broker, LowGlow, Window | key, source ("chat" or nil) |
| SSF_OPTIONS_REBUILT | Options | Window | |
| SSF_SORTED | Sorter | none | moves |
| SSF_MACROS_CHANGED | Macros | Window | |
| SSF_MACRO_WINDOW_SHOWN | Macros | MacroGlow | |
| SSF_SHOW_WELCOME | Window | Welcome | |
| SSF_WINDOW_OPENED | Window | Welcome | |

Known gap (fixed by chunk 3.18): LowGlow does not listen to SSF_CAP_CHANGED, so a cap
dropped below the low mark leaves the glow stale until the next bag change.

## Game events, by module

| Module | Events |
|---|---|
| Cap | PLAYER_ENTERING_WORLD; bucket BAG_UPDATE, BAG_CONTAINER_UPDATE |
| Sorter | bucket BAG_UPDATE, BAG_CONTAINER_UPDATE |
| Counter | bucket BAG_UPDATE, BAG_CONTAINER_UPDATE |
| LowGlow | bucket BAG_UPDATE, BAG_CONTAINER_UPDATE |
| Window | bucket BAG_UPDATE, BAG_CONTAINER_UPDATE; PLAYER_REGEN_DISABLED |
| Broker | bucket BAG_UPDATE (drifted: missing BAG_CONTAINER_UPDATE; chunk 3.10) |
| Status | PLAYER_ENTERING_WORLD; BAG_UPDATE_DELAYED (first login) |
| Macros | bucket UPDATE_MACROS; LOADING_SCREEN_DISABLED (after its own reload) |
| MacroGlow | ACTIONBAR_SLOT_CHANGED (while a macro glows) |
| Welcome | LOADING_SCREEN_DISABLED (while a note is owed) |

Chunk 3.10 replaces the six bag buckets with one in Bags that sends SSF_BAGS_CHANGED.

## Shared state

- The AceDB profile (SSF.db.profile) is the one shared state. Any module may read it.
  Only the module that owns a rule derives it: the low mark in use is Cap:LowMark(),
  not min(profile.lowMark, cap) written again.
- NS, the addon-private namespace every file receives, carries the locale tables and
  the shared constants Core sets (SSF.SHARD_ITEM_ID, SSF.ICON on the addon object).

## Raw-frame exceptions (the only three)

- DeleteButton: a named CreateFrame, because /click resolves a global name.
- Counter: a FontString on a Blizzard bag button, because nothing in Ace draws there.
- Window: the title strip behind each option group, because AceConfigDialog hardcodes
  the InlineGroup widget.
