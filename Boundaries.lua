local HS = HideAndSeek

HS.Boundaries = {}

HS.Boundaries.active = nil
HS.Boundaries.mapID = nil
HS.Boundaries.setupMode = false
HS.Boundaries.setupPoints = {}
HS.Boundaries.isCustom = false
HS.Boundaries.useSubZone = false
HS.Boundaries.subZone = nil
HS.Boundaries.validSubZones = nil
HS.Boundaries.zoneName = nil

function HS.Boundaries.SetFromPreset(preset)
    HS.Boundaries.active = {}
    for _, point in ipairs(preset.polygon) do
        table.insert(HS.Boundaries.active, {x = point.x, y = point.y})
    end
    HS.Boundaries.isCustom = false
    HS.Boundaries.useSubZone = preset.useSubZone
    HS.Boundaries.subZone = preset.subZone
    HS.Boundaries.validSubZones = preset.validSubZones
    HS.Boundaries.zoneName = preset.zone
    HS.Boundaries.mapID = C_Map.GetBestMapForUnit("player")
    HS.Util.Print("Boundary set: " .. preset.name)
end

function HS.Boundaries.StartSetup()
    HS.Boundaries.setupMode = true
    HS.Boundaries.setupPoints = {}
    HS.Boundaries.mapID = C_Map.GetBestMapForUnit("player")
    HS.Boundaries.zoneName = GetZoneText()
    HS.Util.Print("Boundary setup started. Walk to each corner and type |cFFFFD100/has corner|r to mark it.")
    HS.Util.Print("Type |cFFFFD100/has done|r when finished (minimum 3 corners).")
end

function HS.Boundaries.AddCorner()
    if not HS.Boundaries.setupMode then
        HS.Util.Warn("Not in boundary setup mode. Use /has create Custom first.")
        return
    end

    local mapID, x, y = HS.Util.GetPlayerPosition()
    if not x or not y then
        HS.Util.Warn("Could not get your position.")
        return
    end

    table.insert(HS.Boundaries.setupPoints, {x = x, y = y})
    local count = #HS.Boundaries.setupPoints
    HS.Util.Print("Corner " .. count .. " set at (" .. string.format("%.3f, %.3f", x, y) .. ")")

    if HS.UI and HS.UI.UpdateMapSetup then
        HS.UI.UpdateMapSetup()
    end
end

function HS.Boundaries.FinishSetup()
    if not HS.Boundaries.setupMode then
        HS.Util.Warn("Not in boundary setup mode.")
        return
    end

    if #HS.Boundaries.setupPoints < 3 then
        HS.Util.Warn("Need at least 3 corners. You have " .. #HS.Boundaries.setupPoints .. ".")
        return
    end

    HS.Boundaries.active = {}
    for _, point in ipairs(HS.Boundaries.setupPoints) do
        table.insert(HS.Boundaries.active, {x = point.x, y = point.y})
    end
    HS.Boundaries.isCustom = true
    HS.Boundaries.useSubZone = false
    HS.Boundaries.setupMode = false

    HS.Util.Print("Custom boundary set with " .. #HS.Boundaries.active .. " corners in " .. (HS.Boundaries.zoneName or "unknown zone") .. ".")

    if HS.UI and HS.UI.UpdateMapSetup then
        HS.UI.UpdateMapSetup()
    end
end

local function IsValidSubZone(currentSubZone)
    if HS.Boundaries.validSubZones then
        for _, valid in ipairs(HS.Boundaries.validSubZones) do
            if currentSubZone == valid then return true end
        end
        return false
    end
    return currentSubZone == HS.Boundaries.subZone
end

function HS.Boundaries.CheckPlayer()
    if not HS.Boundaries.active then return true end

    if HS.Boundaries.zoneName and GetZoneText() ~= HS.Boundaries.zoneName then
        if HS.Boundaries.useSubZone and HS.Boundaries.subZone then
            return IsValidSubZone(GetSubZoneText())
        end
        return false
    end

    if HS.Boundaries.useSubZone and HS.Boundaries.subZone then
        return IsValidSubZone(GetSubZoneText())
    end

    local mapID, x, y = HS.Util.GetPlayerPosition()
    if not x or not y then return true end

    return HS.Util.PointInPolygon(x, y, HS.Boundaries.active)
end

function HS.Boundaries.Serialize()
    if not HS.Boundaries.active then return "" end

    local parts = {}
    for _, point in ipairs(HS.Boundaries.active) do
        table.insert(parts, string.format("%.4f:%.4f", point.x, point.y))
    end

    local validSZ = ""
    if HS.Boundaries.validSubZones then
        validSZ = table.concat(HS.Boundaries.validSubZones, ";")
    end

    local meta = (HS.Boundaries.zoneName or "") .. "|"
        .. (HS.Boundaries.subZone or "") .. "|"
        .. (HS.Boundaries.useSubZone and "1" or "0") .. "|"
        .. table.concat(parts, ",") .. "|"
        .. validSZ

    return meta
end

function HS.Boundaries.Deserialize(str)
    if not str or str == "" then return end

    local parts = HS.Util.Split(str, "|")
    if #parts < 4 then return end

    HS.Boundaries.zoneName = parts[1] ~= "" and parts[1] or nil
    HS.Boundaries.subZone = parts[2] ~= "" and parts[2] or nil
    HS.Boundaries.useSubZone = parts[3] == "1"
    HS.Boundaries.mapID = C_Map.GetBestMapForUnit("player")

    HS.Boundaries.active = {}
    local pointStrs = HS.Util.Split(parts[4], ",")
    for _, ps in ipairs(pointStrs) do
        local coords = HS.Util.Split(ps, ":")
        if #coords == 2 then
            table.insert(HS.Boundaries.active, {
                x = tonumber(coords[1]),
                y = tonumber(coords[2]),
            })
        end
    end

    if parts[5] and parts[5] ~= "" then
        HS.Boundaries.validSubZones = HS.Util.Split(parts[5], ";")
    else
        HS.Boundaries.validSubZones = nil
    end

    HS.Boundaries.isCustom = true
end

function HS.Boundaries.SaveCustomPreset(name)
    if not HS.Boundaries.active then
        HS.Util.Warn("No active boundary to save.")
        return
    end

    if not HideAndSeekDB then return end

    local preset = {
        name = name,
        zone = HS.Boundaries.zoneName or GetZoneText(),
        subZone = HS.Boundaries.subZone,
        faction = "Custom",
        polygon = {},
        useSubZone = HS.Boundaries.useSubZone or false,
        minPlayers = 2,
        recPlayers = "2-8",
        hideTime = 45,
        seekTime = 240,
        description = "Custom map",
        difficulty = "Custom",
    }

    for _, point in ipairs(HS.Boundaries.active) do
        table.insert(preset.polygon, {x = point.x, y = point.y})
    end

    HideAndSeekDB.customPresets[name] = preset
    HS.Util.Print("Custom preset '" .. name .. "' saved.")
end

function HS.Boundaries.Clear()
    HS.Boundaries.active = nil
    HS.Boundaries.mapID = nil
    HS.Boundaries.setupMode = false
    HS.Boundaries.setupPoints = {}
    HS.Boundaries.isCustom = false
    HS.Boundaries.useSubZone = false
    HS.Boundaries.subZone = nil
    HS.Boundaries.validSubZones = nil
    HS.Boundaries.zoneName = nil
end
