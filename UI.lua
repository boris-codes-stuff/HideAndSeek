local HS = HideAndSeek

HS.UI = {}

local C = HS.COLORS

-- ============================================================================
-- HELPERS
-- ============================================================================

local function Backdrop(frame, bg, border)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(unpack(bg or C.darkBg))
    frame:SetBackdropBorderColor(unpack(border or C.border))
end

local function Text(parent, text, size, color, anchor, relTo, relPt, xOff, yOff)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont("Fonts\\FRIZQT__.TTF", size or 12, "")
    fs:SetTextColor(unpack(color or C.white))
    fs:SetText(text or "")
    if anchor then
        fs:SetPoint(anchor, relTo or parent, relPt or anchor, xOff or 0, yOff or 0)
    end
    return fs
end

local function Btn(parent, label, w, h, fn)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 120, h or 26)
    b:SetText(label)
    b:SetScript("OnClick", fn)
    b:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    return b
end

-- ============================================================================
-- LOBBY
-- ============================================================================

local function CreateLobby()
    local f = CreateFrame("Frame", "HAS_Lobby", UIParent, "BackdropTemplate")
    f:SetSize(400, 560)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("HIGH")
    Backdrop(f)

    -- Title bar
    local tb = CreateFrame("Frame", nil, f, "BackdropTemplate")
    tb:SetHeight(30)
    tb:SetPoint("TOPLEFT", 1, -1)
    tb:SetPoint("TOPRIGHT", -1, -1)
    tb:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    tb:SetBackdropColor(unpack(C.headerBg))

    Text(tb, "Hide&Seek", 15, C.gold, "LEFT", tb, "LEFT", 10, 0)
    Text(tb, "v" .. HS.VERSION, 9, C.grey, "RIGHT", tb, "RIGHT", -36, 0)

    local closeBtn = Btn(tb, "X", 22, 22, function() f:Hide() end)
    closeBtn:SetPoint("RIGHT", tb, "RIGHT", -4, 0)

    -- Map section
    local mapLabel = Text(f, "Select Map:", 12, C.gold, "TOPLEFT", tb, "BOTTOMLEFT", 10, -10)

    -- Preset grid grouped by faction
    local grid = CreateFrame("Frame", nil, f)
    grid:SetPoint("TOPLEFT", mapLabel, "BOTTOMLEFT", 0, -4)
    grid:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    grid:SetHeight(160)

    f.presetButtons = {}
    local btnW, btnH, gap = 80, 22, 3
    local yOff = 0

    local factions = {"Horde", "Alliance", "Neutral"}
    local factionColors = {
        Horde = C.red,
        Alliance = C.alliance,
        Neutral = C.yellow,
    }

    for _, faction in ipairs(factions) do
        Text(grid, faction, 10, factionColors[faction], "TOPLEFT", grid, "TOPLEFT", 0, yOff)
        yOff = yOff - 16

        local col = 0
        for _, preset in ipairs(HS.Presets.Maps) do
            if preset.faction == faction then
                local pb = Btn(grid, preset.name, btnW, btnH, function()
                    HS.UI.SelectPreset(preset)
                end)
                pb:SetPoint("TOPLEFT", grid, "TOPLEFT", col * (btnW + gap), yOff)
                pb:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 9, "")

                table.insert(f.presetButtons, pb)
                col = col + 1
                if col >= 4 then
                    col = 0
                    yOff = yOff - (btnH + 4)
                end
            end
        end
        if col > 0 then
            yOff = yOff - (btnH + 8)
        else
            yOff = yOff - 8
        end
    end

    -- Selected map info
    local infoFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
    infoFrame:SetHeight(72)
    infoFrame:SetPoint("TOPLEFT", grid, "BOTTOMLEFT", 0, -4)
    infoFrame:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    Backdrop(infoFrame, {0.12, 0.12, 0.12, 1})

    f.mapNameText = Text(infoFrame, "Select a map above", 12, C.white, "TOPLEFT", infoFrame, "TOPLEFT", 8, -8)
    f.mapFactionText = Text(infoFrame, "", 10, C.grey, "TOPLEFT", f.mapNameText, "BOTTOMLEFT", 0, -2)
    f.hideTimeLabel = Text(infoFrame, "", 10, C.grey, "TOPLEFT", f.mapFactionText, "BOTTOMLEFT", 0, -2)
    f.seekTimeLabel = Text(infoFrame, "", 10, C.grey, "TOPLEFT", f.hideTimeLabel, "BOTTOMLEFT", 0, -2)
    f.recPlayersLabel = Text(infoFrame, "", 10, C.gold, "TOPRIGHT", infoFrame, "TOPRIGHT", -8, -8)

    -- Player list
    local plLabel = Text(f, "Players:", 12, C.gold, "TOPLEFT", infoFrame, "BOTTOMLEFT", 0, -10)

    local plFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
    plFrame:SetHeight(120)
    plFrame:SetPoint("TOPLEFT", plLabel, "BOTTOMLEFT", 0, -4)
    plFrame:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    Backdrop(plFrame, {0.12, 0.12, 0.12, 1})
    f.playerListFrame = plFrame
    f.playerTexts = {}

    -- Seeker selector (host only)
    local seekerLabel = Text(f, "Seeker:", 10, C.gold, "BOTTOMLEFT", f, "BOTTOMLEFT", 10, 72)
    f.seekerLabel = seekerLabel

    local seekerBtn = Btn(f, "Random", 120, 22, function()
        local names = {}
        for name in pairs(HS.Game.state.players) do
            table.insert(names, name)
        end
        table.sort(names)
        table.insert(names, 1, "Random")
        local current = HS.Game.state.nextSeeker or "Random"
        local idx = 1
        for i, n in ipairs(names) do
            if n == current then idx = i; break end
        end
        idx = idx + 1
        if idx > #names then idx = 1 end
        if names[idx] == "Random" then
            HS.Game.state.nextSeeker = nil
        else
            HS.Game.state.nextSeeker = names[idx]
        end
        f.seekerBtn:SetText(names[idx])
    end)
    seekerBtn:SetPoint("LEFT", seekerLabel, "RIGHT", 4, 0)
    seekerBtn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 9, "")
    f.seekerBtn = seekerBtn

    -- Options
    local moveCheck = CreateFrame("CheckButton", "HAS_MoveCheck", f, "UICheckButtonTemplate")
    moveCheck:SetSize(24, 24)
    moveCheck:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 42)
    moveCheck:SetChecked(false)
    f.moveCheck = moveCheck

    local moveLabel = Text(f, "Allow Movement (hiders can run)", 10, C.white, "LEFT", moveCheck, "RIGHT", 2, 0)
    f.moveLabel = moveLabel

    -- Bottom buttons
    local btnBar = CreateFrame("Frame", nil, f)
    btnBar:SetHeight(32)
    btnBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 12)
    btnBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)

    f.createBtn = Btn(btnBar, "Create Game", 105, 26, function()
        local preset = HS.UI.selectedPreset
        local allowMove = moveCheck:GetChecked()
        if preset then
            HS.Game.Create(preset.name, preset.hideTime, preset.seekTime, allowMove)
        else
            HS.Game.Create("Custom", HS.DEFAULTS.hideTime, HS.DEFAULTS.seekTime, allowMove)
        end
    end)
    f.createBtn:SetPoint("LEFT", btnBar, "LEFT")

    f.joinBtn = Btn(btnBar, "Join", 80, 26, function()
        HS.Game.Join()
    end)
    f.joinBtn:SetPoint("LEFT", f.createBtn, "RIGHT", 4, 0)

    f.startBtn = Btn(btnBar, "Start Round", 105, 26, function()
        HS.Game.StartRound()
    end)
    f.startBtn:SetPoint("LEFT", f.joinBtn, "RIGHT", 4, 0)

    f.cancelBtn = Btn(btnBar, "Cancel", 70, 26, function()
        HS.Game.Cancel()
    end)
    f.cancelBtn:SetPoint("RIGHT", btnBar, "RIGHT")

    f:Hide()
    return f
