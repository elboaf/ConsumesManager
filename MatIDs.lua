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
    ["Fadeleaf"]                = 3819,
    ["Firebloom"]               = 4625,
    ["Ghost Mushroom"]          = 8845,
    ["Golden Sansam"]           = 13464,
    ["Goldthorn"]               = 3821,
    ["Gromsblood"]              = 8846,
    ["Heart of the Wild"]       = 13465,
    ["Icecap"]                  = 12655,
    ["Khadgar's Whisker"]       = 3358,
    ["Mountain Silversage"]     = 13466,
    ["Plaguebloom"]             = 13467,
    ["Purple Lotus"]            = 8831,
    ["Stranglekelp"]            = 3820,
    ["Sungrass"]                = 8838,
    ["Swiftthistle"]            = 2452,
    ["Wild Steelbloom"]         = 3355,
    ["Wildvine"]                = 8153,
    ["Wintersbite"]             = 13010,

    -- Herbs (Turtle WoW custom)
    ["Deathweed"]               = 5173,    -- [TW]
    ["Mage Royal"]              = 785,     -- [TW] (Mageroyal, renamed)
    ["Savage Frond"]            = 22529,   -- [TW]
    ["Sweet Mountain Berry"]    = 51714,   -- [TW]

    -- Gardening mats (Turtle WoW)
    ["Magic Mushroom Spores"]   = 51716,   -- [TW]
    ["Mountain Berry Bush Seeds"] = 51707, -- [TW]
    ["Un'Goro Soil"]            = 11018,

    -- Alchemy intermediates / oils
    ["Blackmouth Oil"]          = 6370,
    ["Fire Oil"]                = 7067,
    ["Shadow Oil"]              = 3824,
    ["Stonescale Oil"]          = 13423,
    ["Goblin Rocket Fuel"]      = 10922,
    ["Swiftness Potion"]        = 6632,

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
    ["Empty Vial"]              = 1971,
    ["Leaded Vial"]             = 2457,
    ["Imbued Vial"]             = 18256,   -- [TW]

    -- Elemental mats
    ["Elemental Air"]           = 7080,
    ["Elemental Earth"]         = 7076,
    ["Elemental Fire"]          = 7078,
    ["Elemental Water"]         = 7077,

    -- Engineering / metal / cloth
    ["Dense Blasting Powder"]   = 15992,
    ["Dense Stone"]             = 12836,
    ["Heavy Blasting Powder"]   = 4377,
    ["Iron Bar"]                = 3575,
    ["Mageweave Cloth"]         = 4338,
    ["Runecloth"]               = 14047,
    ["Silk Cloth"]              = 4306,
    ["Solid Blasting Powder"]   = 10505,
    ["Thorium Bar"]             = 12359,
    ["Thorium Ore"]             = 10620,
    ["Thorium Widget"]          = 15994,
    ["Unstable Trigger"]        = 18588,

    -- Cooking mats (vanilla)
    ["Basilisk Brain"]          = 8398,
    ["Blasted Boar Lung"]       = 8392,
    ["Chimaerok Tenderloin"]    = 21151,
    ["Darkclaw Lobster"]        = 13893,
    ["Deeprock Salt"]           = 8150,
    ["Giant Egg"]               = 12207,
    ["Hot Spices"]              = 2692,
    ["Large Venom Sac"]         = 7974,
    ["Murloc Eye"]              = 12422,
    ["Mystery Meat"]            = 12426,
    ["Raw Greater Sagefish"]    = 13756,
    ["Raw Nightfin Snapper"]    = 13754,
    ["Raw Whitescale Salmon"]   = 13758,
    ["Red Wolf Meat"]           = 12203,
    ["Refreshing Spring Water"] = 159,
    ["Refreshing Springwater"]  = 159,     -- alternate spelling used in itemlist
    ["Runn Tum Tuber"]          = 13724,
    ["Scorpok Pincer"]          = 8393,
    ["Snickerfang Jowl"]        = 8394,
    ["Soothing Spices"]         = 2680,
    ["Tender Crocolisk Meat"]   = 12428,
    ["Tender Wolf Meat"]        = 12429,
    ["Tiger Meat"]              = 12427,
    ["Vulture Gizzard"]         = 8396,
    ["White Spider Meat"]       = 12425,

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