local HS = HideAndSeek

-- Update frame for timers
local ticker = CreateFrame("Frame")
local tickAccum = 0
local TICK = 0.1

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function HS.Init()
    if not HideAndSeekDB then
        HideAndSeekDB = {}
        for k, v in pairs(HS.DB_DEFAULTS) do
            if type(v) == "table" then
                HideAndSeekDB[k] = {}
                for k2, v2 in pairs(v) do HideAndSeekDB[k][k2] = v2 end
            else
                HideAndSeekDB[k] = v
            end
        end
    end
    -- Ensure sub-tables exist
    HideAndSeekDB.customPresets = HideAndSeekDB.customPresets or {}
    HideAndSeekDB.stats = HideAndSeekDB.stats or {}
    HideAndSeekDB.settings = HideAndSeekDB.settings or {soundEnabled = true}
    HideAndSeekDB.history = HideAndSeekDB.history or {}

    HS.Comm.Init()
    HS.UI.Init()

    SLASH_HIDEANDSEEK1 = "/has"
    SLASH_HIDEANDSEEK2 = "/hideandseek"
    SlashCmdList["HIDEANDSEEK"] = HS.SlashHandler

    HS.Util.Print("v" .. HS.VERSION .. " loaded. Type |cFFFFD100/has|r for commands.")
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