end

function HS.UI.SelectPreset(preset)
    HS.UI.selectedPreset = preset
    local f = HS.UI.lobby
    if not f then return end

    f.mapNameText:SetText(preset.name .. "  |  " .. preset.zone)

    local diffColors = {
        Easy = {0.3, 0.8, 0.3, 1},
        Medium = {1, 0.8, 0.2, 1},
        Hard = {0.9, 0.3, 0.3, 1},
    }
    f.mapFactionText:SetText(preset.difficulty .. " difficulty  |  HC Safe")
    f.mapFactionText:SetTextColor(unpack(diffColors[preset.difficulty] or C.white))

    f.hideTimeLabel:SetText("Hide: " .. preset.hideTime .. "s  |  Seek: " .. HS.Util.FormatTime(preset.seekTime))
    f.seekTimeLabel:SetText(preset.description)
    f.recPlayersLabel:SetText(preset.recPlayers .. " players (min " .. preset.minPlayers .. ")")
end

-- ============================================================================
-- HUD (in-game overlay)
-- ============================================================================

local function CreateHUD()
    local f = CreateFrame("Frame", "HAS_HUD", UIParent, "BackdropTemplate")
    f:SetSize(300, 400)
    f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -80)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("HIGH")
    f:SetIgnoreParentAlpha(true)
    Backdrop(f, {0.05, 0.05, 0.05, 0.92})

    -- Header bar
    local tb = CreateFrame("Frame", nil, f, "BackdropTemplate")
    tb:SetHeight(28)
    tb:SetPoint("TOPLEFT", 1, -1)
    tb:SetPoint("TOPRIGHT", -1, -1)
    tb:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    tb:SetBackdropColor(unpack(C.headerBg))

    f.roundText = Text(tb, "Round 1", 13, C.gold, "LEFT", tb, "LEFT", 10, 0)
    f.phaseText = Text(tb, "", 11, C.yellow, "RIGHT", tb, "RIGHT", -30, 0)

    local hudClose = Btn(tb, "X", 22, 22, function() f:Hide() end)
    hudClose:SetPoint("RIGHT", tb, "RIGHT", -4, 0)

    -- Timer
    f.timerText = Text(f, "0:00", 36, C.white, "TOP", f, "TOP", 0, -36)

    -- Found counter
    f.foundText = Text(f, "Found: 0/0", 11, C.white, "TOP", f, "TOP", 0, -72)

    -- Column headers
    local hY = -90
    Text(f, "Player", 10, C.gold, "TOPLEFT", f, "TOPLEFT", 14, hY)
    Text(f, "Score", 10, C.gold, "TOPLEFT", f, "TOPLEFT", 180, hY)
    Text(f, "Status", 10, C.gold, "TOPLEFT", f, "TOPLEFT", 228, hY)

    -- Divider under headers
    local div = f:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(unpack(C.border))
    div:SetHeight(1)
    div:SetPoint("TOPLEFT", f, "TOPLEFT", 8, hY - 14)
    div:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, hY - 14)

    -- Player rows
    f.rows = {}
    for i = 1, 8 do
        local y = hY - 20 - ((i-1) * 28)
        local r = {}
        r.bg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        r.bg:SetColorTexture(0.4, 0.12, 0.12, 0.5)
        r.bg:SetHeight(24)
        r.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 4, y + 4)
        r.bg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, y + 4)
        r.bg:Hide()

        r.icon = Text(f, "", 11, C.white, "TOPLEFT", f, "TOPLEFT", 14, y)
        r.name = Text(f, "", 11, C.white, "TOPLEFT", f, "TOPLEFT", 28, y)
        r.score = Text(f, "", 11, C.yellow, "TOPLEFT", f, "TOPLEFT", 180, y)
        r.status = Text(f, "", 10, C.grey, "TOPLEFT", f, "TOPLEFT", 228, y)
        f.rows[i] = r
    end

    f.roleText = Text(f, "", 10, C.grey, "BOTTOM", f, "BOTTOM", 0, 10)

    f:Hide()
    return f
