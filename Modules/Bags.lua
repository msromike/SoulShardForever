-- Soul Shard Forever (SSF). GPLv3, see LICENSE.
--
-- Bags: read-only queries over the player's bags 0-4. No state, no events, never moves
-- or deletes anything. Every other module reads the bags through these methods.
-- API facts behind this file: BAG_API_NOTES.md.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SoulShardForever")
local Bags = SSF:NewModule("Bags")

local SHARD = SSF.SHARD_ITEM_ID
local FIRST_BAG, LAST_BAG = 0, 4

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

-- A soul bag is any bag whose family bits overlap the Soul Shard's family bits.
function Bags:IsSoulBag(bag)
    local _, family = C_Container.GetContainerNumFreeSlots(bag)
    family = num(family)
    if not family or family == 0 then return false end
    local shardFamily = num(C_Item.GetItemFamily(SHARD))
    return shardFamily ~= nil and bit.band(family, shardFamily) ~= 0
end

-- Walks every shard and calls fn(bag, slot); fn returning true stops the walk.
-- order "front": backpack slot 1 outward. order "back": far-left bag, last slot, inward.
function Bags:ForEachShard(order, fn)
    if order == "back" then
        for bag = LAST_BAG, FIRST_BAG, -1 do
            for slot = self:NumSlots(bag), 1, -1 do
                if self:IsShardAt(bag, slot) and fn(bag, slot) then return end
            end
        end
    else
        for bag = FIRST_BAG, LAST_BAG do
            for slot = 1, self:NumSlots(bag) do
                if self:IsShardAt(bag, slot) and fn(bag, slot) then return end
            end
        end
    end
end

function Bags:Count()
    local n = 0
    self:ForEachShard("front", function() n = n + 1 end)
    return n
end

-- Total slots across every equipped soul bag; 0 when there is none.
function Bags:SoulBagSlots()
    local n = 0
    for bag = 1, LAST_BAG do
        if self:IsSoulBag(bag) then n = n + self:NumSlots(bag) end
    end
    return n
end

-- The shard to delete next: one in a regular bag first, in the given order; one in a soul bag
-- only when no regular bag holds any. Returns bag, slot, or nil when there is no shard.
function Bags:PickVictim(order)
    local vbag, vslot
    self:ForEachShard(order, function(bag, slot)
        if not self:IsSoulBag(bag) then
            vbag, vslot = bag, slot
            return true
        end
    end)
    if vbag then return vbag, vslot end
    self:ForEachShard(order, function(bag, slot)
        vbag, vslot = bag, slot
        return true
    end)
    return vbag, vslot
end
