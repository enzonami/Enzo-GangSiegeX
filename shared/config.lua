
local print = "off" -- Change to "off" to disable the cigarettes

    if print == "on" then
        print(
            [[
            /  __/ \  //_   /  _ \    / ___/ /  __/  __/  __\  \//
            |  \ | |\ ||/   | / \_____|    | |  \ | |  |  \  \  /
            |  /_| | \|/   /| \_/\____\___ | |  /_| |_/|  /_ /  \
            \____\_/  \\____\____/    \____\_\____\____\____/__/\\]]
    )
end

Config = Config or {}

Config.CheckUpdates = true  -- Set to false to disable update checking
Config.Framework = "qbox" -- Supported values: "qbox" or "qb"
Config.TargetSystem = "ox" -- Supported values: "ox" or "qb"
Config.NotifySystem = "ox" -- Supported values: "ox" or "qb"

Config.Turf = {
    Defaults = {
        radius = 50.0, -- Default turf zone radius (meters)
        captureTime = 60000, -- Time required to capture turf (milliseconds)
        captureCooldown = 300, -- Cooldown between capture attempts (seconds)
        blip = {
            color = 1, -- Default blip color (1 = Red)
            sprite = 378, -- Blip sprite ID (378 = Gang Territory)
            scale = 1.0, -- Blip size
            alpha = 255, -- Blip transparency (0-255)
            shortRange = true, -- Blip is only visible when nearby
            showOwner = true, -- Display gang name in blip title
            name = "Turf" -- Default blip name if no owner is set
        },
        gangster = {
            types = {
                ["default"] = {skin = "g_m_y_ballasout_01", color = 1},
                ["ballas"] = {skin = "g_m_y_ballasout_01", color = 27},
                ["vagos"] = {skin = "g_m_y_mexgoon_01", color = 46},
                ["grove"] = {skin = "g_m_y_famfor_01", color = 2}
            },
            weapon = "WEAPON_ASSAULTRIFLE", -- Default weapon for gangsters
            armGangsters = true, -- Give gangsters weapons
            cooldown = 60, -- Cooldown between gangster spawns (seconds)
            maxPerPlayer = 5, -- Maximum gangster units per player
            menuKey = "G" -- Key to open the gangster menu (default: G)
        },
        waves = {
            gangType = "default", -- Default gang type for wave spawns
            weapon = "WEAPON_ASSAULTRIFLE", -- Default weapon for wave NPCs
            heading = 0.0, -- Default heading for spawned NPCs
            countPerSpot = 1, -- Number of NPCs per spawn location
            locations = nil -- Default to turf center if not specified
        },
        interaction = {
            enabled = true, -- Enable NPC interaction
            distance = 2.0, -- Interaction distance (meters)
            icon = "fas fa-handshake", -- Interaction icon (FontAwesome)
            label = "Talk to Capo" -- Interaction label
        }
    },
    Data = {
        ["Grove"] = {
            center = vector3(119, -1951, 21), -- Turf center coordinates
            npc = vector4(118.62, -1951.21, 19.74, 51.13), -- NPC spawn
            waves = {
                gangType = "grove", -- Gang type for wave spawns
                cooldown = 10, -- Unused (kept for compatibility)
                locations = {
                    -- Wave spawn points
                    vector3(77.4, -1960.55, 19.75),
                    vector3(102.48, -1972.16, 19.89),
                    vector3(68.15, -1929.59, 20.06)
                },
                countPerSpot = 2, -- Number of NPCs per spawn point
                weapon = "WEAPON_ASSAULTRIFLE", -- Weapon for wave NPCs
                heading = 137.31 -- Heading for wave NPCs
            }
        },
        ["Mansion"] = {
            center = vector3(-1539.0, 128.0, 57.0), -- Turf center coordinates
            npc = vector4(-1539.5, 128.0, 55.77, 135.68), -- NPC spawn
            waves = {
                gangType = "ballas", -- Gang type for wave spawns
                cooldown = 10,  -- Unused (kept for compatibility)
                locations = {
                    -- Wave spawn points
                    vector3(-1552.38, 101.1, 58.18),
                    vector3(-1568.54, 115.47, 58.18),
                    vector3(-1532.14, 101.53, 55.77)
                },
                countPerSpot = 1, -- Number of NPCs per spawn point
                weapon = "WEAPON_ASSAULTRIFLE", -- Weapon for wave NPCs
                heading = 137.31 -- Heading for wave NPCs
            }
        },
        ["Heist"] = {
            center = vector3(751, -1202, 23.9), -- Turf center coordinates
            npc = vector4(751, -1202, 23.3, 359.5), -- NPC spawn
            waves = {
                gangType = "vagos", -- Gang type for wave spawns
                cooldown = 10,  -- Unused (kept for compatibility)
                locations = {
                    -- Wave spawn points
                    vector3(727.9, -1190.19, 23.28),
                    vector3(736.76, -1204.94, 26.59),
                    vector3(749.07, -1214.12, 23.75),
                    vector3(730.6, -1186.65, 29.06),
                    vector3(748.07, -1204.1, 29.51)
                },
                countPerSpot = 1, -- Number of NPCs per spawn point
                weapon = "WEAPON_ASSAULTRIFLE", -- Weapon for wave NPCs
                heading = 137.31 -- Heading for wave NPCs
            }
        }
    }
}

