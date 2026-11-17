-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- load: brings the whole addon up outside the game, the way a login does, for the two
-- runners (tests/run.lua and tests/window.lua). The WoW stub; every library embeds.xml
-- names, in its order; every file the toc names, in its order; OnInitialize; every module's
-- OnEnable. One loader, so both runners test the same addon, and it is the one the game
-- loads: a file missing from the toc is missing here too.
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

-- every Lua file an xml names, through the xml files it includes, in order
local function XmlFiles(xml, out)
    local dir = xml:match("^(.*)/[^/]+$")
    local file = io.open(ROOT .. "/" .. xml)
    if not file then return out end -- AceConfig-3.0.xml names a folder this client's copy lacks
    for line in file:lines() do
        local kind, inc = line:match("<(%a+)%s+file%s*=%s*[\"']([^\"']+)[\"']")
        if kind == "Include" or kind == "Script" then
            inc = ((dir and (dir .. "/") or "") .. inc):gsub("\\", "/")
            if kind == "Include" then XmlFiles(inc, out) else out[#out + 1] = inc end
        end
    end
    file:close()
    return out
end

return function(opts)
    opts = opts or {}
    loadLua("tests/wow_stub.lua", ROOT)
    WoW.root = ROOT

    for _, rel in ipairs(XmlFiles("embeds.xml", {})) do
        if rel:find("LibCustomGlow", 1, true) then
            setmetatable(LibStub:NewLibrary("LibCustomGlow-1.0", 1), { __index = function() return function() end end })
        else
            loadLua(rel, ADDON, NS)
        end
    end

    if opts.before then opts.before() end
    SoulShardForeverDB = opts.saved

    for line in io.lines(ROOT .. "/SoulShardForever.toc") do
        line = line:gsub("\r", "")
        if line:lower():match("%.lua$") and not line:match("^#") then loadLua((line:gsub("\\", "/")), ADDON, NS) end
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