end

-- ============================================================================
-- BLINDFOLD (seeker's black screen)
-- ============================================================================

local function CreateBlindfold()
    local f = CreateFrame("Frame", "HAS_Blindfold", UIParent, "BackdropTemplate")
    f:SetAllPoints()
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(100)
    f:SetIgnoreParentAlpha(true)
    f:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    f:SetBackdropColor(0, 0, 0, 1)
    f:EnableMouse(false)

    f.titleText = Text(f, "Close Your Eyes...", 30, C.gold, "CENTER", f, "CENTER", 0, 50)
    f.countText = Text(f, "", 64, C.white, "CENTER", f, "CENTER", 0, -20)
    f.subText = Text(f, "Hiders are scrambling!", 13, C.grey, "CENTER", f, "CENTER", 0, -70)

    f:Hide()
    return f
end

-- ============================================================================
-- SCOREBOARD
-- ============================================================================

local function CreateScoreboard()
    local f = CreateFrame("Frame", "HAS_Scoreboard", UIParent, "BackdropTemplate")
    f:SetSize(380, 360)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("HIGH")
    Backdrop(f)

    local tb = CreateFrame("Frame", nil, f, "BackdropTemplate")
    tb:SetHeight(30)
    tb:SetPoint("TOPLEFT", 1, -1)
    tb:SetPoint("TOPRIGHT", -1, -1)
    tb:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    tb:SetBackdropColor(unpack(C.headerBg))

    f.titleText = Text(tb, "Round Complete!", 14, C.gold, "CENTER")

    local sbClose = Btn(tb, "X", 22, 22, function()
        f:Hide()
        if HS.Game.state.phase == HS.PHASE.GAME_END then
            HS.Game.Reset()
        end
    end)
    sbClose:SetPoint("RIGHT", tb, "RIGHT", -4, 0)

    -- Column headers
    local hY = -40
    Text(f, "#",      10, C.gold, "TOPLEFT", f, "TOPLEFT", 14,  hY)
    Text(f, "Player", 10, C.gold, "TOPLEFT", f, "TOPLEFT", 32,  hY)
    Text(f, "Role",   10, C.gold, "TOPLEFT", f, "TOPLEFT", 150, hY)
    Text(f, "Round",  10, C.gold, "TOPLEFT", f, "TOPLEFT", 240, hY)
    Text(f, "Total",  10, C.gold, "TOPLEFT", f, "TOPLEFT", 310, hY)

    f.rows = {}
    for i = 1, 8 do
        local y = hY - 6 - (i * 20)
        local r = {}
        r.rank  = Text(f, "", 10, C.white, "TOPLEFT", f, "TOPLEFT", 14,  y)
        r.name  = Text(f, "", 10, C.white, "TOPLEFT", f, "TOPLEFT", 32,  y)
        r.role  = Text(f, "", 10, C.grey,  "TOPLEFT", f, "TOPLEFT", 150, y)
        r.round = Text(f, "", 10, C.yellow,"TOPLEFT", f, "TOPLEFT", 240, y)
        r.total = Text(f, "", 10, C.gold,  "TOPLEFT", f, "TOPLEFT", 310, y)
        f.rows[i] = r
    end

    f.nextSeekerText = Text(f, "", 12, C.seeker, "BOTTOM", f, "BOTTOM", 0, 48)

    f.nextBtn = Btn(f, "Next Round", 110, 26, function()
        HS.Game.StartRound()
    end)
    f.nextBtn:SetPoint("BOTTOMLEFT", 14, 12)

    f.endBtn = Btn(f, "End Game", 100, 26, function()
        HS.Game.EndGame()
    end)
    f.endBtn:SetPoint("BOTTOMRIGHT", -14, 12)

    f:Hide()
    return f
end

-- ============================================================================
-- BOUNDARY WARNING
-- ============================================================================

local function CreateBoundaryWarning()
    local f = CreateFrame("Frame", "HAS_OOB", UIParent, "BackdropTemplate")
    f:SetSize(340, 36)
    f:SetPoint("TOP", UIParent, "TOP", 0, -130)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetIgnoreParentAlpha(true)
    Backdrop(f, {0.7, 0.1, 0.1, 0.92}, {1, 0, 0, 1})

    f.text = Text(f, "", 12, C.white, "CENTER")

    f:Hide()
    return f
end

-- ============================================================================
-- MAP SETUP OVERLAY (shows corners as you set them)
-- ============================================================================

local function CreateMapSetup()
    local f = CreateFrame("Frame", "HAS_MapSetup", UIParent, "BackdropTemplate")
    f:SetSize(260, 100)
    f:SetPoint("TOP", UIParent, "TOP", 0, -60)
    f:SetFrameStrata("HIGH")
    Backdrop(f, {0.08, 0.08, 0.08, 0.92})

    Text(f, "Custom Boundary Setup", 12, C.gold, "TOP", f, "TOP", 0, -8)
    f.statusText = Text(f, "Walk to a corner and type /has corner", 10, C.white, "TOP", f, "TOP", 0, -26)
    f.cornerCount = Text(f, "Corners: 0", 11, C.yellow, "TOP", f, "TOP", 0, -42)
    f.hint = Text(f, "/has done when finished (min 3)", 9, C.grey, "TOP", f, "TOP", 0, -58)

    local doneBtn = Btn(f, "Done", 80, 22, function()
        HS.Boundaries.FinishSetup()
        f:Hide()
    end)
    doneBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 8)

    f:Hide()
    return f
