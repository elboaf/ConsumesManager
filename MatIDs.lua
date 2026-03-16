---------------------------------------------------------------
-- MatIDs.lua
-- Lookup table: mat name -> item ID for AH search link construction
-- Used by ConsumesManager to build item links for aux / vanilla AH
-- WoW 1.12 / Turtle WoW
--
-- IDs marked [TW] are Turtle WoW custom items.
-- All others are standard 1.12 vanilla IDs verified via wowhead.
---------------------------------------------------------------

CM_MatIDs = {

    -- Herbs (vanilla)
    ["Arthas' Tears"]           = 8836,
    ["Black Lotus"]             = 13468,
    ["Blindweed"]               = 8839,
    ["Bruiseweed"]              = 2453,
    ["Dreamfoil"]               = 13463,
    ["Fadeleaf"]                = 3818,
    ["Firebloom"]               = 4625,
    ["Ghost Mushroom"]          = 8845,
    ["Golden Sansam"]           = 13464,
    ["Goldthorn"]               = 3821,
    ["Gromsblood"]              = 8846,
    ["Heart of the Wild"]       = 10286,
    ["Icecap"]                  = 13467,
    ["Khadgar's Whisker"]       = 3358,
    ["Mountain Silversage"]     = 13465,
    ["Plaguebloom"]             = 13466,
    ["Purple Lotus"]            = 8831,
    ["Stranglekelp"]            = 3820,
    ["Sungrass"]                = 8838,
    ["Swiftthistle"]            = 2452,
    ["Wild Steelbloom"]         = 3355,
    ["Wildvine"]                = 8153,
    ["Wintersbite"]             = 3819,

    -- Herbs (Turtle WoW custom)
    ["Deathweed"]               = 5173,    -- [TW]
    ["Mageroyal"]              = 785,     -- [TW] (Mageroyal, renamed)
    ["Savage Frond"]            = 22529,   -- [TW]
    ["Sweet Mountain Berry"]    = 51714,   -- [TW]

    -- Gardening mats (Turtle WoW)
    ["Magic Mushroom Spores"]   = 51716,   -- [TW]
    ["Mountain Berry Bush Seeds"] = 51707, -- [TW]
    ["Un'Goro Soil"]            = 11018,

    -- Alchemy intermediates / oils
    ["Blackmouth Oil"]          = 6370,
    ["Fire Oil"]                = 6371,
    ["Shadow Oil"]              = 3824,
    ["Stonescale Oil"]          = 13423,
    ["Goblin Rocket Fuel"]      = 9061,
    ["Swiftness Potion"]        = 2459,

    -- Enchanting mats
    ["Dream Dust"]              = 11176,
    ["Large Brilliant Shard"]   = 14344,
    ["Small Dream Shard"]       = 61198,   -- [TW]

    -- Turtle WoW alchemy / poison mats
    ["Dust of Deterioration"]   = 8924,    -- [TW]
    ["Essence of Agony"]        = 8923,    -- [TW]
    ["Gargantuan Tel'Abim Banana"] = 60955, -- [TW]
    ["Premium Chocolate"]       = 61173,   -- [TW]
    ["Sandworm Meat"]           = 20424,   -- [TW]

    -- Vials
    ["Crystal Vial"]            = 8925,
    ["Empty Vial"]              = 3371,
    ["Leaded Vial"]             = 3372,
    ["Imbued Vial"]             = 18256,   -- [TW]

    -- Elemental mats
    ["Elemental Air"]           = 7069,
    ["Elemental Earth"]         = 7067,
    ["Elemental Fire"]          = 7068,
    ["Elemental Water"]         = 7070,

    -- Engineering / metal / cloth
    ["Dense Blasting Powder"]   = 15992,
    ["Dense Stone"]             = 12365,
    ["Heavy Blasting Powder"]   = 4377,
    ["Iron Bar"]                = 3575,
    ["Mageweave Cloth"]         = 4338,
    ["Runecloth"]               = 14047,
    ["Silk Cloth"]              = 4306,
    ["Solid Blasting Powder"]   = 10505,
    ["Thorium Bar"]             = 12359,
    ["Thorium Ore"]             = 10620,
    ["Thorium Widget"]          = 15994,
    ["Unstable Trigger"]        = 10560,

    -- Cooking mats (vanilla)
    ["Basilisk Brain"]          = 8394,
    ["Blasted Boar Lung"]       = 8392,
    ["Chimaerok Tenderloin"]    = 21024,
    ["Darkclaw Lobster"]        = 13888,
    ["Deeprock Salt"]           = 8150,
    ["Giant Egg"]               = 12207,
    ["Hot Spices"]              = 2692,
    ["Large Venom Sac"]         = 1288,
    ["Murloc Eye"]              = 730,
    ["Mystery Meat"]            = 12037,
    ["Raw Greater Sagefish"]    = 21153,
    ["Raw Nightfin Snapper"]    = 13759,
    ["Raw Whitescale Salmon"]   = 13889,
    ["Red Wolf Meat"]           = 12203,
    ["Refreshing Spring Water"] = 159,
    ["Runn Tum Tuber"]          = 18255,
    ["Scorpok Pincer"]          = 8393,
    ["Snickerfang Jowl"]        = 8391,
    ["Soothing Spices"]         = 3713,
    ["Tender Crocolisk Meat"]   = 3667,
    ["Tender Wolf Meat"]        = 12208,
    ["Tiger Meat"]              = 12202,
    ["Vulture Gizzard"]         = 8396,
    ["White Spider Meat"]       = 12205,

    -- E'ko items (Winterspring, sold on AH, 3x per Juju turn-in)
    ["Winterfall E'ko"]         = 12431,
    ["Frostmaul E'ko"]          = 12436,
    ["Shardtooth E'ko"]         = 12432,
    ["Chillwind E'ko"]          = 12434,
    ["Frostsaber E'ko"]         = 12430,

    --power crystals
    ["Blue Power Crystal"]          = 11184,
    ["Green Power Crystal"]         = 11185,
    ["Red Power Crystal"]          = 11186,
    ["Yellow Power Crystal"]         = 11188,

    --oranges lol
    ["Arcane Powder"]           = 17020,

    -- Name-search sentinels
    -- No single item ID exists - clicking searches AH by name instead.
    ["Bijou"]                   = "search",  -- any color bijou works
    ["Zandalar Honor Token"]    = "search",

    -- Concoction constituent elixirs are NOT listed here.
    -- Their IDs are resolved automatically from consumablesCategories at runtime.
    -- (Winterfall Firewater, Dreamtonic, Elixir of the Mongoose, etc.)
}