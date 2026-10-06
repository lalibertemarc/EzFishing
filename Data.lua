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

-- Effective fishing skill (skill + pole + lure) needed so fish never get away (enUS zone names).
-- Classic values; subzones (e.g. Jaguero Isle) are checked before the zone.
ns.ZONE_SKILL = {
    -- 25
    ["Dun Morogh"] = 25, ["Durotar"] = 25, ["Elwynn Forest"] = 25, ["Mulgore"] = 25,
    ["Teldrassil"] = 25, ["Tirisfal Glades"] = 25,
    -- 75
    ["The Barrens"] = 75, ["Blackfathom Deeps"] = 75, ["Darkshore"] = 75, ["Darnassus"] = 75,
    ["The Deadmines"] = 75, ["Ironforge"] = 75, ["Loch Modan"] = 75, ["Orgrimmar"] = 75,
    ["Silverpine Forest"] = 75, ["Stormwind City"] = 75, ["Thunder Bluff"] = 75, ["Undercity"] = 75,
    ["Wailing Caverns"] = 75, ["Westfall"] = 75,
    -- 150
    ["Ashenvale"] = 150, ["Duskwood"] = 150, ["Hillsbrad Foothills"] = 150, ["Redridge Mountains"] = 150,
    ["Stonetalon Mountains"] = 150, ["Wetlands"] = 150,
    -- 225
    ["Alterac Mountains"] = 225, ["Arathi Highlands"] = 225, ["Desolace"] = 225, ["Dustwallow Marsh"] = 225,
    ["Scarlet Monastery"] = 225, ["Stranglethorn Vale"] = 225, ["Swamp of Sorrows"] = 225,
    ["Thousand Needles"] = 225,
    -- 300
    ["Azshara"] = 300, ["Felwood"] = 300, ["Feralas"] = 300, ["The Hinterlands"] = 300, ["Maraudon"] = 300,
    ["Moonglade"] = 300, ["Jaguero Isle"] = 300, ["Tanaris"] = 300, ["The Temple of Atal'Hakkar"] = 300,
    ["Un'Goro Crater"] = 300, ["Western Plaguelands"] = 300,
    -- 425
    ["Deadwind Pass"] = 425, ["Eastern Plaguelands"] = 425, ["Scholomance"] = 425, ["Silithus"] = 425,
    ["Stratholme"] = 425, ["Winterspring"] = 425,
}

-- Key bindings from Bindings.xml with their labels, in the order shown on the options page.
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
