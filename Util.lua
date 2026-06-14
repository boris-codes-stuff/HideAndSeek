local HS = HideAndSeek

HS.Util = {}

function HS.Util.PointInPolygon(px, py, polygon)
    local n = #polygon
    if n < 3 then return false end

    local inside = false
    local j = n

    for i = 1, n do
        local xi, yi = polygon[i].x, polygon[i].y
        local xj, yj = polygon[j].x, polygon[j].y

        if ((yi > py) ~= (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end

    return inside
end

function HS.Util.MapDistance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

function HS.Util.GetPlayerPosition()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil, nil, nil end

    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return mapID, nil, nil end

    return mapID, pos.x, pos.y
end

function HS.Util.IsInZone(zoneName)
    return GetZoneText() == zoneName or GetSubZoneText() == zoneName
end

function HS.Util.Split(str, sep)
    local parts = {}
    for part in str:gmatch("([^" .. sep .. "]+)") do
        table.insert(parts, part)
    end
    return parts
end

function HS.Util.FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function HS.Util.GetGroupMembers()
    local members = {}
    local name = UnitName("player")
    if name then members[name] = true end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local rName = UnitName("raid" .. i)
            if rName then members[rName] = true end
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() - 1 do
            local pName = UnitName("party" .. i)
            if pName then members[pName] = true end
        end
    end

    return members
end

function HS.Util.IsInTagRange(unit)
    return CheckInteractDistance(unit, HS.DEFAULTS.tagRange)
end

function HS.Util.GetCVarHash()
    local cvars = {
        GetCVar("nameplateShowFriends") or "0",
        GetCVar("nameplateShowEnemies") or "0",
        GetCVar("UnitNameNPC") or "0",
        GetCVar("UnitNameFriendlyPlayerName") or "0",
        GetCVar("UnitNameEnemyPlayerName") or "0",
    }
    return table.concat(cvars, "")
end

HS.Util.EXPECTED_CVAR_HASH = "00000"

function HS.Util.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100Hide&Seek|r: " .. msg)
end

function HS.Util.Warn(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF4444Hide&Seek|r: " .. msg)
end
