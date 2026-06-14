local HS = HideAndSeek

HS.AntiCheat = {}

local lastHeartbeat = 0

function HS.AntiCheat.OnUpdate()
    local state = HS.Game.state
    if state.phase ~= HS.PHASE.HIDING and state.phase ~= HS.PHASE.SEEKING then
        return
    end

    local now = GetTime()
    if now - lastHeartbeat >= HS.DEFAULTS.heartbeatInterval then
        lastHeartbeat = now
        HS.AntiCheat.SendHeartbeat()
        HS.AntiCheat.CheckHeartbeats()
    end
end

function HS.AntiCheat.SendHeartbeat()
    local playerName = UnitName("player")
    local cvarHash = HS.Util.GetCVarHash()
    HS.Comm.Send(HS.Comm.MSG.HB, playerName .. "|" .. cvarHash)
end

function HS.AntiCheat.CheckHeartbeats()
    local state = HS.Game.state
    local now = GetTime()
    local timeout = HS.DEFAULTS.heartbeatInterval * 3

    for name, player in pairs(state.players) do
        if player.lastHeartbeat and (now - player.lastHeartbeat) > timeout then
            HS.Util.Warn(name .. " stopped sending heartbeats (possible /reload or addon disabled).")
            HS.Comm.Send(HS.Comm.MSG.CHEAT, name .. "|no_heartbeat")
            player.lastHeartbeat = now
        end
    end
end

function HS.AntiCheat.OnReload()
    local state = HS.Game.state
    if state.phase == HS.PHASE.HIDING or state.phase == HS.PHASE.SEEKING then
        local playerName = UnitName("player")
        HS.Comm.Send(HS.Comm.MSG.CHEAT, playerName .. "|reloaded_ui")
        HS.Game.ApplyGameUI()
    end
end
