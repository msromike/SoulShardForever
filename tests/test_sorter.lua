-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_sorter: TopFirst and the moves one pass plans from a snapshot, read back from the
-- stub's record of PickupContainerItem calls (pairs: source, then target).
-- Exceptions: reads and resets Sorter.reruns, the module's private leftover counter, to
--          prove a rerun is pending or forgotten; nothing public exposes it, and a test
--          is the one place allowed to look.
-- Touches nothing else.

local SHARD = SSF.SHARD_ITEM_ID
local Sorter = SSF:GetModule("Sorter")
local profile = SSF.db.profile
local soul, plain = WoW.SoulBag, WoW.PlainBag
local function moves()
    local out = {}
    for i = 1, #WoW.picks, 2 do
        local s, t = WoW.picks[i], WoW.picks[i + 1]
        out[#out + 1] = s[1] .. ":" .. s[2] .. ">" .. t[1] .. ":" .. t[2]
    end
    return table.concat(out, " ")
end

test("TopFirst only under SoulSort legacy Normal", function()
    profile.soulsortLegacy, profile.soulsortReverse = false, false
    eq(Sorter:TopFirst(), false, "SSF Mode")
    profile.soulsortLegacy, profile.soulsortReverse = true, false
    eq(Sorter:TopFirst(), true, "legacy Normal")
    profile.soulsortLegacy, profile.soulsortReverse = true, true
    eq(Sorter:TopFirst(), false, "legacy Reverse")
    profile.soulsortLegacy, profile.soulsortReverse = false, false
end)

test("SSF Mode: shards in regular bags move into free soul bag slots, last shard first", function()
    profile.soulsortLegacy = false
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD, [9] = SHARD }), [1] = soul(4, { [4] = SHARD }) })
    local n = Sorter:Pass()
    eq(n, 2, "two moves")
    -- walk order: soul bag 1 bottom first (free 3, 2, 1), then backpack bottom first (9, 2)
    eq(moves(), "0:2>1:3 0:9>1:2", "backpack shards into the soul bag's free slots")
end)

test("SSF Mode: nothing moves with no soul bag, or no free soul bag slot", function()
    profile.soulsortLegacy = false
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD }) })
    eq(Sorter:Pass(), 0, "no soul bag")
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD }), [1] = soul(1, { [1] = SHARD }) })
    eq(Sorter:Pass(), 0, "soul bag full")
    eq(#WoW.picks, 0, "no pickup")
end)

test("a locked shard is skipped and the pass asks for a rerun", function()
    profile.soulsortLegacy = false
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD, [9] = SHARD }, { [9] = true }), [1] = soul(4) })
    eq(Sorter:Pass(), 1, "only the unlocked one moves")
    eq(moves(), "0:2>1:4", "slot 9 left alone")
    ok(Sorter.reruns ~= nil, "a rerun is pending")
    Sorter.reruns = nil
end)

test("in combat a pass does nothing and forgets leftovers", function()
    profile.soulsortLegacy = false
    WoW.SetBags({ [0] = plain(16, { [2] = SHARD }), [1] = soul(4) })
    Sorter.reruns = 2
    WoW.combat = true
    eq(Sorter:Pass(), 0, "nothing in combat")
    eq(Sorter.reruns, nil, "leftovers forgotten")
    eq(#WoW.picks, 0, "no pickup")
end)

test("SoulSort legacy Normal: a shard moves to an earlier slot, swapping with an item", function()
    profile.soulsortLegacy, profile.soulsortReverse = true, false
    -- no soul bag; backpack top first: slot 1 holds another item, slot 3 a shard
    WoW.SetBags({ [0] = plain(4, { [1] = 1234, [3] = SHARD }) })
    eq(Sorter:Pass(), 1, "one swap")
    eq(moves(), "0:3>0:1", "shard goes to the top slot, the item takes its place")
    profile.soulsortLegacy, profile.soulsortReverse = false, false
end)
