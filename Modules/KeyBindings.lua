-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- KeyBindings: SSF's two rows in Blizzard's Key Bindings screen (Bindings.xml: SSF_DELETE
-- and SSF_PAUSE), unbound until the player picks keys. Their labels are the globals
-- BINDING_NAME_SSF_DELETE and BINDING_NAME_SSF_PAUSE, set here at load for every class
-- (the rows show on any character, the gate only stops the actions) and set again on a
-- Language change. Opens the Key Bindings page scrolled to SSF's section and expanded.
--
-- SECTION must equal the category attribute in Bindings.xml; that file cannot read Lua,
-- so the name is typed in both places.
--
-- Public:  KeyBindings:ApplyLabels() (Core:ApplyLanguage calls it after a language switch)
--          KeyBindings:Open() (the window's Key Bindings button; the caller closes the
--          window first, SSF's window draws above the settings panel)
-- Owns no state, no events, no frames. Touches nothing else.

local ADDON = ...
local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local KeyBindings = SSF:NewModule("KeyBindings")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)

local SECTION = "Soul Shards Forever" -- Bindings.xml category, see the header

function KeyBindings:ApplyLabels()
    BINDING_NAME_SSF_DELETE = L["Delete Shard"]
    BINDING_NAME_SSF_PAUSE = L["Pause all SSF actions"]
end

-- There is no function to expand a section, so the section's own flag
-- (initializer.data.expanded) is set first; tested in game, and a key bound there
-- afterwards stuck through a reload with nothing blocked.
function KeyBindings:Open()
    local id = Settings.KEYBINDINGS_CATEGORY_ID
    local category = id and Settings.GetCategory(id)
    local layout = category and SettingsPanel:GetLayout(category)
    for _, initializer in ipairs(layout and layout:GetInitializers() or {}) do
        if initializer.data and initializer.data.name == SECTION then
            initializer.data.expanded = true
        end
    end
    Settings.OpenToCategory(id, SECTION)
end

KeyBindings:ApplyLabels() -- at load, before the gate: every class sees the rows labeled
