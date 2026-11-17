#!/usr/bin/env python
"""tools/selftest.py: the check, checked.

Job:    prove that tools/check.py still catches what it is there to catch. Each case breaks
        one thing on purpose (a method renamed, a header line dropped, a module that errors
        as it starts, a button relabelled), runs the one step of the check that should
        object, and passes only if that step FAILS and says why in the words expected.
        Then the file's original bytes go back. A check can rot in the worst way, by
        still printing ALL PASS; this is what would notice. Every case here was first run
        by hand, 2026-11-16, when its step was written.
        Add a case with the check it proves: a new step in check.py with no case here is
        a step nobody has seen fail.
Takes:  nothing, or words to match against case names (`python tools/selftest.py window`
        runs the cases with "window" in the name). LUA and LUACHECK as check.py reads them.
Writes: nothing that stays. A case rewrites one file for the length of one step and puts
        the original bytes back even when the step raises; at the end every file touched
        is compared with what it held at the start, and a difference fails the run.
Exit:   0 when every case was caught for the expected reason and every file is as it was;
        1 otherwise. "SETUP WRONG" (the text a case replaces is no longer in the file)
        counts as a failure: the code moved, and the case must follow it.
When:   on GitHub on every push and pull request (.github/workflows/check.yml), and
        locally after any change to tools/check.py or tests/. Not part of check.py: it
        takes longer, and it changes files while it runs. This folder is the one the
        game loads, so do not /reload in game during the ten seconds it takes: a file
        is broken on disk for a moment at a time.
Touches nothing else.
"""
import contextlib
import glob
import io
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check  # noqa: E402

APPEND = object()   # `old` for a case that adds lines at the end of a file
EVERY = object()    # `count` for a case that replaces every occurrence


def run_step(step):
    """(passed, output) for one check step, its print captured."""
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        ok = step()
    return ok, buf.getvalue()


class Case:
    def __init__(self, name, step, rel, old, new, expect, count=1):
        self.name, self.step, self.rel, self.old, self.new = name, step, rel, old, new
        self.expect, self.count = expect, count


originals = {}


def mutate(rel, old, new, count):
    """Rewrite one file; returns False when `old` is not there. The first bytes seen for a
    file are kept, to put back and to compare at the end."""
    path = os.path.join(check.ROOT, rel)
    raw = open(path, "rb").read()
    originals.setdefault(rel, raw)
    text = raw.decode("utf-8").replace("\r\n", "\n")
    if old is APPEND:
        text += new
    else:
        if old not in text:
            return False
        text = text.replace(old, new) if count is EVERY else text.replace(old, new, count)
    with open(path, "wb") as f:
        f.write(text.encode("utf-8"))
    return True


def restore(rel):
    with open(os.path.join(check.ROOT, rel), "wb") as f:
        f.write(originals[rel])


# ---------------------------------------------------------------- the cases

PUBLIC, HEADERS, ACTS, EXCEPTIONS = (check.check_public_truth, check.check_header_truth,
                                     check.check_acts_on, check.check_exceptions)
WINDOW, TESTS, TOC, BIND = check.check_window, check.check_tests, check.check_toc, check.check_bindings
API = check.check_blizzard_api
HOOKS = check.check_hooks
COLORS, RULES = check.check_colors, check.check_rules

