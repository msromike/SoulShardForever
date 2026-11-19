-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Bags: read-only queries over the player's bags, backpack through the reagent slot (bag 5,
-- where a soul pouch equips on Forever), and the one signal that the bags changed. Never
-- moves or deletes anything. Every other module reads the bags through these methods and
-- hears about changes through SSF_BAGS_CHANGED, never through its own BAG_UPDATE, and about
-- a lock going on or off through SSF_LOCKS_CHANGED. A lock can clear with no change in the
-- bags (a move the server refused, an item picked up and put back), and after a delete the
-- game fires no lock event at all when the server answers: the shard just goes, which is a
-- change in the bags. So whoever waits for the server listens to both. Two
-- exceptions, both for the moment of a login, which the bucket is too late for: Status
-- listens to the game's BAG_UPDATE_DELAYED and GET_ITEM_INFO_RECEIVED at a fresh login, to
-- ask CountAgrees before its login line; and Debug to the same two at a watched login, to
-- note what the bags looked like at each, on purpose the game's own signals and not Bags'.
--
-- The count at a fresh login: on the first login after the game starts, the game says the
-- bags are ready before it says what kind of bag each is. A soul pouch reads as a plain
-- bag in the reagent slot then, and no shard in it is counted, until the item data arrives
-- a moment later (seen in game: 11 counted of 25). The game's own count of the item is
-- right from the first moment. So GameCount hands that over, and CountAgrees says whether
-- Count can be trusted yet: Status holds its login line until it can, and Debug records
-- the two side by side.
-- Right after a delete the bags still show the deleted shard until the server confirms:
-- a listener to SSF_SHARD_DELETED that reads Bags:Count() gets the old number, and the
-- right one with the SSF_BAGS_CHANGED that follows within half a second. The message
-- carries the count after the delete; use that when the moment matters. Until then the
-- count is one too high, so the delete gate (Trimmer:WhyNot) asks AnyShardLocked before it
-- trusts the count: no shard locked, no delete or move still in flight.
--
-- The bags a shard can be in, one definition (SortOrder's list): every soul bag, in any
-- slot (the reagent slot holds a soul pouch or a reagent bag on Forever, and a shard goes
-- in it only when it is a soul pouch), and the regular bags 0 to 4. A herb or enchanting
-- bag, or a reagent bag, takes no shard. The count (ForEachShard, Count), the sort and the
-- delete all walk exactly these bags, so they can never disagree about a shard.
--
-- Sort order (the one order everything uses): every soul bag, then every regular bag from
-- bag 4 down to the backpack; inside a bag, the bottom slot (highest number) first. With
-- topFirst (SoulSort legacy, Normal), the top slot comes first inside each regular bag;
-- soul bags keep bottom first. The caller passes topFirst; Bags reads no settings. The
-- Sorter fills along the order; the Trimmer deletes from its far end (LastShard).
--
-- Public:  Ids() -> every bag id Bags looks at, ascending, equipped or not;
--          NumSlots(bag) -> n; IsShardAt(bag, slot), IsFreeAt(bag, slot),
--          IsLocked(bag, slot), IsSwappableAt(bag, slot), IsSoulBag(bag),
--          IsRegularBag(bag), HasSoulBag() -> bool; SoulBags() -> ids ascending;
--          SortOrder() -> ids in sort order; ForEachSlot(fn(bag, slot, position), topFirst);
--          ForEachShard(fn(bag, slot)); Count() -> n; SoulBagSlots() -> n;
--          GameCount() -> the game's own count of the shards in the bags, or nil when it
--          cannot be read; CountAgrees() -> bool, Count equals it (true when it cannot be
--          read: nothing to hold against);
--          AnyShardLocked() -> bool;
--          LastShard(topFirst) -> bag, slot or nil. Every one is also the headless
--          tests' handle on the bags.
-- Listens: BAG_UPDATE and BAG_CONTAINER_UPDATE, bucketed to one tick every 0.5 s;
--          ITEM_LOCK_CHANGED, gathered to the next tick (a bucket of length zero).
-- Sends:   SSF_BAGS_CHANGED, once per bucket;
--          SSF_LOCKS_CHANGED, on the tick after any item's lock went on or off. It says
--          only that a lock changed: a listener asks AnyShardLocked or IsLocked itself.
-- Game internals: ItemLocation.CreateFromBagAndSlot, Blizzard's Lua helper (not a documented
--          API call), which makes the location C_Item's questions take.
-- Owns no state. Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Bags = SSF:NewModule("Bags", "AceEvent-3.0", "AceBucket-3.0")

local SHARD = SSF.SHARD_ITEM_ID
local FIRST_BAG, LAST_BAG = 0, Enum.BagIndex.ReagentBag -- 0 through 5

-- A value from the container API can be a secret value on this engine; anything that is
-- not a plain number is treated as "not a shard" / "not a number".
local function num(v)
    if type(v) == "number" then return v end
    return nil
end