Config.Interact = {
    Locations = {
        Intel = {
            -- Intel blip locations
            {
                coords = vector3(-816.92, 178.09, 71.23),
                name = "Edwood Mansion",
                blip = {id = 353, color = 2, size = 1.0}
            },
            {
                coords = vector3(-14.22, -1441.9, 30.11),
                name = "Forum House",
                blip = {id = 353, color = 3, size = 1.0}},
            {
                coords = vector3(-1150.01, -1521.94, 9.63),
                name = "Magellan House",
                blip = {id = 353, color = 5, size = 1.0}
            },
            {
                coords = vector3(1973.74, 3815.29, 32.43),
                name = "Marina Trailer",
                blip = {id = 353, color = 5, size = 1.0}
            },
            {
                coords = vector3(-1122.65, -1089.37, 1.55),
                name = "Canal House",
                blip = {id = 353, color = 5, size = 1.0}},
            {
                coords = vector3(-1896.07, 642.61, 129.21),
                name = "Nrockford House",
                blip = {id = 353, color = 5, size = 1.0}
            },
            {
                coords = vector3(-371.83, 343.18, 108.95),
                name = "Didion House",
                blip = {id = 353, color = 5, size = 1.0}}
        },
        Robbery = {
            -- Robbery interaction points
            {
                "1", -- Robbery ID
                vector3(-804.86, 177.79, 72.74), -- Coordinates
                0.5, -- Interaction radius
                "Rob their stash", -- Interaction label
                "amb@world_human_stand_impatient@male@no_sign@idle_a", -- Animation dict
                "idle_a", -- Animation name
                5000 -- Animation duration (ms)
            },
            {
                "2",
                vector3(-804.02, 184.38, 72.44),
                0.5,
                "Search for smokes",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "3",
                vector3(-796.1, 184.97, 72.48),
                0.5,
                "Snatch the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "4",
                vector3(-797.16, 187.72, 72.5),
                0.5,
                "Snatch the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "5",
                vector3(-799.6, 176.8, 72.78),
                0.5,
                "Swipe their loot",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "6",
                vector3(-807.93, 181.49, 72.0),
                0.5,
                "Snatch the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "7",
                vector3(-808.26, 174.9, 76.49),
                0.5,
                "Go ham",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "8",
                vector3(-799.4, 172.25, 76.63),
                0.5,
                "Snatch the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "9",
                vector3(-799.96, 169.61, 76.62),
                0.5,
                "Rob their stash",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "10",
                vector3(-802.39, 172.88, 76.27),
                0.5,
                "Bag the loot",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "11",
                vector3(-806.05, 167.42, 76.37),
                0.5,
                "Snatch for the crew",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "12",
                vector3(-810.2, 170.63, 76.45),
                0.5,
                "Pocket the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "13",
                vector3(1978.77, 3819.78, 33.27),
                0.5,
                "Slam the stash",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "14",
                vector3(1970.41, 3814.84, 33.36),
                0.5,
                "Swipe their loot",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "15",
                vector3(1968.79, 3818.08, 33.12),
                0.5,
                "Go ham",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "16",
                vector3(1975.98, 3819.23, 33.43),
                0.5,
                "Grab a load",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "17",
                vector3(1975.7, 3818.07, 33.0),
                0.5,
                "Snatch the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "18",
                vector3(-1152.46, -1521.56, 10.35),
                0.5,
                "Go ham",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "19",
                vector3(-1154.32, -1523.48, 10.32),
                0.5,
                "Snatch the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "20",
                vector3(-1158.46, -1517.89, 10.47),
                0.5,
                "Pop off on their stash",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "21",
                vector3(-1159.69, -1520.74, 9.88),
                0.5,
                "Snatch the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "22",
                vector3(-1145.54, -1514.12, 10.63),
                0.5,
                "Pocket the loot",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "23",
                vector3(-1152.56, -1519.23, 10.44),
                0.5,
                "Five finger",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "24",
                vector3(-1150.12, -1512.26, 10.3),
                0.5,
                "Snatch the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "25",
                vector3(-1147.88, -1510.69, 10.3),
                0.5,
                "Slam their stash",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "26",
                vector3(-1147.46, -1513.79, 10.31),
                0.5,
                "Swipe their loot",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "27",
                vector3(-1115.97, -1089.77, 2.51),
                0.5,
                "Snatch the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "28",
                vector3(-1122.31, -1092.37, 2.48),
                0.5,
                "Pocket the loot",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "29",
                vector3(-1123.42, -1077.88, 2.47),
                0.5,
                "Five finger",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "30",
                vector3(-1117.93, -1086.0, 2.4),
                0.5,
                "Snatch the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "31",
                vector3(-1122.84, -1073.52, 4.15),
                0.5,
                "Slam their stash",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "32",
                vector3(-1119.5, -1080.0, 7.06),
                0.5,
                "Pocket the loot",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "33",
                vector3(-1119.99, -1083.61, 5.89),
                0.5,
                "Snatch the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "34",
                vector3(-1124.23, -1089.51, 6.56),
                0.5,
                "Pocket the loot",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "35",
                vector3(-1115.02, -1096.08, 6.59),
                0.5,
                "Five finger",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "36",
                vector3(-1125.28, -1076.58, 7.45),
                0.5,
                "Snatch the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "37",
                vector3(-1122.61, -1075.04, 7.44),
                0.5,
                "Go ham",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "38",
                vector3(-1120.99, -1089.84, 10.62),
                0.5,
                "Snatch the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "39",
                vector3(-1118.43, -1088.36, 10.36),
                0.5,
                "Search for smokes",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "40",
                vector3(-1128.1, -1082.69, 7.66),
                0.5,
                "Slam their stash",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "41",
                vector3(-1899.03, 646.51, 129.84),
                0.5,
                "Snatch the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "42",
                vector3(-1895.35, 647.22, 129.85),
                0.5,
                "Pocket the loot",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "43",
                vector3(-1893.64, 654.63, 130.04),
                0.5,
                "Five finger",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "44",
                vector3(-1888.59, 652.59, 129.96),
                0.5,
                "Snatch the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "45",
                vector3(-1888.94, 644.33, 129.71),
                0.5,
                "Take it.",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "46",
                vector3(-1890.3, 633.22, 129.83),
                0.5,
                "Swipe their loot",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "47",
                vector3(-1885.06, 636.55, 129.86),
                0.5,
                "Snatch the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "48",
                vector3(-1883.18, 638.45, 129.86),
                0.5,
                "Pocket the loot",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "49",
                vector3(-1895.37, 638.51, 129.48),
                0.5,
                "Five finger",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "50",
                vector3(-1877.87, 633.59, 130.2),
                0.5,
                "Snatch the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "51",
                vector3(-1872.35, 644.77, 130.04),
                0.5,
                "Slam their stash",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "52",
                vector3(-1869.48, 642.26, 130.13),
                0.5,
                "Snatch the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "53",
                vector3(-1863.77, 648.23, 129.7),
                0.5,
                "Slam their stash",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "54",
                vector3(-1865.57, 651.71, 129.55),
                0.5,
                "Search for smokes",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "55",
                vector3(-376.17, 336.41, 109.72),
                0.5,
                "Hurry Up!",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "56",
                vector3(-376.32, 342.71, 110.17),
                0.5,
                "Pocket the loot",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "57",
                vector3(-378.13, 338.12, 109.2),
                0.5,
                "Five finger",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "58",
                vector3(-382.54, 336.42, 109.25),
                0.5,
                "Finders Keepers!",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "59",
                vector3(-368.51, 342.4, 109.85),
                0.5,
                "Want it? Take it.",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "60",
                vector3(-367.27, 342.14, 109.92),
                0.5,
                "Swipe their loot",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "61",
                vector3(-362.61, 336.05, 109.62),
                0.5,
                "Snatch the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "62",
                vector3(-357.86, 340.99, 110.09),
                0.5,
                "Pocket the loot",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "63",
                vector3(-361.08, 341.2, 109.84),
                0.5,
                "Five finger",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "64",
                vector3(-362.12, 344.53, 109.73),
                0.5,
                "Snatch the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "65",
                vector3(-358.23, 344.8, 109.46),
                0.5,
                "Looks like it's yours now!",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "66",
                vector3(-358.39, 339.09, 109.66),
                0.5,
                "Snatch the goods",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "67",
                vector3(-359.26, 336.43, 109.46),
                0.5,
                "Slam their stash",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            },
            {
                "68",
                vector3(-361.32, 336.56, 109.43),
                0.5,
                "Search for smokes",
                "amb@world_human_stand_impatient@male@no_sign@idle_a",
                "idle_a",
                5000
            }            
            -- Add additional robbery points as needed
        }
    }
}

Config.RobberySettings = {
    cooldown = 300, -- Example value
    xpGain = 10,    -- Matches your logs
    xpPerLevel = 1000, -- Matches your level-up at 990 XP
    maxLevel = 10,  -- Example
    maxRewards = {1, 2}, -- Level 1: 1 reward, Level 2+: 2 rewards
    rewards = {
        {item = "money", chance = 80},
        {item = "lockpick", chance = 50},
        -- Add more items as needed
    }
}

Config.Crafting = {
    enabled = true, -- Enable the crafting system
    system = "ox", -- "cw" or "ox"
    table = "bigguns", -- Used only for cw-crafting
    recipes = { -- Shared recipes for both systems
        {
            output = "weapon_assaultrifle",
            inputs = {
                { item = "metalscrap", amount = 50 },
                { item = "steel", amount = 20 }
            },
            duration = 10000 -- Crafting duration in milliseconds
        },
        {
            output = "ammo-rifle",
            inputs = {
                { item = "gunpowder", amount = 10 },
                { item = "copper", amount = 5 }
            },
            duration = 5000
        }
    }
}

return Config