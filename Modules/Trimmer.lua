-- Soul Shard Forever (SSF). GPLv3, see LICENSE.
--
-- Trimmer: Delete() removes one Soul Shard when the count is over the cap. Nothing else.
-- Runs only inside a hardware event (a slash command or a button click), because
-- DeleteCursorItem is limited to one delete per hardware event on this engine.
-- In combat it does nothing: the server reverts in-combat deletes when combat ends.
-- Silent unless the announce option is on. Sends SSF_SHARD_DELETED after a delete.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SoulShardForever")
local Trimmer = SSF:NewModule("Trimmer", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("SoulShardForever")

local SHARD = SSF.SHARD_ITEM_ID

function Trimmer:Delete()
    if InCombatLockdown() then return end

    local Bags, Cap = SSF:GetModule("Bags"), SSF:GetModule("Cap")
    local count, cap = Bags:Count(), Cap:Get()
    if count <= cap then return end

    local bag, slot = Bags:PickVictim(SSF.db.profile.deleteOrder)
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

    self:SendMessage("SSF_SHARD_DELETED", count - 1, cap)
    if SSF.db.profile.announce then
        SSF:Print(L["Deleted a Soul Shard (%d/%d)."]:format(count - 1, cap))
    end
end