function HS.SlashHandler(msg)
    local cmd, arg = msg:match("^(%S+)%s*(.*)")
    cmd = (cmd or msg):lower()

    if cmd == "" or cmd == "help" then
        HS.Util.Print("Commands:")
        HS.Util.Print("  /has ui - Open the lobby")
        HS.Util.Print("  /has create [map] - Create a game")
        HS.Util.Print("  /has join - Join a game")
        HS.Util.Print("  /has start - Start the round (host)")
        HS.Util.Print("  /has cancel - Cancel the game (host)")
        HS.Util.Print("  /has corner - Mark a boundary corner")
        HS.Util.Print("  /has done - Finish boundary setup")
        HS.Util.Print("  /has save [name] - Save custom boundary")
        HS.Util.Print("  /has scores - Show scores")
        HS.Util.Print("  /has ready - Ready up while hiding (skip wait)")
        HS.Util.Print("  /has leave - Leave the game")
        HS.Util.Print("  /has stats - Show lifetime stats")
        HS.Util.Print("  /has test - Solo test (seeker view)")
        HS.Util.Print("  /has testfind - Simulate a find (test mode)")

    elseif cmd == "ui" or cmd == "open" or cmd == "show" then
        if HS.UI.lobby then
            if HS.UI.lobby:IsShown() then
                HS.UI.lobby:Hide()
            else
                HS.UI.ShowLobby()
            end
        end

    elseif cmd == "create" then
        if arg and arg ~= "" then
            local preset = HS.Presets.Get(arg)
            if preset then
                HS.Game.Create(preset.name, preset.hideTime, preset.seekTime)
            else
                HS.Util.Warn("Unknown map: " .. arg)
                local names = {}
                for _, p in ipairs(HS.Presets.Maps) do
                    table.insert(names, p.name)
                end
                HS.Util.Print("Available: " .. table.concat(names, ", "))
            end
        else
            HS.Game.Create("Custom", HS.DEFAULTS.hideTime, HS.DEFAULTS.seekTime)
        end

    elseif cmd == "join" then
        HS.Game.Join()

    elseif cmd == "start" then
        HS.Game.StartRound()

    elseif cmd == "cancel" or cmd == "stop" then
        HS.Game.Cancel()

    elseif cmd == "corner" or cmd == "mark" then
        HS.Boundaries.AddCorner()
        if HS.UI and HS.UI.UpdateMapSetup then HS.UI.UpdateMapSetup() end

    elseif cmd == "done" then
        HS.Boundaries.FinishSetup()

    elseif cmd == "save" then
        if arg == "" then
            HS.Util.Warn("Usage: /has save MyMapName")
        else
            HS.Boundaries.SaveCustomPreset(arg)
        end

    elseif cmd == "scores" or cmd == "score" then
        local state = HS.Game.state
        if next(state.players) then
            HS.Util.Print("Scores (Round " .. state.round .. "):")
            local sorted = {}
            for name, player in pairs(state.players) do
                table.insert(sorted, {name = name, score = player.score})
            end
            table.sort(sorted, function(a, b) return a.score > b.score end)
            for i, e in ipairs(sorted) do
                HS.Util.Print("  " .. i .. ". " .. e.name .. ": " .. e.score .. " pts")
            end
        else
            HS.Util.Print("No active game.")
        end

    elseif cmd == "leave" then
        local me = UnitName("player")
        if HS.Game.state.players[me] then
            HS.Comm.Send(HS.Comm.MSG.LEAVE, me)
            HS.Game.state.players[me] = nil
            HS.Game.RestoreUI()
            HS.Util.Print("You left the game.")
            HS.UI.HideAll()
        else
            HS.Util.Print("You're not in a game.")
        end

    elseif cmd == "history" then
        if HideAndSeekDB and HideAndSeekDB.history and #HideAndSeekDB.history > 0 then
            HS.Util.Print("Game History:")
            local startIdx = math.max(1, #HideAndSeekDB.history - 9)
            for i = #HideAndSeekDB.history, startIdx, -1 do
                local g = HideAndSeekDB.history[i]
                local playerList = {}
                for _, p in ipairs(g.players) do
                    table.insert(playerList, p.name .. ":" .. p.score)
                end
                HS.Util.Print("  " .. g.date .. " | " .. g.map .. " (" .. g.rounds .. " rds) | Winner: |cFFFFD100" .. g.winner .. "|r | " .. table.concat(playerList, ", "))
            end
        else
            HS.Util.Print("No game history yet.")
        end

    elseif cmd == "stats" then
        if HideAndSeekDB and HideAndSeekDB.stats then
            local s = HideAndSeekDB.stats
            HS.Util.Print("Lifetime Stats:")
            HS.Util.Print("  Games played: " .. (s.gamesPlayed or 0))
            HS.Util.Print("  Rounds as seeker: " .. (s.roundsAsSeeker or 0))
            HS.Util.Print("  Rounds as hider: " .. (s.roundsAsHider or 0))
            HS.Util.Print("  Found first: " .. (s.timesFoundFirst or 0))
            HS.Util.Print("  Found last: " .. (s.timesFoundLast or 0))
            HS.Util.Print("  Survived (not found): " .. (s.timesSurvivedRound or 0))
        end

    elseif cmd == "ready" then
        HS.Game.HiderReady()

    elseif cmd == "test" then
        HS.Game.TestStart()

    elseif cmd == "testfind" then
        HS.Game.TestFind()

    else
        HS.Util.Warn("Unknown command. Type /has help")
    end
end

-- ============================================================================
-- EVENTS
-- ============================================================================

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("CHAT_MSG_ADDON")
events:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("READY_CHECK")
events:RegisterEvent("READY_CHECK_CONFIRM")
events:RegisterEvent("READY_CHECK_FINISHED")
events:RegisterEvent("PLAYER_TARGET_CHANGED")

events:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "HideAndSeek" then
            HS.Init()
        end
        -- Detect reload during active game
        if name == "HideAndSeek" then
            local phase = HS.Game.state.phase
            if phase == HS.PHASE.HIDING or phase == HS.PHASE.SEEKING then
                HS.AntiCheat.OnReload()
            end
        end

    elseif event == "CHAT_MSG_ADDON" then
        HS.Comm.OnMessage(...)

    elseif event == "CHAT_MSG_TEXT_EMOTE" then
        local msg, sender = ...
        if not msg then return end
        -- Detect /point emote from the local player (seeker tagging)
        local me = UnitName("player")
        local short = sender and sender:match("([^-]+)") or ""
        if short == me and (msg:find("[Pp]oint") or msg:find("[Pp]OINT")) then
            HS.Game.TryTag()
        end

    elseif event == "GROUP_ROSTER_UPDATE" then
        if HS.UI and HS.UI.UpdateLobby then HS.UI.UpdateLobby() end
        local phase = HS.Game.state.phase
        if phase == HS.PHASE.HIDING or phase == HS.PHASE.SEEKING then
            HS.Game.HideRevealingFrames()
        end

    elseif event == "READY_CHECK" then
        if HS.Game._pendingStart then
            HS.Game._readyResponses = {}
            HS.Game._readyResponses[UnitName("player")] = true
        elseif HS.Game.state.phase == HS.PHASE.HIDING then
            HS.Game._hideReadyCheck = true
            HS.Game._readyResponses = {}
            HS.Game._readyResponses[UnitName("player")] = true
        end

    elseif event == "READY_CHECK_CONFIRM" then
        if HS.Game._pendingStart or HS.Game._hideReadyCheck then
            local unitID, isReady = ...
            local name = unitID and UnitName(unitID)
            if name then
                local short = name:match("([^-]+)") or name
                HS.Game._readyResponses[short] = isReady
            end
        end

    elseif event == "READY_CHECK_FINISHED" then
        if HS.Game._pendingStart then
            HS.Game.OnReadyCheckFinished()
        elseif HS.Game._hideReadyCheck then
            HS.Game.OnHideReadyCheckFinished()
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        local phase = HS.Game.state.phase
        if phase == HS.PHASE.HIDING or phase == HS.PHASE.SEEKING then
            HS.Game.HideRevealingFrames()
        end
        if phase == HS.PHASE.SEEKING then
            local me = UnitName("player")
            if HS.Game.state.seeker == me and UnitExists("target") then
                HS.Game.TryTag()
            end
        end

    elseif event == "PLAYER_LOGOUT" then
        HS.Game.RestoreUI()
    end
end)

-- ============================================================================
-- TICK (timers, anti-cheat, blindfold)
-- ============================================================================

ticker:SetScript("OnUpdate", function(self, elapsed)
    tickAccum = tickAccum + elapsed
    if tickAccum < TICK then return end
    tickAccum = 0

    HS.Game.OnUpdate()
    HS.AntiCheat.OnUpdate()

    -- Blindfold management
    local state = HS.Game.state
    local me = UnitName("player")

    if state.phase == HS.PHASE.HIDING and state.seeker == me then
        if HS.UI.blindfold and not HS.UI.blindfold:IsShown() then
            HS.UI.ShowBlindfold()
        end
    else
        if HS.UI.blindfold and HS.UI.blindfold:IsShown() then
            HS.UI.HideBlindfold()
        end
    end
end)
