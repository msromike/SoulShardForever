-- SoulStone Sort Forever (SSF): a Soul Shard cap for warlocks on WoW Forever.
-- Fork of SoulSort by Anilusion (GPLv3), rewritten on Ace3 for Forever only.
-- GPLv3, see LICENSE.
--
-- Core: the addon object, the warlock gate and the saved settings. Nothing else.
-- The work is in the modules under Modules\.

local ADDON = "SoulStoneSortForever"
local SSF = LibStub("AceAddon-3.0"):NewAddon(ADDON, "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)

SSF.SHARD_ITEM_ID = 6265
SSF.ICON = "Interface\\Icons\\spell_shadow_soulgem"

local defaults = {
    profile = {
        maxShards = 20,             -- the cap while autoMax is off (1-100)
        autoMax = true,             -- cap follows the soul bag's slot count
        counter = false,            -- number on the far-left bag button
        announce = false,           -- one chat line per deletion
        minimap = { hide = false }, -- LibDBIcon state
    },
}

function SSF:OnInitialize()
    -- Warlock gate. On any other class nothing is set up and the addon never enables,
    -- so no saved variables, no slash command, no button, no message.
    if UnitClassBase("player") ~= "WARLOCK" then
        self:SetEnabledState(false)
        return
    end

    self.db = LibStub("AceDB-3.0"):New("SoulStoneSortForeverDB", defaults) -- per-character profiles

    self:SetupProbe() -- chunk 1a only
end

-- ===== Chunk 1a probe. THROWAWAY: removed in chunk 1d when Trimmer and DeleteButton land. =====
-- Deletes the last shard found in bags 0-4, unconditionally, one per call, and reports
-- exactly what happened so the slash-vs-click and combat questions get a clean answer.

local function ProbeDelete(via)
    ClearCursor()
    for bag = 4, 0, -1 do
        for slot = C_Container.GetContainerNumSlots(bag), 1, -1 do
            local id = C_Container.GetContainerItemID(bag, slot)
            if type(id) == "number" and id == SSF.SHARD_ITEM_ID then
                C_Container.PickupContainerItem(bag, slot)
                local kind, cursorID = GetCursorInfo()
                if kind ~= "item" or cursorID ~= SSF.SHARD_ITEM_ID then
                    SSF:Print(("probe via %s: pickup failed (cursor holds %s %s)"):format(via, tostring(kind), tostring(cursorID)))
                    ClearCursor()
                    return
                end
                local ok, err = pcall(DeleteCursorItem)
                local stillHeld = GetCursorInfo()
                ClearCursor()
                if not ok then
                    SSF:Print(("probe via %s: DeleteCursorItem errored: %s"):format(via, tostring(err)))
                elseif stillHeld then
                    SSF:Print(("probe via %s: delete refused, shard still on cursor (bag %d slot %d)"):format(via, bag, slot))
                else
                    SSF:Print(("probe via %s: deleted shard from bag %d slot %d"):format(via, bag, slot))
                end
                return
            end
        end
    end
    SSF:Print(("probe via %s: no shard found"):format(via))
end

function SSF:SetupProbe()
    self:RegisterChatCommand("ssfprobe", function() ProbeDelete("slash") end)
    local button = CreateFrame("Button", "SSFProbe", UIParent)
    button:SetScript("OnClick", function() ProbeDelete("click") end)
end