CASES = [
    # Public is the truth: modules and the addon object
    Case("public: a method renamed in its file only", PUBLIC, "Modules/Bags.lua",
         "function Bags:Count(", "function Bags:CountAll(", "Public lists Count"),
    Case("public: a method renamed in file and header, callers left", PUBLIC, "Modules/Sorter.lua",
         "TopFirst", "TopDown", "uses Sorter:TopFirst", EVERY),
    Case("public: a name dropped from Public", PUBLIC, "Modules/Trimmer.lua",
         "WhyNot(count) ->", "(count) ->", "does not list under Public"),
    Case("public: a constant renamed", PUBLIC, "Modules/Cap.lua",
         "Cap.MIN, Cap.MAX = 1, 100", "Cap.LOW, Cap.MAX = 1, 100", "Public lists MIN"),
    Case("public: a typo in a caller", PUBLIC, "Modules/LowGlow.lua",
         '"Counter"):Refresh()', '"Counter"):Refesh()', "uses Counter:Refesh"),
    Case("public: a caller names a module nobody makes", PUBLIC, "Modules/DeleteButton.lua",
         'GetModule("Trimmer")', 'GetModule("Trimer")', "no file makes that module"),
    Case("public: an addon constant renamed in Core only", PUBLIC, "Core.lua",
         "SSF.SHARD_ITEM_ID =", "SSF.SHARD_ID =", "Public lists SHARD_ITEM_ID"),
    Case("public: a test replaces a method the real module does not have", PUBLIC, "tests/test_newsshow.lua",
         "function Window:RefreshLeftNote(", "function Window:RefillLeftNote(", "replaces Window:RefillLeftNote"),
    # Public is the truth: the widgets
    Case("widget: a window method renamed in the widget only", PUBLIC, "Widgets/SSFFrame.lua",
         '["FitWidth"] = function', '["FitWide"] = function', "calls SSFFrame:FitWidth"),
    Case("widget: a window method renamed in widget and header, Window left", PUBLIC, "Widgets/SSFFrame.lua",
         "SetFooter", "SetFootLine", "calls SSFFrame:SetFooter", EVERY),
    Case("widget: a window method dropped from the widget's Public", PUBLIC, "Widgets/SSFFrame.lua",
         "MakeRoom() (a showing note", "(a showing note", "does not list under Public"),
    Case("widget: a typo in Window's call", PUBLIC, "Modules/Window.lua",
         "self.window:FitToContent()", "self.window:FitContent()", "calls SSFFrame:FitContent"),
    Case("widget: a side note method renamed, the loop call in SSFFrame left", PUBLIC, "Widgets/SSFSideNote.lua",
         '["Layout"] = function', '["Relayout"] = function', "calls SSFSideNote:Layout"),
    Case("widget: a side note method renamed in widget and header, a name stock widgets also use", PUBLIC,
         "Widgets/SSFSideNote.lua", "Show", "Display", "calls SSFSideNote:Show", EVERY),
    Case("widget: a copy of a method AceGUI's core already gives", PUBLIC, "Widgets/SSFSideNote.lua",
         '    ["Close"] = function', '    ["IsShown"] = function(self) return self.frame:IsShown() end,\n    ["Close"] = function',
         "core already gives every widget"),
    Case("widget: a dialogControl widget's own method renamed in the file only", PUBLIC, "Widgets/SSFStepperSlider.lua",
         '["MinWidth"] = function', '["NarrowWidth"] = function', "Public lists MinWidth"),
    # Reads and Saves are claims
    Case("headers: a stale Reads claim (the call is gone, the header still says it)", HEADERS, "Modules/LowGlow.lua",
         'SSF:GetModule("Counter"):Refresh()', "-- call removed", "Reads names Counter"),
    # Acts on
    Case("acts: a file starts deleting, header silent", ACTS, "Modules/Sorter.lua",
         APPEND, "\nlocal function Probe() DeleteCursorItem() end\n", 'does not say "DeleteCursorItem"'),
    Case("acts: a file changes a game setting, with no Acts on at all", ACTS, "Modules/Cap.lua",
         APPEND, '\nlocal function Probe() SetCVar("Sound_EnableSFX", 0) end\n', 'does not say "SetCVar"'),
    Case("acts: a file writes a global name", ACTS, "Modules/Bags.lua",
         APPEND, '\nlocal function Probe() _G["SSFProbe"] = true end\n', 'does not say "global"'),
    Case("acts: a file makes a macro", ACTS, "Modules/Status.lua",
         APPEND, '\nlocal function Probe() CreateMacro("x", 1, "") end\n', 'does not say "CreateMacro"'),
    Case("acts: an Acts on field removed", ACTS, "Modules/Trimmer.lua",
         "-- Acts on: the bags: deletes one shard", "--          the bags: deletes one shard", 'does not say "DeleteCursorItem"'),
    Case("acts: the code stops doing what Acts on still names", ACTS, "Modules/Macros.lua",
         "        CreateMacro(MACROS[key].name, ICON, self:Body(key), perChar)", "        -- removed",
         "Acts on names CreateMacro, the code never does it"),
    Case("acts: a header loses the library it hands a table to", ACTS, "Modules/Broker.lua",
         "-- Acts on: LibDBIcon: its Register", "-- Acts on: the minimap icon: Register", 'does not say "LibDBIcon"'),
    # hooks, both ways; raw hooks one at a time; scripts set on a frame the file did not create
    Case("hooks: a hook the header still names, gone from the code", HOOKS, "Modules/Debug.lua",
         '            self:SecureHook(SSF, "Printf", "OnPrintf")', "            -- removed",
         "Hooks names Printf, the code never hooks it"),
    Case("hooks: a new hook, header silent", HOOKS, "Modules/Bags.lua",
         APPEND, '\nlocal function Probe() Bags:SecureHook(SSF, "Print", "OnPrint") end\n', "the code hooks Print, Hooks does not name it"),
    Case("hooks: a global function hooked, read as the function and not its handler", HOOKS, "Modules/Cap.lua",
         APPEND, '\nlocal function Probe() Cap:SecureHook("UseContainerItem", "OnUse") end\n',
         "the code hooks UseContainerItem, Hooks does not name it"),
    Case("hooks: a hook whose name is not written out", HOOKS, "Modules/Cap.lua",
         APPEND, "\nlocal function Probe(name) Cap:SecureHook(SSF, name, print) end\n", "cannot read what this hook is on"),
    Case("hooks: a raw hooksecurefunc with no exception", HOOKS, "Modules/Sorter.lua",
         APPEND, '\nhooksecurefunc("UseContainerItem", print)\n', "raw hook hooksecurefunc on UseContainerItem"),
    Case("hooks: a frame's own HookScript with no exception", HOOKS, "Modules/Counter.lua",
         APPEND, '\nlocal function Probe(f) f:HookScript("OnShow", print) end\n', "raw hook HookScript on OnShow"),
    Case("hooks: a second raw hook behind one excused in the header", HOOKS, "Modules/LowGlow.lua",
         "-- Touches nothing else.\n",
         "-- Hooks: _G.UseContainerItem and _G.PickupContainerItem.\n"
         "-- Exceptions: hooksecurefunc on UseContainerItem, raw because.\n"
         "-- Touches nothing else.\n\n"
         'hooksecurefunc("UseContainerItem", print)\nhooksecurefunc("PickupContainerItem", print)\n',
         "raw hook hooksecurefunc on PickupContainerItem"),
    Case("hooks: a script set on a frame the file was handed", HOOKS, "Modules/Bags.lua",
         APPEND, '\nlocal function Probe(frame) frame:SetScript("OnShow", print) end\n',
         "sets OnShow on a frame this file did not create"),
    Case("hooks: Help's Acts on no longer owns up to its SetScript", HOOKS, "Modules/Help.lua",
         "-- Acts on: SetScript on a frame Help", "--          SetScript on a frame Help",
         "sets OnEnter on a frame this file did not create"),
    Case("hooks: an Acts on that says SetScript, the calls gone", HOOKS, "Modules/Help.lua",
         "wrapper:SetScript(", "wrapper:HasScript(", "Acts on names SetScript, the code sets no script", EVERY),
    # a color in other clothes
    Case("colors: a color typed as a table with r, g, b keys", COLORS, "Modules/Bags.lua",
         APPEND, "\nlocal PROBE = { r = 0.2, g = 0.3, b = 0.4 }\n", "a table with r, g and b typed as numbers"),
    Case("colors: the same table over several lines", COLORS, "Modules/Bags.lua",
         APPEND, "\nlocal PROBE = {\n    r = 0.2,\n    g = 0.3,\n    b = 0.4,\n}\n", "a table with r, g and b typed as numbers"),
    Case("colors: a color typed as three locals on one line, then used", COLORS, "Modules/Bags.lua",
         APPEND, "\nlocal R, G, B = 0.2, 0.3, 0.4\nlocal function Probe(t) t:SetVertexColor(R, G, B) end\n",
         "names this file sets to numbers"),
    Case("colors: a color typed as three locals on three lines, then used", COLORS, "Modules/Bags.lua",
         APPEND, "\nlocal R = 0.2\nlocal G = 0.3\nlocal B = 0.4\nlocal function Probe(t) t:SetTextColor(R, G, B, 1) end\n",
         "names this file sets to numbers"),
    # one value, one home
    Case("rules: a constant another file has, typed again inside a block", RULES, "Modules/Bags.lua",
         APPEND, "\ndo\n    local VALUE_GAP = 5\nend\n", "VALUE_GAP is typed in"),
    Case("rules: the same table constant twice, once over several lines", RULES, "Modules/Bags.lua",
         APPEND, "\ndo\n    local PROBE_SET = {\n        1,\n        2\n    }\nend\ndo\n    local PROBE_SET = { 1, 2 }\nend\n",
         "PROBE_SET is typed in"),
    Case("rules: two things with one name and one number in one file", RULES, "Widgets/SSFCentered.lua",
         "local PAIR_GAP = 12 --", "local GAP = 12 --", "GAP is typed in Widgets/SSFCentered.lua"),
    Case("rules: a module that only passes calls on to another", RULES, "Modules/Combat.lua",
         '    return InCombatLockdown() and true or false\nend\n\nfunction Combat:InFight()\n'
         '    return (InCombatLockdown() or UnitAffectingCombat("player")) and true or false',
         '    return SSF:GetModule("Bags"):HasSoulBag()\nend\n\nfunction Combat:InFight()\n'
         '    return SSF:GetModule("Bags"):Count()',
         "a file that adds nothing but a hop"),
    Case("rules: a file asks the game about combat itself", RULES, "Modules/Bags.lua",
         APPEND, "\nlocal function Probe() return InCombatLockdown() end\n", "InCombatLockdown is typed here; ask Combat"),
    Case("tests: the sort no longer asks the pause gate", TESTS, "Modules/Sorter.lua",
         'if SSF:GetModule("Trimmer"):Paused() then -- paused: nothing moves', 'if false then -- paused: nothing moves',
         "paused, Sorter:Pass moves nothing"),
    Case("tests: the window's fight question shrunk to the lockdown", TESTS, "Modules/Combat.lua",
         'return (InCombatLockdown() or UnitAffectingCombat("player")) and true or false', "return InCombatLockdown() and true or false",
         "but it is a fight already"),
    Case("tests: the low mark's setter no longer holds it under the cap", TESTS, "Modules/Cap.lua",
         "SSF.db.profile.lowMark = math.min(clamp(n), self:Get())", "SSF.db.profile.lowMark = clamp(n)",
         "set above the cap: held at the cap"),
    Case("tests: the low mark read above the cap before Recompute", TESTS, "Modules/Cap.lua",
         "return math.min(SSF.db.profile.lowMark, self:Get())", "return SSF.db.profile.lowMark",
         "never read above the cap, even before Recompute"),
    Case("tests: the delete button made again when its module is switched on again", TESTS,
         "Modules/DeleteButton.lua", "    if self.button then return end\n", "",
         "DeleteButton: no frame made a second time"),
    Case("tests: the fake game skips AceAddon's start-up queue again (the loader before A8)", TESTS,
         "tests/load.lua",
         '    WoW.FireEvent("ADDON_LOADED", ADDON)\n    if opts.afterInit then opts.afterInit(SSF) end\n'
         '    WoW.loggedIn = true\n    WoW.FireEvent("PLAYER_LOGIN")',
         '    local AceAddon = LibStub("AceAddon-3.0")\n    AceAddon:InitializeAddon(SSF)\n'
         '    if opts.afterInit then opts.afterInit(SSF) end\n    WoW.loggedIn = true\n    AceAddon:EnableAddon(SSF)',
         "on again"),
    Case("tests: the count walks bags the delete never reaches again", TESTS, "Modules/Bags.lua",
         "if shardBags[bag] and WalkSlots(", "if WalkSlots(", "only the backpack's and the soul bag's shards count"),
    Case("tests: the first open's second fit feeds a window closed in that tick", TESTS, "Modules/Window.lua",
         'self:ScheduleTimer("Refresh", 0)', "self:ScheduleTimer(function() Feed(self) end, 0)", "still closed"),
    Case("tests: an open starts a second open of itself", TESTS, "Modules/Window.lua",
         "    if self.opening then return end", "    local _ = nil", "one open, one message"),
    Case("tests: only a chat command redraws the window again", TESTS, "Modules/Window.lua",
         'if source ~= "window" then self:Refresh() end', 'if source == "chat" then self:Refresh() end',
         "a source not named: redrawn"),
    Case("tests: an unknown WhyNot answer errors on every redraw", TESTS, "Modules/Options.lua",
         "(BLOCKER_TEXT[why] or CapIs)()", "BLOCKER_TEXT[why]()", "no error"),
    Case("tests: an unknown state painted white again", TESTS, "Modules/Colors.lua",
         'return BY_STATE[state] or error("Colors: no color for the state " .. tostring(state), 3)',
         "return BY_STATE[state] or Colors.WHITE", "ForState: an error, not a quiet white"),
    # the toc and the files on disk
    Case("toc: a file's line dropped from the toc", TOC, "SoulShardForever.toc",
         "Modules\\Counter.lua\n", "", "Modules/Counter.lua is on disk and not in the toc"),
    Case("toc: a line spelled with the wrong case", TOC, "SoulShardForever.toc",
         "Modules\\Options.lua", "Modules\\options.lua", "no file is spelled exactly that"),
    Case("toc: a line for a file that does not exist", TOC, "SoulShardForever.toc",
         "Modules\\LowGlow.lua", "Modules\\LowGlow.lua\nModules\\Ghost.lua", "the toc names Modules\\Ghost.lua"),
    Case("toc: a library path in embeds.xml spelled with the wrong case", TOC, "embeds.xml",
         "Libs\\LibStub\\LibStub.lua", "Libs\\Libstub\\LibStub.lua", "embeds.xml names Libs\\Libstub\\LibStub.lua"),
    # Bindings.xml, held to the code it calls
    Case("bindings: the button's global name changed in the code only", BIND, "Modules/DeleteButton.lua",
         'CreateFrame("Button", "SSFDelete", UIParent)', 'CreateFrame("Button", "SSFTrim", UIParent)',
         "uses the global SSFDelete"),
    Case("bindings: the same rename leaves the README's /click pointing at nothing", BIND, "Modules/DeleteButton.lua",
         'CreateFrame("Button", "SSFDelete", UIParent)', 'CreateFrame("Button", "SSFTrim", UIParent)',
         "tells the player to /click SSFDelete"),
    Case("bindings: the method the pause key calls renamed where it is defined", BIND, "Modules/Options.lua",
         "function Options:TogglePause(", "function Options:FlipPause(", "calls Options:TogglePause"),
    Case("bindings: Bindings.xml calls a method the module does not have", BIND, "Bindings.xml",
         '):TogglePause()', '):Toggle()', "calls Options:Toggle"),
    Case("bindings: a row's label is no longer set", BIND, "Modules/KeyBindings.lua",
         "BINDING_NAME_SSF_PAUSE = L", "BINDING_NAME_SSF_HOLD = L", "nothing sets BINDING_NAME_SSF_PAUSE"),
    Case("bindings: the category differs from the section the Keybindings button opens", BIND, "Modules/KeyBindings.lua",
         'local SECTION = "Soul Shards Forever"', 'local SECTION = "Soul Shards"', "would open the wrong place"),
    Case("tests: the delete key's own code in Bindings.xml no longer clicks the button", TESTS, "Bindings.xml",
         "SSFDelete:Click()", "SSFDelete:Hide()", "one delete asked for"),
    Case("tests: the pause key's own code in Bindings.xml broken", TESTS, "Bindings.xml",
         "if s and s:IsEnabled() then", "if s and not s:IsEnabled() then", "the pause key turns pause on"),
    # Blizzard's names: the globals, and the reaches past the documented API
    Case("blizzard: a global nobody proved the game has", API, ".luacheckrc",
         '    "CLOSE",', '    "CLOSE", "NoSuchBlizzardThing",', "nowhere in this client's UI source"),
    Case("blizzard: a proven-in-game global the code no longer names", API, ".luacheckrc",
         '"MuteSoundFile", ', "", "KNOWN_GLOBALS lists MuteSoundFile"),
    Case("blizzard: a reach taken off the list, the code still making it", API, "tools/blizzard_reaches.txt",
         "GameTooltip:IsOwned ", "# GameTooltip:IsOwned ", "reads GameTooltip.IsOwned"),
    Case("blizzard: a reach Blizzard renamed (not in the UI source any more)", API, "tools/blizzard_reaches.txt",
         "MacroFrame.MacroSelector ", "MacroFrame.MacroPicker ", "MacroFrame.MacroPicker is nowhere in this client's UI source"),
    Case("blizzard: a reach listed for a file that does not make it", API, "tools/blizzard_reaches.txt",
         APPEND, "ShowMacroFrame                           Modules/Bags.lua\n", "whose code no longer uses it"),
    Case("blizzard: a reach the header does not own up to", API, "Modules/Counter.lua",
         "-- Game internals: the bag bar's buttons", "--          the bag bar's buttons", "does not name"),
    Case("blizzard: a new member read off a Blizzard frame", API, "Modules/Bags.lua",
         APPEND, "\nlocal function Probe() return MacroFrame.SecretField end\n", "reads MacroFrame.SecretField"),
    Case("blizzard: a frame made from a template nobody listed", API, "Modules/Bags.lua",
         APPEND, '\nlocal function Probe() return CreateFrame("Frame", nil, UIParent, "TooltipBorderedFrameTemplate") end\n',
         "creates a frame from the template TooltipBorderedFrameTemplate"),
    # the exceptions and Lib internals, counted against CLAUDE.md
    Case("exceptions: a new one appears in a header", EXCEPTIONS, "Modules/LowGlow.lua",
         "-- Touches nothing else.", "-- Exceptions: a raw frame, because.\n-- Touches nothing else.", "lists 0 for LowGlow"),
    Case("exceptions: a second one numbered into a header that has one", EXCEPTIONS, "Widgets/SSFFrame.lua",
         "-- Exceptions: the frame gets a global name", "-- Exceptions: (1) something new. (2) the frame gets a global name",
         "documents 2 exception(s)"),
    Case("exceptions: a header's Exceptions field removed, the list left", EXCEPTIONS, "Modules/Counter.lua",
         "-- Exceptions: the FontString", "--          the FontString", "documents 0 exception(s)"),
    Case("exceptions: the number in CLAUDE.md changed, the list left", EXCEPTIONS, "CLAUDE.md",
         "- Five documented exceptions", "- Six documented exceptions", "says Six documented exceptions, lists 5"),
    Case("exceptions: a line dropped from CLAUDE.md's list", EXCEPTIONS, "CLAUDE.md",
         "    - Core: ApplyLanguage writes into AceLocale's own table (AceLocale has no way to\n"
         "      switch language while the game runs).\n", "", "lists 0 for Core"),
    Case("exceptions: a Lib internals field where none is allowed", EXCEPTIONS, "Modules/LowGlow.lua",
         "-- Touches nothing else.", "-- Lib internals: AceDB's keys table.\n-- Touches nothing else.", "does not allow one there"),
    Case("exceptions: a Lib internals field removed, CLAUDE.md still names the module", EXCEPTIONS, "Modules/Help.lua",
         "-- Lib internals:", "--         ", "allows Lib internals in Help"),
    Case("exceptions: a module taken out of CLAUDE.md's places, its header left", EXCEPTIONS, "CLAUDE.md",
         "Window, Tooltip and Help modules", "Window and Tooltip modules", "does not allow one there"),
    # the window's controls
    Case("window: the bottom right button relabelled", WINDOW, "Modules/Window.lua",
         'SetRightButton(L["Keybindings"]', 'SetRightButton(L["Delete Shard"]', "-Button      shown  enabled Keybindings"),
    Case("window: the bottom right button never set up", WINDOW, "Modules/Window.lua",
         "    self.window:SetRightButton(", "    local _ = (function(...) end)(", "-Button      shown  enabled Keybindings"),
    Case("window: the help button never set up", WINDOW, "Modules/Window.lua",
         "    self.window:SetHelpButton(", "    local _ = (function(...) end)(", "-Button      shown  enabled (no text:"),
    Case("window: an option's key renamed", WINDOW, "Modules/Options.lua",
         'minimap = Toggle(1, L["Show minimap icon"],', 'minimapGone = Toggle(1, L["Show minimap icon"],', "the window did not open"),
    Case("window: a widget method renamed in the widget only, so the open errors", WINDOW, "Widgets/SSFFrame.lua",
         '["FitWidth"] = function', '["FitWide"] = function', "the window did not open"),
    Case("window: a module that errors as it starts", WINDOW, "Modules/Counter.lua",
         "function Counter:OnEnable()", "function Counter:OnEnable()\n    error('boom')", "the game would have shown in red"),
    # the tests, on the whole addon started as the game starts it
    Case("tests: an event handler renamed where it is defined, its registration left", TESTS, "Modules/Sorter.lua",
         "function Sorter:OnCombatEnd(", "function Sorter:OnFightEnd(", "method 'OnCombatEnd' not found"),
    Case("tests: a registration naming a handler that does not exist", TESTS, "Modules/Counter.lua",
         "function Counter:OnEnable()", "function Counter:OnEnable()\n    self:RegisterMessage('SSF_BAGS_CHANGED', 'NoSuchHandler')",
         "method 'NoSuchHandler' not found"),
    Case("tests: a module errors as it starts", TESTS, "Modules/Broker.lua",
         "function Broker:OnEnable()", "function Broker:OnEnable()\n    local x = nil + 1", "an error the game would show in red"),
    Case("tests: a syntax error in a file", TESTS, "Modules/Welcome.lua",
         "local Welcome = SSF:NewModule(", "local Welcome = = SSF:NewModule(", "cannot load Modules/Welcome.lua"),
    Case("tests: the sort drops a shard in the wrong slot", TESTS, "Modules/Sorter.lua",
         "C_Container.PickupContainerItem(move[3], move[4])", "C_Container.PickupContainerItem(move[1], move[2])",
         "once the server confirms, every shard is in the soul bag"),
    Case("tests: the bags never say they changed", TESTS, "Modules/Bags.lua",
         '"BAG_UPDATE"', '"BAG_UPDATED"', "the bag change that follows reruns the pass"),
    Case("tests: SSF calls a frame method the game does not have", TESTS, "Modules/Counter.lua",
         "function Counter:OnEnable()", "function Counter:OnEnable()\n    UIParent:NoSuchMethod()", "no frame method NoSuchMethod"),
    # the tests of Settings, the options table, /ssf, Tab, Help, Welcome, the window's spot
    Case("tests: a chat setting's usage line names the wrong thing", TESTS, "Modules/Settings.lua",
         'L["Use: /ssf %s on|off"]:format(key)', 'L["Use: /ssf %s on|off"]:format(def.name)', "the usage line names the key"),
    Case("tests: a toggle no longer tells Tab its value words", TESTS, "Modules/Settings.lua",
         "        valueWords[key] = VALUE_WORDS", "        -- removed", "the usage line offers off and on"),
    # (the window's own title styling errors on the tree AceConfigDialog then builds, as the
    # addon starts, before test_options can say "cap is inline")
    Case("tests: an options group that is not inline", TESTS, "Modules/Options.lua",
         'type = "group", inline = true, order = 10,', 'type = "group", inline = false, order = 10,',
         "in function 'StyleGroupTitles'"),
    Case("tests: a fifth answer from WhyNot with no text on the button", TESTS, "Modules/Trimmer.lua",
         'and "atcap" or "undercap"', 'and "atcap" or "nearcap"', "the Delete Shard button has a text for every answer"),
    Case("tests: the old word announce shows up in the command list", TESTS, "Modules/Options.lua",
         "announceOld.cmdHidden = true", "announceOld.cmdHidden = false", "announce is not listed"),
    Case("tests: a hidden word offered by Tab", TESTS, "Modules/Options.lua",
         'if HIDDEN_WORDS[word] then return "hidden" end', 'if HIDDEN_WORDS[word] then return "listed" end',
         "no hidden word"),
    Case("tests: /ssf and a number no longer sets the cap", TESTS, "Modules/SlashCommand.lua",
         'if input:match("^%d+$") then', "if false then", "/ssf 25 sets the cap to 25"),
    Case("tests: a bare number out of range answers in the long form", TESTS, "Modules/Settings.lua",
         'if short then return nil, L["Use: /ssf %d-%d"]', 'if false then return nil, L["Use: /ssf %d-%d"]',
         "/ssf 500: the usage line in the short form"),
    Case("tests: /ssf debug takes words after on", TESTS, "Modules/DebugCommand.lua",
         'if (word == "on" or word == "off") and rest == "" then', 'if (word == "on" or word == "off") then',
         "debug on now: the usage line"),
    Case("tests: help mode gives a tooltip to an option with no help line", TESTS, "Modules/Help.lua",
         'entry.descStyle = entry.desc and style or "hidden"', "entry.descStyle = style", "no help line: still hidden"),
    Case("tests: a fight that closes the welcome settles it", TESTS, "Modules/Welcome.lua",
         "                if InFight() then return end -- a fight closed it: still owed", "", "and the note is still owed"),
    Case("tests: the saved spot is used on another screen size", TESTS, "Modules/Window.lua",
         "math.abs(saved.width - w) < 1 and", "math.abs(saved.width - w) < 10000 and", "another screen size: centered"),
    Case("tests: a new state in Cap with no color", TESTS, "Modules/Cap.lua",
         'if count < self:LowMark() then return "low" end', 'if count < self:LowMark() then return "starving" end',
         "Colors: no color for the state starving"),
    Case("tests: a volume level retuned under players' saved numbers", TESTS, "Modules/Sounds.lua",
         '{ key = "quiet", volume = 0.12 }', '{ key = "quiet", volume = 0.1 }', "quiet is the number saved for it"),
]


