local HS = HideAndSeek

HS.Presets = {}

--[[
    Boundary detection:
    - useSubZone = true  -> checks GetSubZoneText() against subZone field
    - useSubZone = false -> checks GetZoneText() against zone field (for full-city maps)
    - polygon is a fallback for custom coordinate-based boundaries
    All preset maps are verified safe for Hardcore (no hostile mobs, elites, or event spawns).
]]

HS.Presets.Maps = {

    -- ========================================================================
    -- HORDE
    -- ========================================================================

    {
        name = "Brill",
        zone = "Tirisfal Glades",
        subZone = "Brill",
        faction = "Horde",
        difficulty = "Easy",
        minPlayers = 2,
        recPlayers = "2-4",
        hideTime = 60,
        seekTime = 300,
        description = "Small undead town. Inn, church, and a few buildings with undead NPCs.",
        useSubZone = true,
        validSubZones = {"Brill", "Brill Town Hall", "Gallows' End Tavern"},
        polygon = {},
    },
    {
        name = "Thunder Bluff",
        zone = "Thunder Bluff",
        subZone = nil,
        faction = "Horde",
        difficulty = "Medium",
        minPlayers = 3,
        recPlayers = "3-6",
        hideTime = 60,
        seekTime = 420,
        description = "Multiple rises connected by bridges. Tents, totems, Tauren NPCs everywhere.",
        useSubZone = false,
        polygon = {},
    },
    {
        name = "The Drag",
        zone = "Orgrimmar",
        subZone = "The Drag",
        faction = "Horde",
        difficulty = "Medium",
        minPlayers = 3,
        recPlayers = "3-5",
        hideTime = 60,
        seekTime = 420,
        description = "The Drag + Cleft of Shadow. Shop alcoves, vendor stalls, RFC entrance.",
        useSubZone = true,
        validSubZones = {"The Drag", "Cleft of Shadow"},
        polygon = {},
    },
    {
        name = "Orgrimmar",
        zone = "Orgrimmar",
        subZone = nil,
        faction = "Horde",
        difficulty = "Hard",
        minPlayers = 4,
        recPlayers = "4-8",
        hideTime = 60,
        seekTime = 600,
        description = "Full city. All valleys, The Drag, Cleft of Shadow. Huge area, no minimap.",
        useSubZone = false,
        polygon = {},
    },
    {
        name = "Undercity",
        zone = "Undercity",
        subZone = nil,
        faction = "Horde",
        difficulty = "Hard",
        minPlayers = 4,
        recPlayers = "4-8",
        hideTime = 60,
        seekTime = 600,
        description = "Circular underground maze. Four quarters, canals, completely disorienting without minimap.",
        useSubZone = false,
        polygon = {},
    },

    -- ========================================================================
    -- ALLIANCE
    -- ========================================================================

    {
        name = "Lakeshire",
        zone = "Redridge Mountains",
        subZone = "Lakeshire",
        faction = "Alliance",
        difficulty = "Easy",
        minPlayers = 2,
        recPlayers = "2-4",
        hideTime = 60,
        seekTime = 300,
        description = "Lakeside town. Inn, town hall, and buildings along the shore.",
        useSubZone = true,
        validSubZones = {"Lakeshire", "Lakeshire Inn", "Lakeshire Town Hall"},
        polygon = {},
    },
    {
        name = "Menethil Harbor",
        zone = "Wetlands",
        subZone = "Menethil Harbor",
        faction = "Alliance",
        difficulty = "Medium",
        minPlayers = 3,
        recPlayers = "3-5",
        hideTime = 60,
        seekTime = 420,
        description = "Port town with docks, Deepwater Tavern, and harbor buildings.",
        useSubZone = true,
        validSubZones = {"Menethil Harbor", "Deepwater Tavern", "Menethil Keep"},
        polygon = {},
    },
    {
        name = "Cathedral Square",
        zone = "Stormwind City",
        subZone = "Cathedral Square",
        faction = "Alliance",
        difficulty = "Medium",
        minPlayers = 3,
        recPlayers = "3-6",
        hideTime = 60,
        seekTime = 420,
        description = "City plaza with the grand cathedral interior, orphanage, and surrounding buildings.",
        useSubZone = true,
        validSubZones = {"Cathedral Square", "Cathedral of Light", "Stormwind City Cemetery"},
        polygon = {},
    },
    {
        name = "Theramore",
        zone = "Dustwallow Marsh",
        subZone = "Theramore Isle",
        faction = "Alliance",
        difficulty = "Hard",
        minPlayers = 4,
        recPlayers = "4-8",
        hideTime = 60,
        seekTime = 600,
        description = "Island fortress. Barracks, keep, inn, multiple buildings, guard patrols.",
        useSubZone = true,
        validSubZones = {"Theramore Isle", "Foothold Citadel"},
        polygon = {},
    },

    -- ========================================================================
    -- NEUTRAL
    -- ========================================================================

    {
        name = "Ratchet",
        zone = "The Barrens",
        subZone = "Ratchet",
        faction = "Neutral",
        difficulty = "Easy",
        minPlayers = 2,
        recPlayers = "2-4",
        hideTime = 60,
        seekTime = 300,
        description = "Small goblin port. Docks, bank, a handful of buildings.",
        useSubZone = true,
        validSubZones = {"Ratchet", "Broken Keel Tavern"},
        polygon = {},
    },
    {
        name = "Booty Bay",
        zone = "Stranglethorn Vale",
        subZone = "Booty Bay",
        faction = "Neutral",
        difficulty = "Hard",
        minPlayers = 4,
        recPlayers = "4-8",
        hideTime = 60,
        seekTime = 600,
        description = "Multi-level goblin port built into a cliff. Tons of NPCs, narrow walkways, multiple floors.",
        useSubZone = true,
        validSubZones = {"Booty Bay", "The Old Port Authority", "The Salty Sailor Tavern"},
        polygon = {},
    },
}

function HS.Presets.Get(name)
    for _, preset in ipairs(HS.Presets.Maps) do
        if preset.name == name then
            return preset
        end
    end
    if HideAndSeekDB and HideAndSeekDB.customPresets then
        return HideAndSeekDB.customPresets[name]
    end
    return nil
end

function HS.Presets.GetForFaction(faction)
    local results = {}
    for _, preset in ipairs(HS.Presets.Maps) do
        if preset.faction == "Neutral" or preset.faction == faction then
            table.insert(results, preset)
        end
    end
    if HideAndSeekDB and HideAndSeekDB.customPresets then
        for _, preset in pairs(HideAndSeekDB.customPresets) do
            table.insert(results, preset)
        end
    end
    return results
end

function HS.Presets.GetByDifficulty(difficulty)
    local results = {}
    for _, preset in ipairs(HS.Presets.Maps) do
        if preset.difficulty == difficulty then
            table.insert(results, preset)
        end
    end
    return results
end