end

-- ============================================================================
-- INVITE POPUP
-- ============================================================================

local function CreateInvitePopup()
    local f = CreateFrame("Frame", "HAS_Invite", UIParent, "BackdropTemplate")
    f:SetSize(300, 150)
    f:SetPoint("TOP", UIParent, "TOP", 0, -200)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    Backdrop(f, {0.08, 0.08, 0.08, 0.95}, {0.8, 0.6, 0, 1})

    f.icon = Text(f, "|TInterface\\Icons\\Ability_Rogue_MasterOfSubtlety:22|t", 22, C.white, "TOP", f, "TOP", 0, -8)
    f.titleText = Text(f, "", 14, C.gold, "TOP", f, "TOP", 0, -38)
    f.mapText = Text(f, "", 11, C.white, "TOP", f, "TOP", 0, -58)
    f.infoText = Text(f, "", 10, C.grey, "TOP", f, "TOP", 0, -74)

    f.joinBtn = Btn(f, "Join Game", 110, 26, function()
        HS.Game.Join()
        f:Hide()
    end)
    f.joinBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 30, 12)

    f.declineBtn = Btn(f, "Decline", 90, 26, function()
        f:Hide()
    end)
    f.declineBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 12)

    f:Hide()
    return f
end

-- ============================================================================
-- PRE-GAME COUNTDOWN
-- ============================================================================

