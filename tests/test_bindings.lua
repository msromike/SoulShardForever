-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_bindings: the two key bindings do what their rows say. Bindings.xml is Lua inside
-- XML that only the game reads; here each binding's own code is taken from the file and
-- run, the way a key press runs it, against the whole addon. So the file is tested as
-- written, not a copy of it.
-- Reads:   Bindings.xml (WoW.root); WoW.deleted and WoW.Settle (tests/wow_stub.lua);
--          Bags:Count.
-- Saves:   profile.paused, maxShards, autoMax, for the test at hand.
-- Touches nothing else.

local SHARD = SSF.SHARD_ITEM_ID
local profile = SSF.db.profile

-- binding name -> its code, compiled
local function Bindings()
    local file = assert(io.open(WoW.root .. "/Bindings.xml"))
    local text = file:read("*a"):gsub("<!%-%-.-%-%->", "")
    file:close()
    local out = {}
    for name, body in text:gmatch('<Binding%s+name="([%w_]+)"[^>]*>(.-)</Binding>') do
        out[name] = assert(loadstring(body, "Bindings.xml " .. name))
    end
    return out
end
local press = Bindings()

test("Bindings.xml has the two bindings, and each compiles", function()
    ok(press.SSF_DELETE ~= nil, "SSF_DELETE")
    ok(press.SSF_PAUSE ~= nil, "SSF_PAUSE")
end)

test("the delete key deletes one shard over the cap, and nothing at the cap", function()
    WoW.SetBags({ [0] = WoW.PlainBag(16, { [1] = SHARD, [2] = SHARD, [3] = SHARD }) })
    profile.paused, profile.autoMax, profile.maxShards = false, false, 2
    press.SSF_DELETE()
    eq(#WoW.deleted, 1, "3 shards, cap 2: one delete asked for")
    WoW.Settle()
    eq(SSF:GetModule("Bags"):Count(), 2, "two left once the server confirms")
    press.SSF_DELETE()
    eq(#WoW.deleted, 1, "at the cap: the key deletes nothing")
end)

test("the pause key turns pause on, and off again", function()
    profile.paused = false
    press.SSF_PAUSE()
    eq(profile.paused, true, "on")
    press.SSF_PAUSE()
    eq(profile.paused, false, "off")
end)

test("paused, the delete key deletes nothing", function()
    WoW.SetBags({ [0] = WoW.PlainBag(16, { [1] = SHARD, [2] = SHARD, [3] = SHARD }) })
    profile.autoMax, profile.maxShards = false, 1
    profile.paused = false
    press.SSF_PAUSE()
    press.SSF_DELETE()
    eq(#WoW.deleted, 0, "paused by the key: the delete key does nothing")
end)
