-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- Trimmer: the delete press. In combat or out, it removes one Soul Shard if the count is
-- over the cap: the shard furthest along the sort order (Bags:LastShard, top slot first
-- under SoulSort legacy Normal, Sorter:TopFirst), so loose shards go before a soul bag's.
-- Then it runs one Sorter pass. Nothing else. The delete goes first: a pass's moves lock
-- the shards they move, and those are the ones LastShard would pick.
-- Runs only inside a hardware event (a slash command or a button click), because
-- DeleteCursorItem is limited to one delete per hardware event on this engine.
-- In combat the delete is the same as out of it (the live server keeps it), but silent
-- (Sounds:Moving decides what is heard); the Sorter pass does nothing in combat but note
-- that it was asked, so a fight never moves a shard.
-- Paused (profile.paused), a press neither moves nor deletes; every paused press out of
-- combat plays the pause sound, if profile.pauseSound is on, and prints the paused-press
-- line (Status), if profile.pauseLog is on, whatever the count. In combat a paused press
-- is silent.
-- The delete is silent unless the announce option is on.
--
-- Public:  Delete(); WhyNot(count) -> why a press would not delete, or nil if it would:
--          "paused" (a mode: the only answer while paused, whatever the count), "quiet"
--          (no Drain Soul yet, Cap:IsQuiet), "atcap", "undercap". The window's Delete
--          Shard button greys on it with the reason under it. No combat reason: a press
--          deletes in a fight too, and the window is shut in one.
-- Sends:   SSF_DELETE_PRESSED (what the press decided: "delete" or WhyNot's answer; then
--          the count and cap it decided on, absent while paused) at the top of every
--          press, before anything is deleted; SSF_SHARD_DELETED (count after the delete,
--          cap, the deleted shard's bag and slot); SSF_DELETE_FAILED (why: "noshard", no
--          unlocked shard to pick; "cursor", the pickup did not put a shard on the cursor;
--          "held", the shard was still on the cursor after the delete) when a press that
--          decided to delete did not. Debug records all three; the first and last have no
--          other listener.
-- Reads:   Bags:LastShard/Count, Cap:Get/State/IsFull/IsQuiet, Sorter:TopFirst/Pass,
--          Sounds:PlayPause/Moving, Status:DeletedText/PausedPressText; profile.paused,
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
    if not bag then
        Trimmer:SendMessage("SSF_DELETE_FAILED", "noshard")
        return
    end

    -- the pickup and the delete go through Sounds, which decides whether they are heard
    local failed
    SSF:GetModule("Sounds"):Moving("delete", function()
        ClearCursor()
        C_Container.PickupContainerItem(bag, slot)
        local kind, cursorID = GetCursorInfo()
        if kind ~= "item" or cursorID ~= SHARD then
            ClearCursor()
            failed = "cursor"
            return
        end
        DeleteCursorItem()
        local stillHeld = GetCursorInfo()
        ClearCursor()
        if stillHeld then failed = "held" end
    end)
    if failed then
        Trimmer:SendMessage("SSF_DELETE_FAILED", failed)
        return
    end

    Trimmer:SendMessage("SSF_SHARD_DELETED", count - 1, cap, bag, slot)
    if SSF.db.profile.announce then
        SSF:Print(SSF:GetModule("Status"):DeletedText(count - 1, cap))
    end
end

function Trimmer:WhyNot(count)
    if SSF.db.profile.paused then return "paused" end
    local Cap = SSF:GetModule("Cap")
    if Cap:IsQuiet() then return "quiet" end
    count = count or SSF:GetModule("Bags"):Count()
    if Cap:State(count) == "over" then return nil end
    return Cap:IsFull(count) and "atcap" or "undercap"
end

function Trimmer:Delete()
    local p = SSF.db.profile
    if p.paused then -- every paused press out of combat: the sound and the chat line, each if switched on
        self:SendMessage("SSF_DELETE_PRESSED", "paused")
        if not InCombatLockdown() then
            if p.pauseSound then SSF:GetModule("Sounds"):PlayPause() end
            if p.pauseLog then SSF:Print(SSF:GetModule("Status"):PausedPressText()) end
        end
        return
    end
    -- count before the sort: a shard in flight can show at its source and its target
    local count, cap = SSF:GetModule("Bags"):Count(), SSF:GetModule("Cap"):Get()
    local why = self:WhyNot(count)
    self:SendMessage("SSF_DELETE_PRESSED", why or "delete", count, cap)
    if not why then TrimOne(count, cap) end
    SSF:GetModule("Sorter"):Pass()
end
