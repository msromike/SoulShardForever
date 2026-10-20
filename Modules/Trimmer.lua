-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Trimmer: Delete() is the press. Out of combat it removes one Soul Shard if the count is
-- over the cap: the shard furthest along the sort order (Bags:LastShard, top slot first
-- under SoulSort legacy Normal), so loose shards go before a soul bag's. Then it runs one
-- Sorter pass. Nothing else. The delete goes first: a pass's moves lock the shards they
-- move, and those are the ones LastShard would pick.
-- Runs only inside a hardware event (a slash command or a button click), because
-- DeleteCursorItem is limited to one delete per hardware event on this engine.
-- In combat it does nothing: the server reverts in-combat deletes when combat ends.
-- Paused (profile.paused), a press neither moves nor deletes; every paused press out of
-- combat plays the pause sound, if profile.pauseSound is on, and prints "All SSF actions
-- paused. Soul Shards: N (cap M)", if profile.pauseLog is on, whatever the count.
-- Silent unless the announce option is on. Sends SSF_SHARD_DELETED after a delete.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Trimmer = SSF:NewModule("Trimmer", "AceEvent-3.0")
local ADDON = "SoulShardForever"
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)

local SHARD = SSF.SHARD_ITEM_ID

-- Deletes the shard furthest along the sort order, if it is a shard; count and cap are the
-- press's, for the message and the announce line.
local function TrimOne(count, cap)
    local Bags, profile = SSF:GetModule("Bags"), SSF.db.profile
    local bag, slot = Bags:LastShard(profile.soulsortLegacy and not profile.soulsortReverse)
    if not bag then return end

    ClearCursor()
    C_Container.PickupContainerItem(bag, slot)
    local kind, cursorID = GetCursorInfo()
    if kind ~= "item" or cursorID ~= SHARD then
        ClearCursor()
        return
    end
    DeleteCursorItem()
    local stillHeld = GetCursorInfo()
    ClearCursor()
    if stillHeld then return end

    Trimmer:SendMessage("SSF_SHARD_DELETED", count - 1, cap)
    if profile.announce then
        SSF:Print(L["Deleted a Soul Shard."] .. " " .. SSF:GetModule("Status"):StatusText(count - 1, cap))
    end
end

function Trimmer:Delete()
    if InCombatLockdown() then return end

    local Bags, Cap = SSF:GetModule("Bags"), SSF:GetModule("Cap")
    local p = SSF.db.profile
    if p.paused then -- every paused press: the sound and the chat line, each if switched on
        if p.pauseSound then
            SSF:GetModule("Sounds"):Play(p.pauseSoundName, p.pauseSoundVolume)
        end
        if p.pauseLog then
            SSF:Print(L["All SSF actions paused"] .. ". " .. SSF:GetModule("Status"):StatusText())
        end
        return
    end
    -- count before the sort: a shard in flight can show at its source and its target
    local count, cap = Bags:Count(), Cap:Get()
    if count > cap then TrimOne(count, cap) end
    SSF:GetModule("Sorter"):Pass()
end
