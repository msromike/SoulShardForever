-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_bags: Bags' sort order, counts, soul bag slots and LastShard, on fake bags.
-- Bag ids: 0 backpack, 1-4 the bag slots, 5 the reagent slot (a soul pouch on Forever).
-- A soul bag is the shard's family; a regular bag is family 0 (the stub's builders).
-- Touches nothing else.

local SHARD = SSF.SHARD_ITEM_ID
local Bags = SSF:GetModule("Bags")
local soul, plain = WoW.SoulBag, WoW.PlainBag

test("count across bags", function()
    WoW.SetBags({ [0] = plain(16, { [1] = SHARD, [3] = SHARD, [4] = 1234 }), [1] = soul(24, { [2] = SHARD }) })
    eq(Bags:Count(), 3, "three shards")
    eq(Bags:IsShardAt(0, 4), false, "another item is not a shard")
    eq(Bags:IsFreeAt(0, 2), true, "empty slot is free")
    eq(Bags:IsFreeAt(0, 4), false, "occupied slot is not free")
end)

test("sort order: soul bags first, then regular bags 4 down to the backpack", function()
    WoW.SetBags({ [0] = plain(16), [1] = plain(8), [2] = soul(20), [4] = plain(6), [5] = soul(24) })
    eq(table.concat(Bags:SortOrder(), ","), "2,5,4,1,0", "order")
end)

test("a special bag that is not a soul bag is left out", function()
    WoW.SetBags({ [0] = plain(16), [1] = { slots = 20, family = 8, items = {} } })
    eq(table.concat(Bags:SortOrder(), ","), "0", "herb bag skipped")
end)

test("SoulBags lists equipped soul bags ascending; HasSoulBag follows", function()
    WoW.SetBags({ [0] = plain(16), [1] = soul(20), [3] = plain(8), [5] = soul(24) })
    eq(table.concat(Bags:SoulBags(), ","), "1,5", "ids ascending")
    eq(Bags:HasSoulBag(), true, "has one")
    WoW.SetBags({ [0] = plain(16) })
    eq(#Bags:SoulBags(), 0, "none")
    eq(Bags:HasSoulBag(), false, "has none")
end)

test("soul bag slots total", function()
    WoW.SetBags({ [0] = plain(16), [2] = soul(20), [5] = soul(24) })
    eq(Bags:SoulBagSlots(), 44, "20 + 24")
    eq(Bags:IsSoulBag(2), true, "bag 2 is a soul bag")
    eq(Bags:IsSoulBag(0), false, "backpack is not")
    WoW.SetBags({ [0] = plain(16) })
    eq(Bags:SoulBagSlots(), 0, "none equipped")
end)

test("LastShard: backpack-most bag, bottom slot first by default", function()
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD, [9] = SHARD }), [1] = soul(24, { [1] = SHARD }) })
    local bag, slot = Bags:LastShard(false)
    eq(bag, 0, "backpack is last in the order")
    eq(slot, 2, "walk is bottom first, so the top-most shard is reached last")
end)

test("LastShard with topFirst walks regular bags top first", function()
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD, [9] = SHARD }), [1] = soul(24, { [1] = SHARD }) })
    local bag, slot = Bags:LastShard(true)
    eq(bag, 0, "still the backpack")
    eq(slot, 9, "top first, so the bottom-most shard is reached last")
end)

test("LastShard skips a locked shard", function()
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD, [9] = SHARD }, { [2] = true }) })
    local _, slot = Bags:LastShard(false)
    eq(slot, 9, "locked slot 2 skipped")
    eq(Bags:IsLocked(0, 2), true, "slot 2 reports locked")
    eq(Bags:IsLocked(0, 9), false, "slot 9 does not")
end)

test("LastShard is nil with no shards", function()
    WoW.SetBags({ [0] = plain(16, { [1] = 1234 }) })
    eq(Bags:LastShard(false), nil, "no shard")
end)

test("ForEachSlot walks soul bags bottom first even with topFirst", function()
    WoW.SetBags({ [1] = soul(3), [0] = plain(2) })
    local seen = {}
    Bags:ForEachSlot(function(bag, slot) seen[#seen + 1] = bag .. ":" .. slot end, true)
    eq(table.concat(seen, " "), "1:3 1:2 1:1 0:1 0:2", "soul bag bottom first, backpack top first")
end)