local function CreatePreGameCountdown()
    local f = CreateFrame("Frame", "HAS_PreGame", UIParent, "BackdropTemplate")
    f:SetSize(340, 220)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(90)
    Backdrop(f, {0.05, 0.05, 0.05, 0.9}, {0.8, 0.6, 0, 1})

    f.titleText = Text(f, "Get Ready!", 24, C.gold, "CENTER", f, "CENTER", 0, 60)
    f.countText = Text(f, "", 72, C.white, "CENTER", f, "CENTER", 0, -10)
    f.seekerText = Text(f, "", 14, C.seeker, "CENTER", f, "CENTER", 0, -65)
    f.subText = Text(f, "Position yourselves!", 12, C.grey, "CENTER", f, "CENTER", 0, -85)

    f:Hide()
    return f
end

-- ============================================================================
-- INIT
-- ============================================================================

function HS.UI.Init()
    HS.UI.lobby = CreateLobby()
    HS.UI.hud = CreateHUD()
    HS.UI.blindfold = CreateBlindfold()
    HS.UI.scoreboard = CreateScoreboard()
    HS.UI.boundaryWarning = CreateBoundaryWarning()
    HS.UI.mapSetup = CreateMapSetup()
    HS.UI.preGameCountdown = CreatePreGameCountdown()
    HS.UI.invitePopup = CreateInvitePopup()
    HS.UI.selectedPreset = nil
end

-- ============================================================================
-- SHOW / HIDE / UPDATE
-- ============================================================================

function HS.UI.ShowLobby()
    if HS.UI.lobby then
        HS.UI.UpdateLobby()
        HS.UI.lobby:Show()
    end
end

function HS.UI.HideLobby()
    if HS.UI.lobby then HS.UI.lobby:Hide() end
end

