-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- load: brings the whole addon up outside the game, the way a login does, for the two
-- runners (tests/run.lua and tests/window.lua). The WoW stub; every file the toc names, in
-- its order, as the game reads it (an xml file loads the Lua files it names, through the xml
-- it includes, with anything inside an XML comment left out: so the libraries load where the
-- toc puts embeds.xml); OnInitialize; every module's OnEnable. One loader, so both runners
-- test the same addon, and it is the one the game loads: a file missing from the toc is
-- missing here too.
--
-- The glow library (LibCustomGlow) is the one stand-in: it draws with the game's texture
-- pools, which no stub has, so a table that takes every call and does nothing stands for
-- it. A glow is a look; nothing here can say anything about looks.
--
-- Public:  the chunk takes the addon's root folder and returns Load(opts) -> SSF, NS.
--          opts, all optional: saved (the saved file, SoulShardForeverDB, as the game
--          holds it before OnInitialize); before() (runs after the libraries and before
--          the addon's files: the bags, a global the scene needs); afterInit(SSF) (runs
--          between OnInitialize and the modules' OnEnable); login (true: send the events
--          a login sends and run the timers they start).
--          Also sets WoW.NS, the addon-private table every file is handed, and WoW.root,
--          the addon's root folder (a test that reads one of the addon's own files).
-- Touches nothing else.

local ROOT = ...
local ADDON, NS = "SoulShardForever", {}
local LOGIN_EVENTS = { "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "LOADING_SCREEN_DISABLED", "BAG_UPDATE_DELAYED" }

local function loadLua(rel, ...)
    local chunk, err = loadfile(ROOT .. "/" .. rel)
    if not chunk then error("cannot load " .. rel .. ": " .. tostring(err)) end
    return chunk(...)
end

-- every Lua file an xml names, through the xml files it includes, in order; a line inside
-- an XML comment is not loaded, by the game or here
local function XmlFiles(xml, out)
    local dir = xml:match("^(.*)/[^/]+$")
    local file = io.open(ROOT .. "/" .. xml)
    if not file then return out end -- AceConfig-3.0.xml names a folder this client's copy lacks
    local text = file:read("*a"):gsub("<!%-%-.-%-%->", "")
    file:close()
    for kind, inc in text:gmatch("<(%a+)%s+file%s*=%s*[\"']([^\"']+)[\"']") do
        if kind == "Include" or kind == "Script" then
            inc = ((dir and (dir .. "/") or "") .. inc):gsub("\\", "/")
            if kind == "Include" then XmlFiles(inc, out) else out[#out + 1] = inc end
        end
    end
    return out
end

-- the toc's file lines, in its order, as the game reads them: no ## line, no # comment,
-- no blank line
local function TocFiles()
    local out = {}
    for line in io.lines(ROOT .. "/SoulShardForever.toc") do
        line = line:gsub("\r", ""):match("^%s*(.-)%s*$")
        if line ~= "" and not line:match("^#") then out[#out + 1] = (line:gsub("\\", "/")) end
    end
    return out
end

return function(opts)
    opts = opts or {}
    loadLua("tests/wow_stub.lua", ROOT)
    WoW.root = ROOT

    -- the toc, line by line: an xml loads the Lua files it names (the libraries, through
    -- embeds.xml), a Lua file loads itself. The scene's before() and the saved file go in
    -- just ahead of the first of the addon's own Lua files, after every library.
    local started = false
    for _, rel in ipairs(TocFiles()) do
        local lower = rel:lower()
        if lower:match("%.xml$") then
            for _, lib in ipairs(XmlFiles(rel, {})) do
                if lib:find("LibCustomGlow", 1, true) then
                    setmetatable(LibStub:NewLibrary("LibCustomGlow-1.0", 1), { __index = function() return function() end end })
                else
                    loadLua(lib, ADDON, NS)
                end
            end
        elseif lower:match("%.lua$") then
            if not started then
                started = true
                if opts.before then opts.before() end
                SoulShardForeverDB = opts.saved
            end
            loadLua(rel, ADDON, NS)
        end
    end
    WoW.NS = NS

    -- AceAddon's own start-up, driven as the game drives it: ADDON_LOADED runs every
    -- OnInitialize and queues the enables, PLAYER_LOGIN runs them. Both queues end empty,
    -- so a module's Enable() later in a test really runs its OnEnable, as in the game.
    local SSF = LibStub("AceAddon-3.0"):GetAddon("SSF")
    WoW.FireEvent("ADDON_LOADED", ADDON)
    if opts.afterInit then opts.afterInit(SSF) end
    WoW.loggedIn = true
    WoW.FireEvent("PLAYER_LOGIN")
    if opts.login then
        for _, event in ipairs(LOGIN_EVENTS) do WoW.FireEvent(event) end
        WoW.RunTimers()
    end
    return SSF, NS
end
