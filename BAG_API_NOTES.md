# Bag and item API notes for SSF on WoW Forever

Everything SSF needs from the Blizzard API, in one place. Forever runs the 12.x engine with
Interface 16001, so the retail-style namespaced API applies (`C_Container`, `C_Item`,
`C_AddOns`, the `Settings` panel API). Facts marked **tested** were confirmed in-game on this
install; the rest are documented API behavior to confirm during the chunk that first uses them.

## Which client this is

- `select(4, GetBuildInfo())` returns the interface build. Forever is `16000 <= build < 20000`.
  SSF does not branch on it (Forever-only addon), but it is the check to use if that ever changes.
- `UnitClassBase("player")` returns the class token, e.g. `"WARLOCK"`. **Tested**: the gate
  in `Core.lua` disables the addon on a druid with no trace.

## Bags

- Player bags are IDs 0 (backpack) through 4. Bank is never touched. `NUM_BAG_SLOTS` is 4.
- `C_Container.GetContainerNumSlots(bag)` → slot count. 0 for an empty bag slot.
- `C_Container.GetContainerItemID(bag, slot)` → item ID or nil. On this engine a value can be
  a **secret value** in restricted situations; treat anything that is not `type() == "number"`
  as "not a shard". Never compare or index with it.
- `C_Container.GetContainerNumFreeSlots(bag)` → `freeSlots, bagFamily`. `bagFamily` is a
  bitfield; 0 means a regular bag, nonzero means a special bag (soul, herb, enchanting, ...).
- `C_Container.GetBagName(bag)` → the bag's name. Not used for detection (localized text).

## Soul bag detection

- `C_Item.GetItemFamily(itemID)` → the item's family bitfield. For the Soul Shard (item 6265)
  this is the bit that soul bags accept.
- A bag is a soul bag when `bit.band(bagFamily, C_Item.GetItemFamily(6265)) ~= 0`. No
  hardcoded bit number, so it holds whatever value Forever assigns.
- Not yet testable: no soul bag is obtainable on Forever during the beta. The branch exists in
  `Modules\Bags.lua` and is verified in the deferred 1.1.0 stage.

## Fill order (client behavior, no addon involved)

- A newly created shard goes into an equipped soul bag first. Only when every soul bag is full
  does it land in a regular bag, in the first free slot counting from the backpack.
- Regular loot also fills the first free slot from the backpack.

## Picking up and deleting

- `ClearCursor()` drops whatever the cursor holds without destroying it. Call it before a
  pickup (so nothing else is on the cursor) and after a delete.
- `C_Container.PickupContainerItem(bag, slot)` puts the item on the cursor. Not protected;
  works in combat. **Tested** out of combat.
- `GetCursorInfo()` → `"item", itemID, itemLink` while an item is held. Confirm
  `itemID == 6265` before deleting. After a successful delete it returns nil.
- `DeleteCursorItem()` destroys the held item. Restrictions on this engine:
  - Requires a **hardware event**: the call must happen inside the handler of a real keypress
    or click. A timer, an event handler, or a `BAG_UPDATE` callback cannot delete.
  - **One delete per hardware event.** A loop deletes one item and the rest are ignored.
  - `noscript`: cannot be called from `/run` or `/script`. **Tested**: it CAN be called from an
    AceConsole slash handler (`/ssf ...`) and from a named Button's OnClick via
    `/click ButtonName`, both typed in chat and as the first line of a macro.
  - **In combat the delete is reverted by the server.** **Tested**: the shard leaves the bag
    on screen, then every shard comes back when combat ends ("You create: Soul Shard"). So
    `Delete()` checks `InCombatLockdown()` first and does nothing in combat.
- Items of Rare quality or better prompt a confirmation dialog; Soul Shards are Common, so no
  dialog.

## Macro and slash plumbing

- A macro keypress is one hardware event for every line in the macro.
- `/click ButtonName` runs that Button frame's OnClick as if clicked. The button must have a
  global name (`CreateFrame("Button", "SSFDelete", UIParent)`). It needs no template, size or
  visibility.
- Keybind addons, WeakAuras and most macro tools can `/click` a button but cannot call an
  addon's slash command, which is why SSF ships both.

## Events

- `BAG_UPDATE` (arg: bagID) fires per bag on any content change, often in bursts. Bucket it
  (AceBucket) so a loot burst produces one refresh.
- `BAG_CONTAINER_UPDATE` fires when the set of equipped bags changes (a bag swapped in or out).
  Use it to recompute AutoMax.
- `PLAYER_ENTERING_WORLD` for the first recompute after login or `/reload`.
- `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` mark combat start and end.
  `InCombatLockdown()` is the synchronous check.

## Bag bar buttons (for the counter)

- `MainMenuBarBackpackButton` is the backpack. `CharacterBag0Slot` through
  `CharacterBag3Slot` are bags 1 through 4. On the default bar the backpack is rightmost and
  `CharacterBag3Slot` (bag 4) is the **far-left** button, where the counter goes.
- The 12.x engine can collapse the bag bar to the backpack alone; when `CharacterBag3Slot` is
  not shown, anchor to `MainMenuBarBackpackButton` instead.
- Nothing enabled on this install (Baganator, EllesmereUIActionBars) hides or moves those
  buttons; EllesmereUIBags is disabled.
- Font: `NumberFontNormal` at 14 with the `"OUTLINE"` flag, as the original SoulSort used.

## Addon metadata

- `C_AddOns.GetAddOnMetadata("SoulShardSortForever", "Version")` → the TOC version string.
  The global `GetAddOnMetadata` does not exist on this engine.
- `C_AddOns.IsAddOnLoaded(name)` likewise replaces the global.

## Options panel

- The legacy `InterfaceOptions_AddCategory`, `InterfaceOptionsFrame` and
  `InterfaceOptionsFramePanelContainer` do not exist on this engine. AceConfigDialog's
  `AddToBlizOptions` registers through `Settings.RegisterCanvasLayoutCategory` and
  `Settings.RegisterAddOnCategory`, and opens through `Settings.OpenToCategory(id)`. The
  bundled AceConfig already handles this.
