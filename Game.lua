local HS = HideAndSeek

HS.Game = {}

HS.Game.state = {
    phase = "IDLE",
    host = nil,
    seeker = nil,
    players = {},
    round = 0,
    foundCount = 0,
    totalHiders = 0,
    preset = nil,
    hideTime = 45,
    seekTime = 240,
    timer = 0,
    timerStart = 0,
    lastTagTime = 0,
    tagAttempts = 0,
    maxTagAttempts = 0,
    testMode = false,
    readyHiders = {},
}

local state = HS.Game.state

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

function HS.Game.Reset()
    state.phase = HS.PHASE.IDLE
    state.host = nil
    state.seeker = nil
    state.players = {}
    state.round = 0
    state.foundCount = 0
    state.totalHiders = 0
    state.preset = nil
    state.hideTime = HS.DEFAULTS.hideTime
    state.seekTime = HS.DEFAULTS.seekTime
    state.timer = 0
    state.timerStart = 0
    state.lastTagTime = 0
    state.tagAttempts = 0
    state.maxTagAttempts = 0
    state.testMode = false
    state.readyHiders = {}
    HS.Game.RestoreUI()
    HS.Boundaries.Clear()
end

-- ============================================================================
-- GAME CREATION & JOINING
-- ============================================================================

function HS.Game.Create(presetName, hideTime, seekTime)
    if state.phase ~= HS.PHASE.IDLE then
        HS.Util.Warn("A game is already in progress.")
        return
    end

    if not IsInGroup() then
        HS.Util.Warn("Not in a group. Game will work locally only until you party up.")
    end

    local playerName = UnitName("player")
    state.phase = HS.PHASE.LOBBY
    state.host = playerName
    state.round = 0
    state.preset = presetName or "Custom"

    state.players[playerName] = {
        role = HS.ROLE.NONE,
        score = 0,
        seekCount = 0,
        lastSeekRound = 0,
        foundOrder = 0,
        moveStrikes = 0,
    }

    if presetName and presetName ~= "Custom" then
        local preset = HS.Presets.Get(presetName)
        if preset then
            HS.Boundaries.SetFromPreset(preset)
            state.hideTime = preset.hideTime
            state.seekTime = preset.seekTime
        end
    else
        state.hideTime = hideTime or HS.DEFAULTS.hideTime
        state.seekTime = seekTime or HS.DEFAULTS.seekTime
    end

    HS.Comm.Send(HS.Comm.MSG.CREATE, playerName .. "|" .. state.preset .. "|" .. state.hideTime .. "|" .. state.seekTime)

    local boundaryStr = HS.Boundaries.Serialize()
    if boundaryStr ~= "" then
        HS.Comm.Send(HS.Comm.MSG.BOUNDARY, boundaryStr)
    end

    HS.Util.Print("Game created! Waiting for players to join.")
    HS.Util.Print("Other players need the addon installed. They type |cFFFFD100/has join|r")

    if HS.UI and HS.UI.ShowLobby then HS.UI.ShowLobby() end
end

function HS.Game.Join()
    if state.phase ~= HS.PHASE.LOBBY then
        HS.Util.Warn("No game lobby to join. Ask the host to /has create first.")
        return
    end

    local playerName = UnitName("player")
    if state.players[playerName] then
        HS.Util.Warn("You are already in the game.")
        return
    end

    state.players[playerName] = {
        role = HS.ROLE.NONE,
        score = 0,
        seekCount = 0,
        lastSeekRound = 0,
        foundOrder = 0,
        moveStrikes = 0,
    }

    HS.Comm.Send(HS.Comm.MSG.JOIN, playerName)
    HS.Util.Print("You joined the game!")

    if HS.UI and HS.UI.ShowLobby then HS.UI.ShowLobby() end
end

-- ============================================================================
-- ROUND MANAGEMENT
-- ============================================================================

function HS.Game.StartRound()
    if state.phase ~= HS.PHASE.LOBBY and state.phase ~= HS.PHASE.ROUND_END then
        HS.Util.Warn("Cannot start round in current phase.")
        return
    end

    if HS.Game._pendingStart then
        HS.Util.Warn("Ready check already in progress.")
        return
    end

    local playerName = UnitName("player")
    if state.host ~= playerName then
        HS.Util.Warn("Only the host can start rounds.")
        return
    end

    local playerCount = 0
    for _ in pairs(state.players) do playerCount = playerCount + 1 end

    if playerCount < 2 then
        HS.Util.Warn("Only " .. playerCount .. " player. Need at least 2 to start a round.")
        return
    end

    if state.preset and state.preset ~= "Custom" then
        local preset = HS.Presets.Get(state.preset)
        if preset and playerCount < preset.minPlayers then
            HS.Util.Warn(state.preset .. " recommends at least " .. preset.minPlayers .. " players. You have " .. playerCount .. ". Starting anyway.")
        end
    end

    if IsInGroup() then
        if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
            HS.Game._pendingStart = true
            HS.Game._readyResponses = {}
            HS.Game._readyResponses[playerName] = true
            DoReadyCheck()
        else
            HS.Util.Warn("You need to be party leader to start. Ask for lead or type /promote " .. playerName)
        end
    else
        HS.Game.StartCountdown()
    end
end

function HS.Game.OnHideReadyCheckFinished()
    HS.Game._hideReadyCheck = false
    if state.phase ~= HS.PHASE.HIDING then return end

    local allReady = true
    for name, _ in pairs(state.players) do
        if not HS.Game._readyResponses[name] then
            allReady = false
            break
        end
    end

    if allReady then
        HS.Util.Print("All players ready! Seeking starts now!")
        if state.host == UnitName("player") then
            HS.Game.StartSeeking()
        end
    else
        HS.Util.Print("Not all players ready. Hiding continues.")
    end
end