-- Every bag slot Bags looks at, backpack through the reagent slot, whatever is in it.
function Bags:Ids()
    local ids = {}
    for bag = FIRST_BAG, LAST_BAG do ids[#ids + 1] = bag end
    return ids
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

-- The server still holds the slot's item (a move or delete in flight). An empty slot is
-- unlocked; otherwise only a plain false counts as unlocked.
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

-- Every equipped soul bag's id, ascending (bag 1 to the reagent slot; the backpack is
-- never one). Counter takes the last soul bag for the button the number sits on.
function Bags:SoulBags()
    local list = {}
    for bag = FIRST_BAG, LAST_BAG do
        if self:IsSoulBag(bag) then list[#list + 1] = bag end
    end
    return list
end

function Bags:HasSoulBag()
    return #self:SoulBags() > 0
end

-- The bag IDs in sort order, as a list. Soul bags first, then the regular bags from bag 4
-- down to the backpack. A special bag that is not a soul bag (herb, enchanting) holds no
-- shards and is left out. See the header.
function Bags:SortOrder()
    local order = self:SoulBags()
    for bag = NUM_BAG_SLOTS, FIRST_BAG, -1 do -- the reagent slot holds a soul pouch or reagents, never a regular target
        if self:IsRegularBag(bag) then order[#order + 1] = bag end
    end
    return order
end

-- Walks one bag's slots from `from` to `to`, calling fn(bag, slot, position). Returns true
-- when fn returned true, which stops the caller's walk too.
local function WalkSlots(bag, from, to, step, fn, position)
    for slot = from, to, step do
        if fn(bag, slot, position) then return true end
    end
    return false
end

-- Walks every slot in sort order, calling fn(bag, slot, position) where position is the
-- bag's 1-based index in SortOrder(). Bottom slot first inside each bag; top slot first
-- inside a regular bag when topFirst. fn returning true stops the walk.
function Bags:ForEachSlot(fn, topFirst)
    for position, bag in ipairs(self:SortOrder()) do
        local from, to, step = self:NumSlots(bag), 1, -1
        if topFirst and not self:IsSoulBag(bag) then from, to, step = 1, self:NumSlots(bag), 1 end
        if WalkSlots(bag, from, to, step, fn, position) then return end
    end
end

-- Walks every shard in the bags a shard can be in (SortOrder's bags: the one definition),
-- in bag and slot order; fn(bag, slot) returning true stops.
function Bags:ForEachShard(fn)
    local function onSlot(bag, slot) return self:IsShardAt(bag, slot) and fn(bag, slot) end
    local shardBags = {}
    for _, bag in ipairs(self:SortOrder()) do shardBags[bag] = true end
    for bag = FIRST_BAG, LAST_BAG do
        if shardBags[bag] and WalkSlots(bag, 1, self:NumSlots(bag), 1, onSlot) then return end
    end
end

function Bags:Count()
    local n = 0
    self:ForEachShard(function() n = n + 1 end)
    return n
end

-- The game's own count of the shards in the bags, not the walk of the slots. A secret value
-- on this engine cannot be compared: nil then.
function Bags:GameCount()
    local n = C_Item.GetItemCount(SHARD)
    if issecretvalue and issecretvalue(n) then return nil end
    return num(n)
end

-- Count can be trusted: it equals the game's own. False at a fresh login until the game
-- says what kind of bag each is (see the header).
function Bags:CountAgrees()
    local game = self:GameCount()
    return game == nil or self:Count() == game
end

-- The server still holds some shard: a delete or a move asked for and not yet answered, or
-- a shard on the cursor or in a trade. While this is true Count() may still include a
-- shard that is on its way out. Only shards count: another item locked says nothing here.
function Bags:AnyShardLocked()
    local locked = false
    self:ForEachShard(function(bag, slot)
        locked = self:IsLocked(bag, slot)
        return locked
    end)
    return locked
end

-- Total slots across every equipped soul bag; 0 when there is none.
function Bags:SoulBagSlots()
    local n = 0
    for _, bag in ipairs(self:SoulBags()) do n = n + self:NumSlots(bag) end
    return n
end

-- The shard furthest along the sort order (topFirst as in ForEachSlot) that is not locked:
-- in the backpack-most bag that has one, the top-most shard, or the bottom-most when
-- topFirst and that bag is a regular one (a soul bag walks bottom first either way).
-- Returns bag, slot, or nil when there is none.
function Bags:LastShard(topFirst)
    local vbag, vslot
    self:ForEachSlot(function(bag, slot)
        if self:IsShardAt(bag, slot) and not self:IsLocked(bag, slot) then
            vbag, vslot = bag, slot
        end
    end, topFirst)
    return vbag, vslot
end

-- The one bag signal. BAG_UPDATE fires in bursts (one per bag, then again as the server
-- confirms), so one bucket here replaces a bucket in every listener.
function Bags:OnBagsChanged()
    self:SendMessage("SSF_BAGS_CHANGED")
end

-- The one lock signal. The game fires ITEM_LOCK_CHANGED inside the very call that picks an
-- item up, SSF's own pickups too, so the message goes out on the next tick: no listener
-- ever runs in the middle of a delete or a move. The bucket's length is zero on purpose:
-- it stands for no server time, it only gathers one tick's burst.
function Bags:OnLocksChanged()
    self:SendMessage("SSF_LOCKS_CHANGED")
end

function Bags:OnEnable()
    self:RegisterBucketEvent({ "BAG_UPDATE", "BAG_CONTAINER_UPDATE" }, 0.5, "OnBagsChanged")
    self:RegisterBucketEvent("ITEM_LOCK_CHANGED", 0, "OnLocksChanged")
end