function HS.UI.UpdateLobby()
    local f = HS.UI.lobby
    if not f then return end

    local state = HS.Game.state
    local me = UnitName("player")

    -- Player list
    local i = 1
    for name, player in pairs(state.players) do
        if not f.playerTexts[i] then
            f.playerTexts[i] = Text(f.playerListFrame, "", 11, C.white,
                "TOPLEFT", f.playerListFrame, "TOPLEFT", 8, -6 - ((i-1) * 16))
        end
        local display = name
        if name == state.host then display = display .. " |cFFFFD100(Host)|r" end
        if name == me then display = display .. " |cFF00CC00(You)|r" end
        f.playerTexts[i]:SetText(display)
        f.playerTexts[i]:Show()
        i = i + 1
    end
    for j = i, #f.playerTexts do
        if f.playerTexts[j] then f.playerTexts[j]:Hide() end
    end

    -- Seeker selector
    if state.nextSeeker and not state.players[state.nextSeeker] then
        state.nextSeeker = nil
    end
    local isHost = state.host == me
    if isHost and (state.phase == HS.PHASE.LOBBY or state.phase == HS.PHASE.ROUND_END) then
        f.seekerLabel:Show()
        f.seekerBtn:Show()
        f.seekerBtn:SetText(state.nextSeeker or "Random")
    else
        f.seekerLabel:Hide()
        f.seekerBtn:Hide()
    end

    -- Button visibility
    local inGame = state.players[me] ~= nil
    local isIdle = state.phase == HS.PHASE.IDLE
    local inLobby = state.phase == HS.PHASE.LOBBY

    if state.phase == HS.PHASE.GAME_END then
        HS.Game.Reset()
        isIdle = true
    end

    if isIdle then
        f.createBtn:Show()
        f.joinBtn:Hide()
        f.startBtn:Hide()
        f.cancelBtn:Hide()
    elseif inLobby or state.phase == HS.PHASE.ROUND_END then
        f.createBtn:Hide()
        if inGame then
            f.joinBtn:Hide()
        else
            f.joinBtn:Show()
        end
        if isHost then
            f.startBtn:Show()
            f.cancelBtn:Show()
        else
            f.startBtn:Hide()
            f.cancelBtn:Hide()
        end
    else
        f.createBtn:Hide()
        f.joinBtn:Hide()
        f.startBtn:Hide()
        f.cancelBtn:Hide()
    end
end

function HS.UI.ShowHUD()
    if not HS.UI.hud then return end
    HS.UI.UpdateHUD()
    HS.UI.hud:Show()

    local state = HS.Game.state
    if state.phase == HS.PHASE.HIDING and state.seeker == UnitName("player") then
        HS.UI.ShowBlindfold()
    end
end

function HS.UI.HideHUD()
    if HS.UI.hud then HS.UI.hud:Hide() end
end

function HS.UI.UpdateHUD()
    local f = HS.UI.hud
    if not f or not f:IsShown() then return end

    local state = HS.Game.state
    local me = UnitName("player")

    f.roundText:SetText("Round " .. state.round)

    if state.phase == HS.PHASE.HIDING then
        f.phaseText:SetText("HIDING")
        f.phaseText:SetTextColor(unpack(C.yellow))
    elseif state.phase == HS.PHASE.SEEKING then
        f.phaseText:SetText("SEEKING")
        f.phaseText:SetTextColor(unpack(C.red))
    end

    f.foundText:SetText("Found: " .. state.foundCount .. " / " .. state.totalHiders)

    local sorted = {}
    for name, player in pairs(state.players) do
        table.insert(sorted, {name = name, player = player})
    end
    table.sort(sorted, function(a, b)
        if a.player.role == HS.ROLE.SEEKER then return true end
        if b.player.role == HS.ROLE.SEEKER then return false end
        if a.player.role == HS.ROLE.FOUND and b.player.role ~= HS.ROLE.FOUND then return false end
        if a.player.role ~= HS.ROLE.FOUND and b.player.role == HS.ROLE.FOUND then return true end
        return a.player.score > b.player.score
    end)

    for i = 1, 8 do
        local r = f.rows[i]
        if sorted[i] then
            local p = sorted[i]
            local nameStr = p.name
            if p.name == me then nameStr = nameStr .. " (You)" end

            r.name:SetText(nameStr)
            r.score:SetText(p.player.score)

            if p.player.role == HS.ROLE.SEEKER then
                r.icon:SetText("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14|t")
                r.name:SetTextColor(unpack(C.seeker))
                r.status:SetText("SEEKER")
                r.status:SetTextColor(unpack(C.seeker))
                r.bg:Hide()
            elseif p.player.role == HS.ROLE.FOUND then
                r.icon:SetText("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:14|t")
                r.name:SetTextColor(0.45, 0.45, 0.45, 1)
                r.status:SetText("FOUND #" .. (p.player.foundOrder or 0))
                r.status:SetTextColor(1, 0.4, 0.1, 1)
                r.bg:Show()
            elseif p.player.role == HS.ROLE.HIDER then
                r.icon:SetText("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:14|t")
                r.name:SetTextColor(unpack(C.hider))
                r.status:SetText("Hiding")
                r.status:SetTextColor(unpack(C.hider))
                r.bg:Hide()
            else
                r.icon:SetText("")
                r.name:SetTextColor(unpack(C.white))
                r.status:SetText("")
                r.bg:Hide()
            end

            r.icon:Show(); r.name:Show(); r.score:Show(); r.status:Show()
        else
            r.icon:Hide(); r.name:Hide(); r.score:Hide(); r.status:Hide(); r.bg:Hide()
        end
    end

    if state.seeker == me then
        if state.maxTagAttempts > 0 then
            local attemptsLeft = state.maxTagAttempts - state.tagAttempts
            if attemptsLeft > 0 then
                f.roleText:SetText("/point or click to tag! " .. attemptsLeft .. " guesses left")
            else
                f.roleText:SetText("|cFFFF0000No guesses left! Wait for timer.|r")
            end
        else
            f.roleText:SetText("/point or click to tag!")
        end
    elseif state.players[me] then
        if state.players[me].role == HS.ROLE.HIDER then
            if state.allowMovement then
                f.roleText:SetText("Run and hide!")
            else
                f.roleText:SetText("Stay hidden! Don't move!")
            end
        elseif state.players[me].role == HS.ROLE.FOUND then
            f.roleText:SetText("You were found!")
        end
    end