function HS.Game.OnReadyCheckFinished()
    if not HS.Game._pendingStart then return end
    HS.Game._pendingStart = false

    local allReady = true
    for name, _ in pairs(state.players) do
        if not HS.Game._readyResponses[name] then
            allReady = false
            break
        end
    end

    if allReady then
        HS.Game.StartCountdown()
    else
        HS.Util.Warn("Ready check failed. Not all players accepted.")
    end
end

function HS.Game.StartCountdown()
    state.round = state.round + 1
    state.seeker = HS.Game.SelectSeeker()
    state.foundCount = 0
    state.totalHiders = 0

    for name, player in pairs(state.players) do
        if name == state.seeker then
            player.role = HS.ROLE.SEEKER
        else
            player.role = HS.ROLE.HIDER
            player.foundOrder = 0
            player.frozenX = nil
            player.frozenY = nil
            player.moveStrikes = 0
            state.totalHiders = state.totalHiders + 1
        end
    end

    state.phase = HS.PHASE.COUNTDOWN
    state.timer = HS.DEFAULTS.preGameCountdown
    state.timerStart = GetTime()

    HS.Comm.Send(HS.Comm.MSG.COUNTDOWN, state.seeker .. "|" .. HS.DEFAULTS.preGameCountdown)

    HS.Util.Print("Round " .. state.round .. "! " .. state.seeker .. " is seeking!")
    HS.Util.Print("Game starts in " .. HS.DEFAULTS.preGameCountdown .. " seconds!")

    if HideAndSeekDB and HideAndSeekDB.settings.soundEnabled then
        PlaySound(HS.SOUNDS.roundStart)
    end

    if HS.UI then
        if HS.UI.ShowPreGameCountdown then HS.UI.ShowPreGameCountdown(state.seeker) end
        if HS.UI.HideLobby then HS.UI.HideLobby() end
        if HS.UI.HideScoreboard then HS.UI.HideScoreboard() end
    end
end

function HS.Game.StartHiding()
    state.phase = HS.PHASE.HIDING
    state.timer = state.hideTime
    state.timerStart = GetTime()
    state.readyHiders = {}

    HS.Comm.Send(HS.Comm.MSG.START_HIDE, state.seeker .. "|" .. state.hideTime)
    HS.Game.ApplyGameUI()

    HS.Util.Print("HIDE! " .. state.seeker .. " is blindfolded for " .. state.hideTime .. "s!")
    HS.Util.Print("Hiders: type |cFFFFD100/has ready|r when you're hidden to skip the wait.")

    if HS.UI then
        if HS.UI.HidePreGameCountdown then HS.UI.HidePreGameCountdown() end
        if HS.UI.ShowHUD then HS.UI.ShowHUD() end
    end
end

function HS.Game.HiderReady()
    if state.phase ~= HS.PHASE.HIDING then
        HS.Util.Warn("Can only ready up during the hiding phase.")
        return
    end

    local playerName = UnitName("player")
    if not state.players[playerName] or state.players[playerName].role ~= HS.ROLE.HIDER then
        HS.Util.Warn("Only hiders can ready up.")
        return
    end

    if state.readyHiders[playerName] then
        HS.Util.Warn("You're already ready.")
        return
    end

    state.readyHiders[playerName] = true
    HS.Comm.Send(HS.Comm.MSG.READY, playerName)
    HS.Util.Print("You're ready! Waiting for other hiders...")
    HS.Game.CheckAllReady()
end

function HS.Game.CheckAllReady()
    local readyCount = 0
    for _ in pairs(state.readyHiders) do readyCount = readyCount + 1 end

    if readyCount >= state.totalHiders then
        HS.Util.Print("|cFF00FF00All hiders ready! Seeking starts now!|r")
        if state.host == UnitName("player") then
            HS.Game.StartSeeking()
        end
    else
        HS.Util.Print(readyCount .. "/" .. state.totalHiders .. " hiders ready.")
    end
end

-- ============================================================================
-- SEEKER SELECTION
-- ============================================================================

