-- Soul Shard Forever (SSF). MIT, see LICENSE.
--
-- Bags: read-only queries over the player's bags, backpack through the reagent slot (bag 5,
-- where a soul pouch equips on Forever). No state, no events, never moves or deletes
-- anything. Every other module reads the bags through these methods.
--
-- Sort order (the one order everything uses): every soul bag, then every regular bag from
-- bag 4 down to the backpack; inside a bag, the bottom slot (highest number) first. With
-- topFirst (SoulSort legacy, Normal), the top slot comes first inside each regular bag;
-- soul bags keep bottom first. The caller passes topFirst; Bags reads no settings. The
-- Sorter fills along the order; the Trimmer deletes from its far end (LastShard).
-- API facts behind this file: .docs/BAG_API_NOTES.md.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Bags = SSF:NewModule("Bags")

local SHARD = SSF.SHARD_ITEM_ID
local FIRST_BAG, LAST_BAG = 0, Enum.BagIndex.ReagentBag -- 0 through 5

-- A value from the container API can be a secret value on this engine; anything that is
-- not a plain number is treated as "not a shard" / "not a number".
local function num(v)
    if type(v) == "number" then return v end
    return nil
end

function Bags:NumSlots(bag)
    return num(C_Container.GetContainerNumSlots(bag)) or 0
end

function Bags:IsShardAt(bag, slot)
    return num(C_Container.GetContainerItemID(bag, slot)) == SHARD
end

-- Nothing in the slot. A slot with a secret value in it is not free.
function Bags:IsFreeAt(bag, slot)
    return C_Container.GetContainerItemID(bag, slot) == nil
end

-- The server still holds the slot's item (a move or delete in flight). Only a plain false
-- counts as unlocked.
function Bags:IsLocked(bag, slot)
    local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if not C_Item.DoesItemExist(loc) then return false end
    local locked = C_Item.IsLocked(loc)
    if type(locked) == "boolean" then return locked end
    return true
end

-- A plain, known item that is not a shard and not locked: one a shard may swap with
-- (SoulSort legacy). A slot with a secret value in it is not one.
function Bags:IsSwappableAt(bag, slot)
    local id = num(C_Container.GetContainerItemID(bag, slot))
    return id ~= nil and id ~= SHARD and not self:IsLocked(bag, slot)
end

-- The bag's family bitfield: 0 for a regular bag, nonzero for a special bag.
local function Family(bag)
    local _, family = C_Container.GetContainerNumFreeSlots(bag)
    return num(family)
end

-- A soul bag is any equipped bag whose family bits overlap the Soul Shard's family bits,
-- whatever slot it sits in.
function Bags:IsSoulBag(bag)
    local family = Family(bag)
    if not family or family == 0 then return false end
    local shardFamily = num(C_Item.GetItemFamily(SHARD))
    return shardFamily ~= nil and bit.band(family, shardFamily) ~= 0
end

-- An equipped bag with no family restriction (the backpack, a plain bag).
function Bags:IsRegularBag(bag)
    return self:NumSlots(bag) > 0 and Family(bag) == 0
end

-- The bag IDs in sort order, as a list. Soul bags first, then the regular bags from bag 4
-- down to the backpack. A special bag that is not a soul bag (herb, enchanting) holds no
-- shards and is left out. See the header.
function Bags:SortOrder()
    local order = {}
    for bag = FIRST_BAG, LAST_BAG do
        if self:IsSoulBag(bag) then order[#order + 1] = bag end
    end
    for bag = LAST_BAG, FIRST_BAG, -1 do
        if self:IsRegularBag(bag) then order[#order + 1] = bag end
    end
    return order
end

-- Walks every slot in sort order, calling fn(bag, slot, position) where position is the
-- bag's 1-based index in SortOrder(). Bottom slot first inside each bag; top slot first
-- inside a regular bag when topFirst. fn returning true stops the walk.
function Bags:ForEachSlot(fn, topFirst)
    for position, bag in ipairs(self:SortOrder()) do
        local from, to, step = self:NumSlots(bag), 1, -1
        if topFirst and not self:IsSoulBag(bag) then from, to, step = 1, self:NumSlots(bag), 1 end
        for slot = from, to, step do
            if fn(bag, slot, position) then return end
        end
    end
end

-- Walks every shard in every bag, in bag and slot order; fn(bag, slot) returning true stops.
function Bags:ForEachShard(fn)
    for bag = FIRST_BAG, LAST_BAG do
        for slot = 1, self:NumSlots(bag) do
            if self:IsShardAt(bag, slot) and fn(bag, slot) then return end
        end
    end
end

function Bags:Count()
    local n = 0
    self:ForEachShard(function() n = n + 1 end)
    return n
end

-- Total slots across every equipped soul bag; 0 when there is none.
function Bags:SoulBagSlots()
    local n = 0
    for bag = FIRST_BAG, LAST_BAG do
        if self:IsSoulBag(bag) then n = n + self:NumSlots(bag) end
    end
    return n
end

-- The shard furthest along the sort order (topFirst as in ForEachSlot) that is not locked:
-- in the backpack-most bag that has one, the top-most shard, or the bottom-most when
-- topFirst. After a sort this is always the same spot. Returns bag, slot, or nil when
-- there is none.
function Bags:LastShard(topFirst)
    local vbag, vslot
    self:ForEachSlot(function(bag, slot)
        if self:IsShardAt(bag, slot) and not self:IsLocked(bag, slot) then
            vbag, vslot = bag, slot
        end
    end, topFirst)
    return vbag, vslot
end