def prose_only_cases():
    """Cases found from the headers themselves: a module or a profile key that a header
    names only in its prose, outside Reads and Saves, gets a new use in that file. The rule
    before 2026-11-16 let these pass (named "somewhere in the header" was enough)."""
    reg = check.module_registry()
    modules = [m for m in reg if m != check.ADDON]
    keys = set()
    code = [f for f in check.lua_files() if not f.startswith("tests/")]
    for rel in code:
        reads, writes = check.profile_refs(check.code_lines(check.read(rel)))
        keys |= reads | writes

    def named(word, where):
        return re.search(r"\b" + re.escape(word) + r"\b", where) is not None

    out = []
    for rel in [f for f in code if f.startswith("Modules/")]:
        header = " ".join(check.header_lines(rel))
        fields = check.header_fields(rel)
        claims = fields.get("Reads", "") + " " + fields.get("Saves", "")
        stem = check.module_name(rel)
        for m in modules:
            if m != stem and named(m, header) and not named(m, fields.get("Reads", "")):
                out.append(Case(f"headers: {stem} calls {m}, which its header names only in prose", HEADERS, rel,
                                APPEND, f'\nlocal function Probe() return SSF:GetModule("{m}") end\n',
                                f"Reads does not name {m}"))
                break
        for k in sorted(keys):
            if named(k, header) and not named(k, claims):
                out.append(Case(f"headers: {stem} reads profile.{k}, which its header names only in prose", HEADERS, rel,
                                APPEND, f"\nlocal function Probe() return SSF.db.profile.{k} end\n",
                                "neither Reads nor Saves names it"))
                break
    return out[:6]