end

function HS.UI.UpdateTimer(remaining, phase)
    local timeStr = HS.Util.FormatTime(remaining)

    if HS.UI.hud and HS.UI.hud:IsShown() then
        HS.UI.hud.timerText:SetText(timeStr)
        if remaining <= 10 then
            HS.UI.hud.timerText:SetTextColor(1, 0.2, 0.2, 1)
        elseif remaining <= 30 then
            HS.UI.hud.timerText:SetTextColor(1, 1, 0.2, 1)
        else
            HS.UI.hud.timerText:SetTextColor(1, 1, 1, 1)
        end
    end

    if HS.UI.blindfold and HS.UI.blindfold:IsShown() then
        HS.UI.blindfold.countText:SetText(tostring(math.ceil(remaining)))
        if remaining <= 5 then
            HS.UI.blindfold.countText:SetTextColor(1, 0.2, 0.2, 1)
        elseif remaining <= 10 then
            HS.UI.blindfold.countText:SetTextColor(1, 1, 0.2, 1)
        else
            HS.UI.blindfold.countText:SetTextColor(1, 1, 1, 1)
        end
    end
end

function HS.UI.ShowBlindfold()
    if HS.UI.blindfold then HS.UI.blindfold:Show() end
end

function HS.UI.HideBlindfold()
    if HS.UI.blindfold then HS.UI.blindfold:Hide() end
end

function HS.UI.ShowPreGameCountdown(seekerName)
    local f = HS.UI.preGameCountdown
    if not f then return end
    f.seekerText:SetText(seekerName .. " will be seeking")
    f:Show()
end

function HS.UI.UpdatePreGameCountdown(remaining)
    local f = HS.UI.preGameCountdown
    if not f or not f:IsShown() then return end
    local secs = math.ceil(remaining)
    f.countText:SetText(tostring(secs))
    if secs <= 3 then
        f.countText:SetTextColor(1, 0.2, 0.2, 1)
    elseif secs <= 5 then
        f.countText:SetTextColor(1, 1, 0.2, 1)
    else
        f.countText:SetTextColor(1, 1, 1, 1)
    end
end

function HS.UI.HidePreGameCountdown()
    if HS.UI.preGameCountdown then HS.UI.preGameCountdown:Hide() end
end

function HS.UI.ShowInvitePopup(hostName, mapName, difficulty)
    local f = HS.UI.invitePopup
    if not f then return end
    f.titleText:SetText(hostName .. " invites you to Hide&Seek!")
    f.mapText:SetText("Map: " .. (mapName or "Custom"))
    if difficulty then
        f.infoText:SetText(difficulty .. " difficulty")
    else
        f.infoText:SetText("")
    end
    f:Show()
end

function HS.UI.HideInvitePopup()
    if HS.UI.invitePopup then HS.UI.invitePopup:Hide() end
end

function HS.UI.ShowBoundaryWarning(show, duration)
    if not HS.UI.boundaryWarning then return end
    if show then
        local me = UnitName("player")
        if HS.Game.state.seeker == me then
            RaidNotice_AddMessage(RaidWarningFrame, "Out of bounds!", ChatTypeInfo["RAID_WARNING"])
            return
        else
            local grace = HS.DEFAULTS.outOfBoundsGrace - (duration or 0)
            if grace > 0 then
                HS.UI.boundaryWarning.text:SetText("OUT OF BOUNDS! Return in " .. math.ceil(grace) .. "s!")
            else
                HS.UI.boundaryWarning.text:SetText("OUT OF BOUNDS! Violation reported!")
            end
        end
        HS.UI.boundaryWarning:Show()
    else
        HS.UI.boundaryWarning:Hide()
    end
