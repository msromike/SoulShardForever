-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Trimmer: the delete press. Out of combat it removes one Soul Shard if the count is over
-- the cap: the shard furthest along the sort order (Bags:LastShard, top slot first under
-- SoulSort legacy Normal, Sorter:TopFirst), so loose shards go before a soul bag's. Then
-- it runs one Sorter pass. Nothing else. The delete goes first: a pass's moves lock the
-- shards they move, and those are the ones LastShard would pick.
-- Runs only inside a hardware event (a slash command or a button click), because
-- DeleteCursorItem is limited to one delete per hardware event on this engine.
-- In combat it does nothing: the server reverts in-combat deletes when combat ends.
-- Paused (profile.paused), a press neither moves nor deletes; every paused press out of
-- combat plays the pause sound, if profile.pauseSound is on, and prints the paused-press
-- line (Status), if profile.pauseLog is on, whatever the count.
-- The delete is silent unless the announce option is on.
--
-- Public:  Delete(); WhyNot(count) -> why a press would not delete, or nil if it would:
--          "paused" (a mode: the only answer while paused, whatever the count), "atcap",
--          "undercap". The window's Delete Shard button greys on it with the reason under
--          it. No combat reason: Delete checks combat itself and the window is shut in a
--          fight.
-- Sends:   SSF_SHARD_DELETED (count after the delete, cap).
-- Reads:   Bags:LastShard/Count, Cap:Get/State/IsFull, Sorter:TopFirst/Pass,
--          Sounds:PlayPause, Status:DeletedText/PausedPressText; profile.paused,
--          pauseSound, pauseLog, announce.
-- Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local Trimmer = SSF:NewModule("Trimmer", "AceEvent-3.0")

local SHARD = SSF.SHARD_ITEM_ID

-- Deletes the shard furthest along the sort order, if it is a shard; count and cap are the
-- press's, for the message and the announce line.
local function TrimOne(count, cap)
    local Bags = SSF:GetModule("Bags")
    local bag, slot = Bags:LastShard(SSF:GetModule("Sorter"):TopFirst())
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
    if SSF.db.profile.announce then
        SSF:Print(SSF:GetModule("Status"):DeletedText(count - 1, cap))
    end
end

function Trimmer:WhyNot(count)
    if SSF.db.profile.paused then return "paused" end
    local Cap = SSF:GetModule("Cap")
    count = count or SSF:GetModule("Bags"):Count()
    if Cap:State(count) == "over" then return nil end
    return Cap:IsFull(count) and "atcap" or "undercap"
end

function Trimmer:Delete()
    if InCombatLockdown() then return end

    local p = SSF.db.profile
    if p.paused then -- every paused press: the sound and the chat line, each if switched on
        if p.pauseSound then SSF:GetModule("Sounds"):PlayPause() end
        if p.pauseLog then SSF:Print(SSF:GetModule("Status"):PausedPressText()) end
        return
    end
    -- count before the sort: a shard in flight can show at its source and its target
    local count, cap = SSF:GetModule("Bags"):Count(), SSF:GetModule("Cap"):Get()
    if not self:WhyNot(count) then TrimOne(count, cap) end
    SSF:GetModule("Sorter"):Pass()
end