# ---------------------------------------------------------------- the runs

def run_case(case):
    """(caught, why not): apply, run the step, put the file back."""
    if not mutate(case.rel, case.old, case.new, case.count):
        return False, f"SETUP WRONG: {case.old!r} is no longer in {case.rel}"
    try:
        ok, out = run_step(case.step)
    finally:
        restore(case.rel)
    if ok:
        return False, "the step PASSED on the broken file"
    if case.expect not in out:
        return False, f"the step failed, but not for this reason: {case.expect!r} is not in its output"
    return True, None


def aside(paths, step):
    """Run a step with some files moved out of the way, then put them back."""
    moved = []
    try:
        for p in paths:
            os.rename(p, p + ".aside")
            moved.append(p)
        return run_step(step)
    finally:
        for p in moved:
            os.rename(p + ".aside", p)


def missing_cases():
    """The check must fail, not pass, when what it runs is not there. [(name, caught, why not)]"""
    out = []
    ok, text = aside([os.path.join(check.ROOT, "tests", "run.lua")], check.check_tests)
    out.append(("missing: the test runner is gone", not ok and "is missing" in text, "the step passed"))
    ok, text = aside(glob.glob(os.path.join(check.ROOT, "tests", "test_*.lua")), check.check_tests)
    out.append(("missing: no test file is found", not ok, "the step passed"))
    real = check.wowui_build
    check.wowui_build = lambda: (None, "clone failed: no network")
    try:
        ok, text = run_step(check.check_blizzard_api)
        out.append(("missing: no Blizzard UI source to check against", not ok, "the step passed"))
        sys.argv.append(check.OFFLINE)
        try:
            ok, text = run_step(check.check_blizzard_api)
        finally:
            sys.argv.remove(check.OFFLINE)
        out.append(("missing: the same, passed on purpose with --offline", ok and "SKIPPED" in text,
                    "it did not pass, or did not say it skipped"))
    finally:
        check.wowui_build = real
    return out


