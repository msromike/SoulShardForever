-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- DebugReport: the window a player copies the debug record from. A stock AceGUI Frame
-- holding one stock multi-line edit box, filled with Debug:Text() (this session's events)
-- at the moment it opens:
-- it does not update while it is showing; opening it again fills it again. The edit box
-- never takes the keyboard by itself (the stock box does not), so key presses keep
-- reaching the game with the window up; a click into the text takes the keyboard for
-- Ctrl+A and Ctrl+C, and Escape gives it back. The Close button closes the window (the
-- stock Frame has no Escape-to-close). Its two lines of wording are English only, like the
-- record. Nothing here is styled: a tool window, not part of SSF's look.
--
-- Public:  Open() (opens the window, or refills it when it is already up).
-- Reads:   Debug:Text.
-- Touches nothing else.

local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
local DebugReport = SSF:NewModule("DebugReport")
local AceGUI = LibStub("AceGUI-3.0")

local TITLE = "SSF debug report"
local HINT = "Ctrl+A, Ctrl+C to copy."
local WIDTH, HEIGHT = 640, 420

function DebugReport:Open()
    local text = SSF:GetModule("Debug"):Text()
    if self.window then
        self.box:SetText(text)
        return
    end

    local window = AceGUI:Create("Frame")
    window:SetTitle(TITLE)
    window:SetStatusText(HINT)
    window:SetWidth(WIDTH)
    window:SetHeight(HEIGHT)
    window:SetLayout("Fill")
    -- released on close, so nothing of it stays behind; the next Open builds a fresh one
    window:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        self.window, self.box = nil, nil
    end)

    local box = AceGUI:Create("MultiLineEditBox")
    box:SetLabel("")
    box:DisableButton(true) -- no Accept button: nothing typed here is kept
    box:SetText(text)
    window:AddChild(box)

    self.window, self.box = window, box
end