end

function HS.UI.ShowScoreboard(isFinal)
    local f = HS.UI.scoreboard
    if not f then return end

    local state = HS.Game.state
    local me = UnitName("player")

    f.titleText:SetText(isFinal and "Game Over!" or ("Round " .. state.round .. " Complete!"))

    local sorted = {}
    for name, player in pairs(state.players) do
        table.insert(sorted, {
            name = name,
            score = player.score,
            role = player.role,
            foundOrder = player.foundOrder or 0,
        })
    end
    table.sort(sorted, function(a, b) return a.score > b.score end)

    for i = 1, 8 do
        local r = f.rows[i]
        if sorted[i] then
            local p = sorted[i]
            r.rank:SetText(i .. ".")
            r.name:SetText(p.name .. (p.name == me and " (You)" or ""))

            local roleStr, roleColor = "", C.grey
            if p.role == HS.ROLE.SEEKER then
                roleStr = "Seeker"
                roleColor = C.seeker
            elseif p.role == HS.ROLE.FOUND then
                roleStr = "Found #" .. p.foundOrder
                roleColor = C.found
            elseif p.role == HS.ROLE.HIDER then
                roleStr = "Survived!"
                roleColor = C.green
            end
            r.role:SetText(roleStr)
            r.role:SetTextColor(unpack(roleColor))

            local roundPts = 0
            if p.role == HS.ROLE.SEEKER then
                roundPts = state.foundCount * HS.DEFAULTS.seekerPointsPerFind
            elseif p.role == HS.ROLE.FOUND then
                roundPts = p.foundOrder
            elseif p.role == HS.ROLE.HIDER then
                roundPts = state.totalHiders + 1
            end
            r.round:SetText("+" .. roundPts)
            r.total:SetText(p.score)

            r.rank:Show(); r.name:Show(); r.role:Show(); r.round:Show(); r.total:Show()
        else
            r.rank:Hide(); r.name:Hide(); r.role:Hide(); r.round:Hide(); r.total:Hide()
        end
    end

    if isFinal then
        f.nextSeekerText:SetText("")
        f.nextBtn:Hide()
        f.endBtn:SetText("Close")
        f.endBtn:SetScript("OnClick", function()
            f:Hide()
            HS.Game.Reset()
            if HS.UI.HideAll then HS.UI.HideAll() end
        end)
        f.endBtn:Enable()
    else
        f.nextSeekerText:SetText("Next Seeker: " .. HS.Game.PeekNextSeeker())
        f.nextBtn:Show()
        f.nextBtn:SetEnabled(state.host == me)
        f.endBtn:SetText("End Game")
        f.endBtn:SetScript("OnClick", function()
            HS.Game.EndGame()
        end)
        f.endBtn:SetEnabled(state.host == me)
    end

    f:Show()
end

function HS.UI.HideScoreboard()
    if HS.UI.scoreboard then HS.UI.scoreboard:Hide() end
end

function HS.UI.UpdateMapSetup()
    local f = HS.UI.mapSetup
    if not f then return end

    local count = #HS.Boundaries.setupPoints
    f.cornerCount:SetText("Corners: " .. count)

    if count >= 3 then
        f.hint:SetText("Ready! Click Done or add more corners.")
        f.hint:SetTextColor(unpack(C.green))
    end

    if HS.Boundaries.setupMode then
        f:Show()
    else
        f:Hide()
    end
end

function HS.UI.HideAll()
    if HS.UI.lobby then HS.UI.lobby:Hide() end
    if HS.UI.hud then HS.UI.hud:Hide() end
    if HS.UI.blindfold then HS.UI.blindfold:Hide() end
    if HS.UI.scoreboard then HS.UI.scoreboard:Hide() end
    if HS.UI.boundaryWarning then HS.UI.boundaryWarning:Hide() end
    if HS.UI.mapSetup then HS.UI.mapSetup:Hide() end
    if HS.UI.preGameCountdown then HS.UI.preGameCountdown:Hide() end
    if HS.UI.invitePopup then HS.UI.invitePopup:Hide() end
end
