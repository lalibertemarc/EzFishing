-- EzFishing static data. Edit lures, poles and zone requirements here.
local _, ns = ...

ns.FISHING_SKILL_LINE = 356
ns.FISHING_SPELL = 7620 -- base Fishing; the secure button casts it by name so the highest rank is used
ns.FISHING_SPELL_FALLBACK = 131474 -- modern Fishing, in case 7620 has no name on this client

-- Every spell ID the Fishing channel can show up as (classic ranks + modern IDs, just in case).
ns.FISHING_SPELLS = {
    [7620] = true, [7731] = true, [7732] = true, [18248] = true, [33095] = true, [51294] = true,
    [88868] = true, [110410] = true, [131474] = true, [131476] = true, [131490] = true, [158743] = true,
}

-- Lures, best first. bonus = skill added, req = fishing skill needed to use it.
ns.LURES = {
    { id = 6533, bonus = 100, req = 100 }, -- Aquadynamic Fish Attractor
    { id = 7307, bonus = 75,  req = 100 }, -- Flesh Eating Worm
    { id = 6532, bonus = 75,  req = 100 }, -- Bright Baubles
    { id = 6811, bonus = 50,  req = 50 },  -- Aquadynamic Fish Lens
    { id = 6530, bonus = 50,  req = 50 },  -- Nightcrawlers
    { id = 6529, bonus = 25,  req = 1 },   -- Shiny Bauble
}

-- Fishing pole skill bonus, used to pick the best pole in your bags. Unknown poles count as 0.
ns.POLE_BONUS = {
    [6256]  = 0,  -- Fishing Pole
    [12225] = 3,  -- Blump Family Fishing Pole
    [6365]  = 5,  -- Strong Fishing Pole
    [6366]  = 15, -- Darkwood Fishing Pole
    [6367]  = 20, -- Big Iron Fishing Pole
    [19022] = 25, -- Nat Pagle's Extreme Angler FC-5000
    [19970] = 35, -- Arcanite Fishing Pole
}

-- Effective fishing skill (skill + pole + lure) needed so fish never get away. Classic values.
-- Keyed by IDs, not names, so every client language works (zone names come back translated).
-- IDs from Forever 1.60.1.70707's UiMap, Map and AreaTable tables on wago.tools.

-- Zones by uiMapID (C_Map.GetBestMapForUnit, walked up its parents: towns and caves sit on their zone).
ns.ZONE_SKILL = {
    -- 25: Durotar, Mulgore, Tirisfal Glades, Dun Morogh, Elwynn Forest, Teldrassil, Zephras Isle (Forever's
    -- Skyborne start, two maps)
    [1411] = 25, [1412] = 25, [1420] = 25, [1426] = 25, [1429] = 25, [1438] = 25, [2521] = 25, [2665] = 25,
    -- 75: The Barrens, Silverpine Forest, Loch Modan, Westfall, Darkshore, Stormwind City, Orgrimmar,
    -- Ironforge, Thunder Bluff, Darnassus, Undercity
    [1413] = 75, [1421] = 75, [1432] = 75, [1436] = 75, [1439] = 75, [1453] = 75, [1454] = 75,
    [1455] = 75, [1456] = 75, [1457] = 75, [1458] = 75,
    -- 150: Hillsbrad Foothills, Duskwood, Redridge Mountains, Wetlands, Ashenvale, Stonetalon Mountains
    [1424] = 150, [1431] = 150, [1433] = 150, [1437] = 150, [1440] = 150, [1442] = 150,
    -- 225: Alterac Mountains, Arathi Highlands, Stranglethorn Vale, Swamp of Sorrows, Thousand Needles,
    -- Desolace, Dustwallow Marsh
    [1416] = 225, [1417] = 225, [1434] = 225, [1435] = 225, [1441] = 225, [1443] = 225, [1445] = 225,
    -- Riverglades (Forever, level 35-45): no published value, estimated like Dustwallow/Stranglethorn.
    [2548] = 225,
    -- 300: Western Plaguelands, The Hinterlands, Feralas, Tanaris, Azshara, Felwood, Un'Goro Crater, Moonglade
    [1422] = 300, [1425] = 300, [1444] = 300, [1446] = 300, [1447] = 300, [1448] = 300, [1449] = 300,
    [1450] = 300,
    -- 425: Eastern Plaguelands, Deadwind Pass, Silithus, Winterspring
    [1423] = 425, [1430] = 425, [1451] = 425, [1452] = 425,
}

-- Dungeons (no world map inside) by instance ID (GetInstanceInfo's 8th return).
ns.INSTANCE_SKILL = {
    [36] = 75,   -- The Deadmines
    [43] = 75,   -- Wailing Caverns
    [48] = 75,   -- Blackfathom Deeps
    [189] = 225, -- Scarlet Monastery
    [109] = 300, -- The Temple of Atal'Hakkar
    [349] = 300, -- Maraudon
    [289] = 425, -- Scholomance
    [329] = 425, -- Stratholme
}

-- Subzones, checked before their zone, by AreaTable ID: C_Map.GetAreaInfo gives the name in the client's
-- language, compared with GetSubZoneText.
ns.SUBZONE_SKILL = {
    [297] = 300, -- Jaguero Isle (Stranglethorn Vale)
}

-- Key bindings from Bindings.xml with their labels (shown on the Key Bindings page).
ns.BINDING_CAST = "CLICK EzFishingCastButton:LeftButton"
ns.BINDINGS = {
    { action = ns.BINDING_CAST, label = "Cast / Hook" },
    { action = "CLICK EzFishingLureButton:LeftButton", label = "Apply best lure" },
    { action = "EZFISHING_POLE", label = "Swap pole / weapons" },
}

-- Items whose icons stand in on the HUD when you have no lure / pole.
ns.PLACEHOLDER_LURE, ns.PLACEHOLDER_POLE = 6529, 6256

-- Chat and HUD color codes.
ns.COLOR = {
    accent = "|cff4fc3f7",
    good   = "|cff7cfc00",
    warn   = "|cffffd100",
    bad    = "|cffff5555",
    dim    = "|cff808080",
}

-- HUD visibility modes (Settings dropdown values).
ns.HUD_AUTO, ns.HUD_ALWAYS, ns.HUD_NEVER = 1, 2, 3

ns.DEFAULTS = {
    -- Casting
    doubleClick = true,
    doubleClickSpeed = 0.4,
    keyHook = true,
    bobberIcon = true,
    -- Sound
    soundPreset = true,
    backgroundSound = true,
    masterBoost = false,
    masterVolume = 1,
    -- Helpers
    autoLoot = true,
    smartPole = true,
    smartLure = false,
    lureWarning = true,
    swapBackCombat = true,
    swapBackOnEnd = false,
    idleTimeout = 60,
    -- HUD
    hudMode = 1,
    locked = true,
    scale = 1,
    -- Stats
    announceSkill = true,
}
