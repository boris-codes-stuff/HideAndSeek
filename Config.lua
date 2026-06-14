HideAndSeek = HideAndSeek or {}
local HS = HideAndSeek

HS.VERSION = "1.0.0"
HS.ADDON_PREFIX = "HASV1"

HS.PHASE = {
    IDLE = "IDLE",
    LOBBY = "LOBBY",
    HIDING = "HIDING",
    SEEKING = "SEEKING",
    COUNTDOWN = "COUNTDOWN",
    ROUND_END = "ROUND_END",
    GAME_END = "GAME_END",
}

HS.ROLE = {
    NONE = "NONE",
    SEEKER = "SEEKER",
    HIDER = "HIDER",
    FOUND = "FOUND",
}

HS.DEFAULTS = {
    hideTime = 60,
    seekTime = 300,
    tagCooldown = 10,
    tagRange = 3,
    seekerPointsPerFind = 2,
    maxConsecutiveSeeks = 2,
    heartbeatInterval = 5,
    boundaryCheckInterval = 1,
    moveThreshold = 0.005,
    moveStrikes = 3,
    preGameCountdown = 10,
    outOfBoundsGrace = 5,
    tagAttemptsPerHider = 3,
}

HS.COLORS = {
    gold = {1, 0.82, 0, 1},
    green = {0.2, 0.8, 0.2, 1},
    red = {0.8, 0.2, 0.2, 1},
    yellow = {1, 1, 0.2, 1},
    white = {1, 1, 1, 1},
    grey = {0.5, 0.5, 0.5, 1},
    darkBg = {0.08, 0.08, 0.08, 1},
    headerBg = {0.15, 0.15, 0.15, 1},
    border = {0.6, 0.5, 0.1, 1},
    seeker = {0.8, 0.2, 0.2, 1},
    hider = {0.2, 0.6, 0.8, 1},
    found = {0.5, 0.5, 0.5, 1},
    alliance = {0.2, 0.4, 1, 1},
}

HS.FOUND_ICONS = {1, 2, 3, 4, 5, 6, 7, 8}

HS.SOUNDS = {
    found = 8959,
    foundFiles = {
        "Interface\\AddOns\\HideAndSeek\\gotya.mp3",
        "Interface\\AddOns\\HideAndSeek\\hellomf.mp3",
        "Interface\\AddOns\\HideAndSeek\\johnny.mp3",
    },
    buzzerFile = "Interface\\AddOns\\HideAndSeek\\buzzer.wav",
    seekStartFile = "Interface\\AddOns\\HideAndSeek\\herewego.mp3",
    loseFile = "Interface\\AddOns\\HideAndSeek\\trombone.mp3",
    winFiles = {
        "Interface\\AddOns\\HideAndSeek\\success.mp3",
        "Interface\\AddOns\\HideAndSeek\\verynice.mp3",
    },
    roundStart = 8960,
    warning = 8959,
    countdown = 6674,
}

HS.DB_DEFAULTS = {
    customPresets = {},
    stats = {
        gamesPlayed = 0,
        roundsAsSeeker = 0,
        roundsAsHider = 0,
        timesFoundFirst = 0,
        timesFoundLast = 0,
        timesSurvivedRound = 0,
    },
    settings = {
        soundEnabled = true,
    },
    history = {},
}
