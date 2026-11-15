-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- NewsShow: shows the current announcement (News\News.lua) in the panel on the window's
-- left until the character ticks "Don't show this again". It comes up when the welcome
-- would (Mike, 2026-11-15: the same behavior, so there is one rule to remember): while it
-- is owed, every load, a login or a reload alike, opens the window by itself, centered,
-- with the announcement beside it, and every open of the window, whoever opened it, brings
-- the announcement back with it. A load that lands in a fight opens nothing, and a fight
-- that closes the window does not bring it back afterwards: the next open, reload or
-- login does. The tick is what decides: it is saved the moment the box is ticked and taken
-- back the moment it is unticked, so how the panel closes afterwards does not matter.
-- Nothing is owed when no announcement was shipped or the current one is switched off.
-- While the panel is open it follows the Language setting: Options' rebuild fills it again
-- in the new language, the tick as the player left it.
--
-- Public:  Show(auto) (the panel, through Window:ShowLeftNote; auto: NewsShow is opening
--          the window by itself, which Window turns into a centered open), Owed() -> bool.
-- Listens: SSF_WINDOW_OPENED (any open), SSF_OPTIONS_REBUILT (a Language change or a help
--          toggle: the open panel is filled again), LOADING_SCREEN_DISABLED (once at load,
--          only while an announcement is owed).
-- Reads:   NS.news from News\News.lua (the announcement: id, on, title, text);
--          profile.newsSeen; Window:ShowLeftNote/RefreshLeftNote/InFight;
--          Colors:Gold (a paragraph's lead).
-- Saves:   profile.newsSeen: the announcement's id while ticked, false again when unticked.
-- Touches nothing else.

local ADDON, NS = ...
local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local NewsShow = SSF:NewModule("NewsShow", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)

-- what stands between a paragraph's gold lead and its text: two spaces, as Mike types
-- after a colon (2026-11-15, on purpose)
local LEAD_GAP = "  "

-- the announcement to show, or nil: none was shipped, or it is switched off
local function Current()
    local news = NS.news
    if news and news.on then return news end
end

-- Owed: there is one, and this character has not ticked it. The saved value has the
-- welcome's shape: a number once ticked (the id it saw), anything else while owed; a
-- newer announcement has a higher id, so it is owed again.
function NewsShow:Owed()
    local news = Current()
    if not news then return false end
    local seen = SSF.db.profile.newsSeen
    return type(seen) ~= "number" or seen < news.id
end

-- What the panel is handed: the title and the note's options. The lines are looked up
-- now, not at load, so they follow the Language setting. The tick box starts as the saved
-- value has it: unticked on any first show (a ticked announcement is not owed), ticked
-- when the panel is filled again after the player ticked it.
local function Note(self, news)
    local Colors = SSF:GetModule("Colors")
    local blocks = {}
    for i, part in ipairs(news.text) do
        local line
        if type(part) == "table" then -- a gold lead, then its text in white (the paragraph's own color)
            line = Colors:Gold(L[part.lead]) .. (part.text and (LEAD_GAP .. L[part.text]) or "")
        else
            line = L[part]
        end
        blocks[i] = { text = line, blank = type(part) == "table" and part.blank or nil }
    end
    return L[news.title], {
        blocks = blocks,
        tick = L["Don't show this again"],
        ticked = SSF.db.profile.newsSeen == news.id,
        button = L["Remind me later"],
        buttonTicked = L["Got it"],
        onTick = function(ticked) SSF.db.profile.newsSeen = ticked and news.id or false end,
        onClose = function() self.noteOpen = false end,
    }
end

-- The panel. Marked open before the window is asked for: the open sends SSF_WINDOW_OPENED,
-- which comes back here. In a fight the window stays shut, so nothing shows.
function NewsShow:Show(auto)
    local news = Current()
    local Window = SSF:GetModule("Window")
    if not news or self.noteOpen or Window:InFight() then return end
    self.noteOpen = true
    local title, opts = Note(self, news)
    Window:ShowLeftNote(title, opts, auto)
end

-- Options rebuilt its table (the Language changed, or help was toggled): the open panel
-- is filled again, in place, so its words are in the language the window now shows.
function NewsShow:OnOptionsRebuilt()
    local news = Current()
    if self.noteOpen and news then SSF:GetModule("Window"):RefreshLeftNote(Note(self, news)) end
end

-- Any open of the window: an announcement still owed comes up with it.
function NewsShow:OnWindowOpened()
    if not self.noteOpen and self:Owed() then self:Show() end
end

-- The load's own open, once the loading screen is gone, so the window opens into a drawn,
-- shown UI. A login and a reload alike, as the welcome.
function NewsShow:LOADING_SCREEN_DISABLED()
    self:UnregisterEvent("LOADING_SCREEN_DISABLED")
    self:Show(true)
end

-- Setup lives in OnEnable, not OnInitialize: Core's warlock gate switches modules off
-- before OnEnable, so other classes never get the announcement.
function NewsShow:OnEnable()
    self:RegisterMessage("SSF_WINDOW_OPENED", "OnWindowOpened")
    self:RegisterMessage("SSF_OPTIONS_REBUILT", "OnOptionsRebuilt")
    if self:Owed() then self:RegisterEvent("LOADING_SCREEN_DISABLED") end
end