function HS.Game.SelectSeeker()
    if state.round == 1 then
        local names = {}
        for name, _ in pairs(state.players) do
            table.insert(names, name)
        end
        return names[math.random(#names)]
    end

    local candidates = {}
    local lowestScore = math.huge

    for name, player in pairs(state.players) do
        local consecutive = 0
        if state.seeker == name and player.lastSeekRound == state.round - 1 then
            consecutive = player.seekCount
        end

        if consecutive < HS.DEFAULTS.maxConsecutiveSeeks then
            table.insert(candidates, {
                name = name,
                score = player.score,
                lastSeekRound = player.lastSeekRound,
                seekCount = player.seekCount,
            })
            if player.score < lowestScore then
                lowestScore = player.score
            end
        end
    end

    -- Safety: if everyone is capped, allow all
    if #candidates == 0 then
        for name, player in pairs(state.players) do
            table.insert(candidates, {
                name = name,
                score = player.score,
                lastSeekRound = player.lastSeekRound,
            })
            if player.score < lowestScore then
                lowestScore = player.score
            end
        end
    end

    -- Lowest score candidates
    local tied = {}
    for _, c in ipairs(candidates) do
        if c.score == lowestScore then
            table.insert(tied, c)
        end
    end

    -- Tie-break: least recently seeked
    table.sort(tied, function(a, b) return a.lastSeekRound < b.lastSeekRound end)

    local selected = tied[1].name

    if state.players[selected] then
        state.players[selected].seekCount = (state.players[selected].seekCount or 0) + 1
        state.players[selected].lastSeekRound = state.round
    end

    return selected
end

function HS.Game.PeekNextSeeker()
    local candidates = {}
    local lowestScore = math.huge

    for name, player in pairs(state.players) do
        local skip = false
        if state.seeker == name and player.seekCount >= HS.DEFAULTS.maxConsecutiveSeeks then
            skip = true
        end

        if not skip then
            table.insert(candidates, {name = name, score = player.score, lastSeekRound = player.lastSeekRound})
            if player.score < lowestScore then lowestScore = player.score end
        end
    end

    if #candidates == 0 then return state.host end

    local tied = {}
    for _, c in ipairs(candidates) do
        if c.score == lowestScore then table.insert(tied, c) end
    end

    table.sort(tied, function(a, b) return a.lastSeekRound < b.lastSeekRound end)
    return tied[1].name
end

-- ============================================================================
-- UI CONTROL (CVars)
-- ============================================================================

function HS.Game.ApplyGameUI()
    if not HS.Game.originalCVars then
        HS.Game.originalCVars = {
            nameplateShowFriends = GetCVar("nameplateShowFriends"),
            nameplateShowEnemies = GetCVar("nameplateShowEnemies"),
            UnitNameNPC = GetCVar("UnitNameNPC"),
            UnitNameFriendlyPlayerName = GetCVar("UnitNameFriendlyPlayerName"),
            UnitNameEnemyPlayerName = GetCVar("UnitNameEnemyPlayerName"),
            UnitNameFriendlyPetName = GetCVar("UnitNameFriendlyPetName"),
            UnitNameFriendlyGuardianName = GetCVar("UnitNameFriendlyGuardianName"),
        }
    end

    SetCVar("nameplateShowFriends", 0)
    SetCVar("nameplateShowEnemies", 0)
    SetCVar("UnitNameNPC", 0)
    SetCVar("UnitNameFriendlyPlayerName", 0)
    SetCVar("UnitNameEnemyPlayerName", 0)
    SetCVar("UnitNameFriendlyPetName", 0)
    SetCVar("UnitNameFriendlyGuardianName", 0)

    if MinimapCluster then MinimapCluster:Hide() end
    for i = 1, 4 do
        local frame = _G["PartyMemberFrame" .. i]
        if frame then frame:Hide() end
    end
    if CompactRaidFrameManager then CompactRaidFrameManager:Hide() end
    if CompactRaidFrameContainer then CompactRaidFrameContainer:Hide() end
    if TargetFrame then TargetFrame:SetAlpha(0); TargetFrame:EnableMouse(false) end
    if TargetFrameToT then TargetFrameToT:SetAlpha(0) end

    if not HS.Game.bindFrame then
        HS.Game.bindFrame = CreateFrame("Frame", "HASBindFrame", UIParent)
        CreateFrame("Button", "HAS_DummyBtn", UIParent)
    end
    for i = 1, 5 do
        SetOverrideBindingClick(HS.Game.bindFrame, true, "F" .. i, "HAS_DummyBtn")
    end
end

function HS.Game.RestoreUI()
    if HS.Game.originalCVars then
        for cvar, value in pairs(HS.Game.originalCVars) do
            SetCVar(cvar, value)
        end
        HS.Game.originalCVars = nil
    end

    if MinimapCluster then MinimapCluster:Show() end
    for i = 1, 4 do
        local frame = _G["PartyMemberFrame" .. i]
        if frame then frame:Show() end
    end
    if CompactRaidFrameManager then CompactRaidFrameManager:Show() end
    if CompactRaidFrameContainer then CompactRaidFrameContainer:Show() end
    if TargetFrame then TargetFrame:SetAlpha(1); TargetFrame:EnableMouse(true) end
    if TargetFrameToT then TargetFrameToT:SetAlpha(1) end

    if HS.Game.bindFrame then
        ClearOverrideBindings(HS.Game.bindFrame)
    end
end

function HS.Game.HideRevealingFrames()
    if MinimapCluster then MinimapCluster:Hide() end
    for i = 1, 4 do
        local frame = _G["PartyMemberFrame" .. i]
        if frame then frame:Hide() end
    end
    if CompactRaidFrameManager then CompactRaidFrameManager:Hide() end
    if CompactRaidFrameContainer then CompactRaidFrameContainer:Hide() end
    if TargetFrame then TargetFrame:SetAlpha(0); TargetFrame:EnableMouse(false) end
    if TargetFrameToT then TargetFrameToT:SetAlpha(0) end
end

-- ============================================================================
-- PHASE TRANSITIONS
-- ============================================================================

function HS.Game.StartSeeking()
    state.phase = HS.PHASE.SEEKING
    state.timer = state.seekTime
    state.timerStart = GetTime()
    state.lastTagTime = 0
    state.tagAttempts = 0
    state.maxTagAttempts = state.totalHiders * HS.DEFAULTS.tagAttemptsPerHider

    -- Freeze hider positions
    local playerName = UnitName("player")
    if state.players[playerName] and state.players[playerName].role == HS.ROLE.HIDER then
        local _, px, py = HS.Util.GetPlayerPosition()
        state.players[playerName].frozenX = px
        state.players[playerName].frozenY = py
        if px and py then
            HS.Comm.Send(HS.Comm.MSG.FREEZE_POS, playerName .. "|" .. string.format("%.4f", px) .. "|" .. string.format("%.4f", py))
        end
    end

    if state.host == playerName then
        HS.Comm.Send(HS.Comm.MSG.START_SEEK, tostring(state.seekTime))
    end

    HS.Util.Print("Seeking phase! " .. state.seeker .. " is now searching!")

    if playerName == state.seeker and HideAndSeekDB and HideAndSeekDB.settings.soundEnabled then
        PlaySoundFile(HS.SOUNDS.seekStartFile, "Master")
    end

    if HS.UI then
        if HS.UI.HideBlindfold then HS.UI.HideBlindfold() end
        if HS.UI.UpdateHUD then HS.UI.UpdateHUD() end
    end
end

-- ============================================================================
-- TAGGING (FINDING PLAYERS)
-- ============================================================================

function HS.Game.TryTag()
    local playerName = UnitName("player")

    if state.phase ~= HS.PHASE.SEEKING or state.seeker ~= playerName then
        return
    end

    local now = GetTime()
    if now - state.lastTagTime < HS.DEFAULTS.tagCooldown then
        local remaining = math.ceil(HS.DEFAULTS.tagCooldown - (now - state.lastTagTime))
        HS.Util.Warn("Tag on cooldown: " .. remaining .. "s remaining.")
        return
    end

    if state.maxTagAttempts > 0 and state.tagAttempts >= state.maxTagAttempts then
        HS.Util.Warn("No guesses left! Wait for the timer to end.")
        return
    end

    state.lastTagTime = now

    -- No target: no guess consumed
    if not UnitExists("target") then
        HS.Util.Warn("No target! Select a player first.")
        return
    end

    -- NPC: guess consumed + buzzer
    if not UnitIsPlayer("target") and not state.testMode then
        state.tagAttempts = state.tagAttempts + 1
        local attemptsLeft = state.maxTagAttempts - state.tagAttempts
        PlaySoundFile(HS.SOUNDS.buzzerFile, "Master")
        HS.Util.Warn("That's an NPC! (" .. attemptsLeft .. " guesses left)")
        if HS.UI and HS.UI.UpdateHUD then HS.UI.UpdateHUD() end
        return
    end

    -- Too far: NO guess consumed + error feedback
    if not HS.Util.IsInTagRange("target") then
        UIErrorsFrame:AddMessage("Too far away!", 1, 0.1, 0.1)
        HS.Util.Warn("Get closer! No guess used.")
        return
    end

    -- From here, guess IS consumed
    state.tagAttempts = state.tagAttempts + 1
    local attemptsLeft = state.maxTagAttempts - state.tagAttempts

    local targetName = UnitName("target")

    if not state.players[targetName] then
        PlaySoundFile(HS.SOUNDS.buzzerFile, "Master")
        HS.Util.Warn(targetName .. " is not in this game. (" .. attemptsLeft .. " guesses left)")
        if HS.UI and HS.UI.UpdateHUD then HS.UI.UpdateHUD() end
        return
    end

    if state.players[targetName].role == HS.ROLE.FOUND then
        -- Refund: already found players have a raid icon, obvious mistake
        state.tagAttempts = state.tagAttempts - 1
        HS.Util.Warn(targetName .. " was already found.")
        return
    end

    if state.players[targetName].role ~= HS.ROLE.HIDER then
        if HS.UI and HS.UI.UpdateHUD then HS.UI.UpdateHUD() end
        return
    end

    HS.Game.ProcessFind(targetName)
    if HS.UI and HS.UI.UpdateHUD then HS.UI.UpdateHUD() end
end

function HS.Game.ProcessFind(hiderName)
    state.foundCount = state.foundCount + 1
    local order = state.foundCount

    state.players[hiderName].role = HS.ROLE.FOUND
    state.players[hiderName].foundOrder = order

    -- Hider points: order-based (1st found = 1pt, 2nd = 2pts, etc.)
    state.players[hiderName].score = state.players[hiderName].score + order

    -- Seeker points: flat per find
    if state.players[state.seeker] then
        state.players[state.seeker].score = state.players[state.seeker].score + HS.DEFAULTS.seekerPointsPerFind
    end

    -- Raid marker on found player
    local icon = HS.FOUND_ICONS[order] or 8
    SetRaidTarget("target", icon)

    local isLastFind = state.foundCount >= state.totalHiders

    if HideAndSeekDB and HideAndSeekDB.settings.soundEnabled and not isLastFind then
        PlaySoundFile(HS.SOUNDS.foundFiles[math.random(#HS.SOUNDS.foundFiles)], "Master")
    end

    HS.Comm.Send(HS.Comm.MSG.FOUND, state.seeker .. "|" .. hiderName .. "|" .. order .. "|" .. state.totalHiders)
    HS.Util.Print("|cFF00CC00" .. state.seeker .. " found " .. hiderName .. "!|r (" .. order .. "/" .. state.totalHiders .. ")")

    if isLastFind then
        HS.Game.EndRound(true)
    end

    if HS.UI and HS.UI.UpdateHUD then HS.UI.UpdateHUD() end
end

-- ============================================================================
-- ROUND & GAME END
-- ============================================================================

function HS.Game.EndRound(allFound)
    state.phase = HS.PHASE.ROUND_END

    -- Bonus for unfound hiders
    if not allFound then
        for name, player in pairs(state.players) do
            if player.role == HS.ROLE.HIDER then
                player.score = player.score + state.totalHiders + 1
            end
        end
    end

    HS.Game.RestoreUI()

    local playerName = UnitName("player")
    if state.host == playerName then
        local scoreParts = {}
        for name, player in pairs(state.players) do
            table.insert(scoreParts, name .. ":" .. player.score)
        end
        HS.Comm.Send(HS.Comm.MSG.ROUND_END, table.concat(scoreParts, ","))
    end

    if allFound then
        HS.Util.Print("Round " .. state.round .. " complete! All hiders found!")
    else
        HS.Util.Print("Round " .. state.round .. " complete! Time ran out!")
    end

    -- Win sound: seeker found everyone, or hider survived
    local me = state.players[playerName]
    if me and HideAndSeekDB and HideAndSeekDB.settings.soundEnabled then
        if allFound and me.role == HS.ROLE.SEEKER then
            PlaySoundFile(HS.SOUNDS.winFiles[math.random(#HS.SOUNDS.winFiles)], "Master")
        elseif not allFound and me.role == HS.ROLE.HIDER then
            PlaySoundFile(HS.SOUNDS.winFiles[math.random(#HS.SOUNDS.winFiles)], "Master")
        elseif not allFound and me.role == HS.ROLE.SEEKER then
            PlaySoundFile(HS.SOUNDS.loseFile, "Master")
        end
    end

    local nextSeeker = HS.Game.PeekNextSeeker()
    HS.Util.Print("Next seeker: |cFFFF4444" .. nextSeeker .. "|r")

    -- Stats
    if HideAndSeekDB then
        local me = state.players[playerName]
        if me then
            if me.role == HS.ROLE.SEEKER then
                HideAndSeekDB.stats.roundsAsSeeker = (HideAndSeekDB.stats.roundsAsSeeker or 0) + 1
            else
                HideAndSeekDB.stats.roundsAsHider = (HideAndSeekDB.stats.roundsAsHider or 0) + 1
                if me.role == HS.ROLE.HIDER then
                    HideAndSeekDB.stats.timesSurvivedRound = (HideAndSeekDB.stats.timesSurvivedRound or 0) + 1
                elseif me.foundOrder == 1 then
                    HideAndSeekDB.stats.timesFoundFirst = (HideAndSeekDB.stats.timesFoundFirst or 0) + 1
                elseif me.foundOrder == state.totalHiders then
                    HideAndSeekDB.stats.timesFoundLast = (HideAndSeekDB.stats.timesFoundLast or 0) + 1
                end
            end
        end
    end

    if HS.UI and HS.UI.ShowScoreboard then HS.UI.ShowScoreboard() end
end

function HS.Game.EndGame()
    state.phase = HS.PHASE.GAME_END

    local playerName = UnitName("player")
    if state.host == playerName then
        local scoreParts = {}
        for name, player in pairs(state.players) do
            table.insert(scoreParts, name .. ":" .. player.score)
        end
        HS.Comm.Send(HS.Comm.MSG.GAME_END, table.concat(scoreParts, ","))
    end

    if HideAndSeekDB then
        HideAndSeekDB.stats.gamesPlayed = (HideAndSeekDB.stats.gamesPlayed or 0) + 1

        HideAndSeekDB.history = HideAndSeekDB.history or {}
        local entry = {
            date = date("%Y-%m-%d %H:%M"),
            map = state.preset or "Custom",
            rounds = state.round,
            players = {},
        }
        local sorted = {}
        for name, player in pairs(state.players) do
            table.insert(sorted, {name = name, score = player.score})
        end
        table.sort(sorted, function(a, b) return a.score > b.score end)
        for _, p in ipairs(sorted) do
            table.insert(entry.players, {name = p.name, score = p.score})
        end
        entry.winner = sorted[1] and sorted[1].name or "Unknown"
        table.insert(HideAndSeekDB.history, entry)
    end

    HS.Util.Print("Game over! Final scores:")
    local sorted = {}
    for name, player in pairs(state.players) do
        table.insert(sorted, {name = name, score = player.score})
    end
    table.sort(sorted, function(a, b) return a.score > b.score end)
    for i, entry in ipairs(sorted) do
        HS.Util.Print("  " .. i .. ". " .. entry.name .. ": " .. entry.score .. " pts")
    end

    HS.Game.RestoreUI()
    if HS.UI and HS.UI.ShowScoreboard then HS.UI.ShowScoreboard(true) end
end

function HS.Game.Cancel()
    local playerName = UnitName("player")
    if state.host == playerName then
        HS.Comm.Send(HS.Comm.MSG.CANCEL, "")
    end
    HS.Util.Print("Game cancelled.")
    HS.Game.Reset()
    if HS.UI and HS.UI.HideAll then HS.UI.HideAll() end
end

-- ============================================================================
-- TEST MODE (solo testing)
-- ============================================================================

function HS.Game.TestStart()
    HS.Game.Reset()

    local playerName = UnitName("player")
    state.phase = HS.PHASE.LOBBY
    state.host = playerName
    state.preset = "Test Mode"
    state.hideTime = 10
    state.seekTime = 120
    state.round = 0

    state.players[playerName] = {
        role = HS.ROLE.NONE, score = 0, seekCount = 0,
        lastSeekRound = 0, foundOrder = 0, moveStrikes = 0,
    }
    state.players["Scout Tharr"] = {
        role = HS.ROLE.NONE, score = 0, seekCount = 0,
        lastSeekRound = 0, foundOrder = 0, moveStrikes = 0,
    }

    state.round = 1
    state.seeker = playerName
    state.foundCount = 0
    state.totalHiders = 1
    state.players[playerName].role = HS.ROLE.SEEKER
    state.players["Scout Tharr"].role = HS.ROLE.HIDER

    state.phase = HS.PHASE.COUNTDOWN
    state.timer = HS.DEFAULTS.preGameCountdown
    state.timerStart = GetTime()

    state.testMode = true

    HS.Util.Print("|cFF00FF00TEST MODE|r - You are the seeker.")
    HS.Util.Print("10s countdown > 10s blindfold > 2min seeking")
    HS.Util.Print("Target |cFFFFD100Scout Tharr|r and /point to test a find.")
    HS.Util.Print("Use |cFFFFD100/has cancel|r to stop.")

    if HideAndSeekDB and HideAndSeekDB.settings.soundEnabled then
        PlaySound(HS.SOUNDS.roundStart)
    end

    if HS.UI then
        if HS.UI.ShowPreGameCountdown then HS.UI.ShowPreGameCountdown(playerName) end
        if HS.UI.HideLobby then HS.UI.HideLobby() end
    end
end

function HS.Game.TestFind()
    if state.phase ~= HS.PHASE.SEEKING then
        HS.Util.Warn("Not in seeking phase yet. Wait for the blindfold to end.")
        return
    end
    if not state.players["Scout Tharr"] or state.players["Scout Tharr"].role ~= HS.ROLE.HIDER then
        HS.Util.Warn("TestHider already found.")
        return
    end

    state.foundCount = state.foundCount + 1
    local order = state.foundCount

    state.players["Scout Tharr"].role = HS.ROLE.FOUND
    state.players["Scout Tharr"].foundOrder = order
    state.players["Scout Tharr"].score = state.players["Scout Tharr"].score + order

    if state.players[state.seeker] then
        state.players[state.seeker].score = state.players[state.seeker].score + HS.DEFAULTS.seekerPointsPerFind
    end

    if HideAndSeekDB and HideAndSeekDB.settings.soundEnabled then
        PlaySoundFile(HS.SOUNDS.foundFiles[math.random(#HS.SOUNDS.foundFiles)], "Master")
    end

    HS.Util.Print("|cFF00CC00Found TestHider!|r (" .. order .. "/" .. state.totalHiders .. ")")

    if state.foundCount >= state.totalHiders then
        HS.Game.EndRound(true)
    end

    if HS.UI and HS.UI.UpdateHUD then HS.UI.UpdateHUD() end
end

-- ============================================================================
-- TICK (called every 100ms)
-- ============================================================================

function HS.Game.OnUpdate()
    if state.phase == HS.PHASE.COUNTDOWN then
        local elapsed = GetTime() - state.timerStart
        local remaining = state.timer - elapsed
        if remaining <= 0 then
            if state.host == UnitName("player") then
                HS.Game.StartHiding()
            end
            if HS.UI and HS.UI.UpdatePreGameCountdown then
                HS.UI.UpdatePreGameCountdown(0)
            end
        else
            if HS.UI and HS.UI.UpdatePreGameCountdown then
                HS.UI.UpdatePreGameCountdown(remaining)
            end
        end
        return
    end

    if state.phase ~= HS.PHASE.HIDING and state.phase ~= HS.PHASE.SEEKING then
        return
    end

    local elapsed = GetTime() - state.timerStart
    local remaining = state.timer - elapsed

    if remaining <= 0 then
        if state.phase == HS.PHASE.HIDING then
            HS.Game.StartSeeking()
        elseif state.phase == HS.PHASE.SEEKING then
            HS.Game.EndRound(false)
        end
        return
    end

    if HS.UI and HS.UI.UpdateTimer then
        HS.UI.UpdateTimer(remaining, state.phase)
    end

    -- Boundary check (every 1s)
    if not HS.Game._lastBoundaryCheck then HS.Game._lastBoundaryCheck = 0 end
    if GetTime() - HS.Game._lastBoundaryCheck >= HS.DEFAULTS.boundaryCheckInterval then
        HS.Game._lastBoundaryCheck = GetTime()
        HS.Game.CheckBoundary()
    end

    -- Movement check for frozen hiders (every 2s)
    if state.phase == HS.PHASE.SEEKING then
        if not HS.Game._lastMoveCheck then HS.Game._lastMoveCheck = 0 end
        if GetTime() - HS.Game._lastMoveCheck >= 2 then
            HS.Game._lastMoveCheck = GetTime()
            HS.Game.CheckMovement()
        end
    end
end

function HS.Game.CheckBoundary()
    if not HS.Boundaries.active then return end

    local inBounds = HS.Boundaries.CheckPlayer()
    local playerName = UnitName("player")

    if not inBounds then
        if not HS.Game._oobStart then
            HS.Game._oobStart = GetTime()
        end
        local oobTime = GetTime() - HS.Game._oobStart
        if HS.UI and HS.UI.ShowBoundaryWarning then
            HS.UI.ShowBoundaryWarning(true, oobTime)
        end
        if oobTime >= HS.DEFAULTS.outOfBoundsGrace then
            HS.Comm.Send(HS.Comm.MSG.OOB, playerName)
            HS.Game._oobStart = GetTime() -- reset to avoid spam
        end
    else
        HS.Game._oobStart = nil
        if HS.UI and HS.UI.ShowBoundaryWarning then
            HS.UI.ShowBoundaryWarning(false)
        end
    end
end

function HS.Game.CheckMovement()
    local playerName = UnitName("player")
    local player = state.players[playerName]
    if not player or player.role ~= HS.ROLE.HIDER then return end
    if not player.frozenX or not player.frozenY then return end

    local _, x, y = HS.Util.GetPlayerPosition()
    if not x or not y then return end

    local dist = HS.Util.MapDistance(x, y, player.frozenX, player.frozenY)
    if dist > HS.DEFAULTS.moveThreshold then
        player.moveStrikes = (player.moveStrikes or 0) + 1
        local maxStrikes = HS.DEFAULTS.moveStrikes

        if player.moveStrikes >= maxStrikes then
            HS.Util.Warn("Strike " .. player.moveStrikes .. "/" .. maxStrikes .. "! Auto-found for moving!")
            HS.Comm.Send(HS.Comm.MSG.MOVED, playerName .. "|" .. player.moveStrikes)
            HS.Game.ProcessAutoFound(playerName)
        else
            HS.Util.Warn("Strike " .. player.moveStrikes .. "/" .. maxStrikes .. "! Stop moving!")
            HS.Comm.Send(HS.Comm.MSG.MOVED, playerName .. "|" .. player.moveStrikes)
        end
    end
end

function HS.Game.ProcessAutoFound(hiderName)
    state.foundCount = state.foundCount + 1
    local order = state.foundCount

    state.players[hiderName].role = HS.ROLE.FOUND
    state.players[hiderName].foundOrder = order
    state.players[hiderName].score = state.players[hiderName].score + order

    if state.players[state.seeker] then
        state.players[state.seeker].score = state.players[state.seeker].score + HS.DEFAULTS.seekerPointsPerFind
    end

    local isLastFind = state.foundCount >= state.totalHiders

    if HideAndSeekDB and HideAndSeekDB.settings.soundEnabled and not isLastFind then
        PlaySoundFile(HS.SOUNDS.foundFiles[math.random(#HS.SOUNDS.foundFiles)], "Master")
    end

    HS.Comm.Send(HS.Comm.MSG.FOUND, state.seeker .. "|" .. hiderName .. "|" .. order .. "|" .. state.totalHiders)
    HS.Util.Print("|cFFFF8800" .. hiderName .. " auto-found for moving!|r (" .. order .. "/" .. state.totalHiders .. ")")

    if isLastFind then
        HS.Game.EndRound(true)
    end

    if HS.UI and HS.UI.UpdateHUD then HS.UI.UpdateHUD() end
end

-- ============================================================================
-- MESSAGE HANDLERS
-- ============================================================================

HS.Comm.handlers[HS.Comm.MSG.CREATE] = function(sender, data)
    local parts = HS.Util.Split(data, "|")
    if #parts < 4 then return end

    state.phase = HS.PHASE.LOBBY
    state.host = parts[1]
    state.preset = parts[2]
    state.hideTime = tonumber(parts[3])
    state.seekTime = tonumber(parts[4])
    state.round = 0
    state.players = {}

    state.players[state.host] = {
        role = HS.ROLE.NONE, score = 0, seekCount = 0,
        lastSeekRound = 0, foundOrder = 0, moveStrikes = 0,
    }

    local playerName = UnitName("player")
    if playerName ~= state.host then
        -- Look up difficulty for the popup
        local difficulty = nil
        local preset = HS.Presets.Get(state.preset)
        if preset then difficulty = preset.difficulty end

        if HS.UI and HS.UI.ShowInvitePopup then
            HS.UI.ShowInvitePopup(state.host, state.preset, difficulty)
        end
        HS.Util.Print(state.host .. " invited you to Hide&Seek! |cFFFFD100/has join|r to play.")
    end

    if HS.UI and HS.UI.ShowLobby then HS.UI.ShowLobby() end
end

HS.Comm.handlers[HS.Comm.MSG.JOIN] = function(sender, data)
    local name = data
    if not state.players[name] then
        state.players[name] = {
            role = HS.ROLE.NONE, score = 0, seekCount = 0,
            lastSeekRound = 0, foundOrder = 0, moveStrikes = 0,
        }
    end
    local playerName = UnitName("player")
    if name ~= playerName then
        HS.Util.Print(name .. " joined the game!")
    end
    if HS.UI and HS.UI.UpdateLobby then HS.UI.UpdateLobby() end
end

HS.Comm.handlers[HS.Comm.MSG.LEAVE] = function(sender, data)
    if state.players[data] then
        state.players[data] = nil
        HS.Util.Print(data .. " left the game.")
    end
    if HS.UI and HS.UI.UpdateLobby then HS.UI.UpdateLobby() end
end

HS.Comm.handlers[HS.Comm.MSG.BOUNDARY] = function(sender, data)
    if sender ~= state.host then return end
    HS.Boundaries.Deserialize(data)
end

HS.Comm.handlers[HS.Comm.MSG.COUNTDOWN] = function(sender, data)
    if sender ~= state.host then return end
    if state.phase == HS.PHASE.COUNTDOWN then return end

    local parts = HS.Util.Split(data, "|")
    local seekerName = parts[1]
    local countdown = tonumber(parts[2])

    state.phase = HS.PHASE.COUNTDOWN
    state.timer = countdown
    state.timerStart = GetTime()

    HS.Util.Print("Round starting! " .. seekerName .. " will be seeking!")
    HS.Util.Print("Game starts in " .. countdown .. " seconds!")

    if HS.UI then
        if HS.UI.ShowPreGameCountdown then HS.UI.ShowPreGameCountdown(seekerName) end
        if HS.UI.HideLobby then HS.UI.HideLobby() end
        if HS.UI.HideScoreboard then HS.UI.HideScoreboard() end
    end
end

HS.Comm.handlers[HS.Comm.MSG.START_HIDE] = function(sender, data)
    if sender ~= state.host then return end
    if state.phase == HS.PHASE.HIDING then return end

    local parts = HS.Util.Split(data, "|")
    state.seeker = parts[1]
    state.hideTime = tonumber(parts[2])
    state.phase = HS.PHASE.HIDING
    state.round = state.round + 1
    state.timer = state.hideTime
    state.timerStart = GetTime()
    state.foundCount = 0
    state.readyHiders = {}

    state.totalHiders = 0
    for name, player in pairs(state.players) do
        if name == state.seeker then
            player.role = HS.ROLE.SEEKER
        else
            player.role = HS.ROLE.HIDER
            player.foundOrder = 0
            player.frozenX = nil
            player.frozenY = nil
            player.moveStrikes = 0
            state.totalHiders = state.totalHiders + 1
        end
    end

    HS.Game.ApplyGameUI()

    local playerName = UnitName("player")
    if playerName == state.seeker then
        HS.Util.Print("You are the SEEKER! Screen goes dark while others hide...")
    else
        HS.Util.Print("HIDE! You have " .. state.hideTime .. " seconds! " .. state.seeker .. " is seeking!")
        HS.Util.Print("Type |cFFFFD100/has ready|r when you're hidden to skip the wait.")
    end

    if HS.UI then
        if HS.UI.HidePreGameCountdown then HS.UI.HidePreGameCountdown() end
        if HS.UI.ShowHUD then HS.UI.ShowHUD() end
    end
end

HS.Comm.handlers[HS.Comm.MSG.START_SEEK] = function(sender, data)
    if sender ~= state.host then return end
    if state.phase == HS.PHASE.SEEKING then return end

    state.phase = HS.PHASE.SEEKING
    state.seekTime = tonumber(data) or state.seekTime
    state.timer = state.seekTime
    state.timerStart = GetTime()
    state.lastTagTime = 0
    state.tagAttempts = 0
    state.maxTagAttempts = state.totalHiders * HS.DEFAULTS.tagAttemptsPerHider

    local playerName = UnitName("player")
    if state.players[playerName] and state.players[playerName].role == HS.ROLE.HIDER then
        local _, px, py = HS.Util.GetPlayerPosition()
        state.players[playerName].frozenX = px
        state.players[playerName].frozenY = py
    end

    if playerName == state.seeker then
        HS.Util.Print("GO! Find all " .. state.totalHiders .. " hiders! Use /point to tag them.")
        if HideAndSeekDB and HideAndSeekDB.settings.soundEnabled then
            PlaySoundFile(HS.SOUNDS.seekStartFile, "Master")
        end
    else
        HS.Util.Print("Seeker is searching! Stay still!")
    end

    if HS.UI then
        if HS.UI.HideBlindfold then HS.UI.HideBlindfold() end
        if HS.UI.UpdateHUD then HS.UI.UpdateHUD() end
    end
end

HS.Comm.handlers[HS.Comm.MSG.READY] = function(sender, data)
    if state.phase ~= HS.PHASE.HIDING then return end

    local name = data
    local playerName = UnitName("player")

    if state.players[name] and state.players[name].role == HS.ROLE.HIDER then
        state.readyHiders[name] = true
        if name ~= playerName then
            HS.Util.Print(name .. " is ready!")
        end
        HS.Game.CheckAllReady()
    end
end

HS.Comm.handlers[HS.Comm.MSG.FOUND] = function(sender, data)
    local playerName = UnitName("player")
    if sender == playerName then return end

    local parts = HS.Util.Split(data, "|")
    if #parts < 4 then return end

    local seekerName = parts[1]
    local hiderName = parts[2]
    local order = tonumber(parts[3])
    local total = tonumber(parts[4])

    if state.players[hiderName] then
        state.players[hiderName].role = HS.ROLE.FOUND
        state.players[hiderName].foundOrder = order
        state.players[hiderName].score = (state.players[hiderName].score or 0) + order
    end
    if state.players[seekerName] then
        state.players[seekerName].score = (state.players[seekerName].score or 0) + HS.DEFAULTS.seekerPointsPerFind
    end
    state.foundCount = order

    local isLastFind = order >= total

    if HideAndSeekDB and HideAndSeekDB.settings.soundEnabled and not isLastFind then
        PlaySoundFile(HS.SOUNDS.foundFiles[math.random(#HS.SOUNDS.foundFiles)], "Master")
    end

    if hiderName == playerName then
        HS.Util.Print("|cFFFF4444You were found!|r (#" .. order .. " of " .. total .. ")")
    else
        HS.Util.Print(seekerName .. " found " .. hiderName .. "! (" .. order .. "/" .. total .. ")")
    end

    if isLastFind and state.host == playerName then
        HS.Game.EndRound(true)
    end

    if HS.UI and HS.UI.UpdateHUD then HS.UI.UpdateHUD() end
end

HS.Comm.handlers[HS.Comm.MSG.OOB] = function(sender, data)
    HS.Util.Warn("|cFFFF8800" .. data .. " went out of bounds!|r")
end

HS.Comm.handlers[HS.Comm.MSG.MOVED] = function(sender, data)
    local playerName = UnitName("player")
    if sender == playerName then return end

    local parts = HS.Util.Split(data, "|")
    local name = parts[1]
    local strikes = tonumber(parts[2]) or 0
    local maxStrikes = HS.DEFAULTS.moveStrikes

    if strikes >= maxStrikes then
        HS.Util.Warn("|cFFFF0000" .. name .. " auto-found for moving! (Strike " .. strikes .. "/" .. maxStrikes .. ")|r")
    else
        HS.Util.Warn("|cFFFF8800" .. name .. " moved! Strike " .. strikes .. "/" .. maxStrikes .. "|r")
    end
end

HS.Comm.handlers[HS.Comm.MSG.CHEAT] = function(sender, data)
    local parts = HS.Util.Split(data, "|")
    local name = parts[1]
    local reason = parts[2] or "unknown"
    HS.Util.Warn("|cFFFF0000CHEAT: " .. name .. " (" .. reason .. ")|r")
end

HS.Comm.handlers[HS.Comm.MSG.ROUND_END] = function(sender, data)
    if sender ~= state.host then return end
    state.phase = HS.PHASE.ROUND_END
    HS.Game.RestoreUI()
    if HS.UI then
        if HS.UI.HideBlindfold then HS.UI.HideBlindfold() end
        if HS.UI.ShowScoreboard then HS.UI.ShowScoreboard() end
    end
end

HS.Comm.handlers[HS.Comm.MSG.GAME_END] = function(sender, data)
    if sender ~= state.host then return end
    state.phase = HS.PHASE.GAME_END
    HS.Game.RestoreUI()
    if HS.UI then
        if HS.UI.HideBlindfold then HS.UI.HideBlindfold() end
        if HS.UI.ShowScoreboard then HS.UI.ShowScoreboard(true) end
    end
end

HS.Comm.handlers[HS.Comm.MSG.CANCEL] = function(sender, data)
    if sender ~= state.host then return end
    HS.Util.Print("Game cancelled by " .. sender .. ".")
    HS.Game.Reset()
    if HS.UI and HS.UI.HideAll then HS.UI.HideAll() end
end

HS.Comm.handlers[HS.Comm.MSG.FREEZE_POS] = function(sender, data)
    local parts = HS.Util.Split(data, "|")
    if #parts < 3 then return end
    local name = parts[1]
    if state.players[name] then
        state.players[name].frozenX = tonumber(parts[2])
        state.players[name].frozenY = tonumber(parts[3])
    end
end

HS.Comm.handlers[HS.Comm.MSG.HB] = function(sender, data)
    local parts = HS.Util.Split(data, "|")
    if #parts < 2 then return end
    local name = parts[1]
    local cvarHash = parts[2]

    if state.players[name] then
        state.players[name].lastHeartbeat = GetTime()
        if cvarHash ~= HS.Util.EXPECTED_CVAR_HASH then
            HS.Comm.Send(HS.Comm.MSG.CHEAT, name .. "|nameplates_enabled")
        end
    end
end