def new_folder_case():
    """A Lua file in a folder nothing reads: made, checked, removed. (name, caught, why not)"""
    folder = os.path.join(check.ROOT, "Extras")
    path = os.path.join(folder, "Thing.lua")
    os.makedirs(folder)
    try:
        with open(path, "w", encoding="utf-8") as f:
            f.write("-- a file in a new folder\n")
        ok, text = run_step(check.check_toc)
    finally:
        os.remove(path)
        os.rmdir(folder)
    return ("toc: a Lua file in a new folder nothing reads",
            not ok and "in a place the checks do not read" in text, "the step passed, or not for this reason")


def main(argv):
    words = [w.lower() for w in argv]
    wanted = lambda name: not words or any(w in name.lower() for w in words)

    # the check must pass on the tree as it is, or a caught break proves nothing
    clean = [("public truth", PUBLIC), ("header truth", HEADERS), ("acts on", ACTS), ("hooks", HOOKS), ("colors", COLORS), ("rules", RULES), ("exceptions", EXCEPTIONS),
             ("toc and files", TOC), ("bindings", BIND), ("blizzard api", API), ("window controls", WINDOW),
             ("tests", TESTS)]
    for label, step in clean:
        ok, out = run_step(step)
        if not ok:
            print(f"the {label} step fails before anything is broken; fix that first:\n{out}")
            return 1

    results = []
    for case in CASES + prose_only_cases():
        if wanted(case.name):
            caught, why = run_case(case)
            results.append((case.name, caught, why))
    extra = (missing_cases() if wanted("missing") else []) + ([new_folder_case()] if wanted("toc: a Lua file in a new folder") else [])
    for name, caught, why in extra:
        results.append((name, caught, None if caught else why))

    bad = 0
    for name, caught, why in results:
        print(("caught  " if caught else "MISSED  ") + name)
        if not caught:
            print("        " + str(why))
            bad += 1

    changed = [rel for rel, raw in originals.items() if open(os.path.join(check.ROOT, rel), "rb").read() != raw]
    for rel in changed:
        print(f"NOT RESTORED  {rel}")
    for label, step in clean:
        ok, _ = run_step(step)
        if not ok:
            print(f"AFTER THE RUN the {label} step no longer passes")
            bad += 1
    print(f"\n{len(results) - bad} of {len(results)} breaks caught for the expected reason, "
          f"{len(originals)} files touched and {'ALL RESTORED' if not changed else 'NOT ALL RESTORED'}")
    print("SELF-TEST PASSED" if not bad and not changed and results else "SELF-TEST FAILED")
    return 0 if not bad and not changed and results else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
