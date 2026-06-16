local HS = HideAndSeek

HS.Comm = {}

HS.Comm.MSG = {
    CREATE     = "CRT",
    JOIN       = "JN",
    LEAVE      = "LV",
    SETTINGS   = "SET",
    START_HIDE = "SH",
    START_SEEK = "SS",
    FOUND      = "FND",
    OOB        = "OOB",
    MOVED      = "MOV",
    HB         = "HB",
    CHEAT      = "CHT",
    ROUND_END  = "RE",
    GAME_END   = "GE",
    CANCEL     = "CXL",
    BOUNDARY   = "BND",
    TAG_FAIL   = "TF",
    FREEZE_POS = "FP",
    COUNTDOWN  = "CD",
    READY      = "RDY",
    TRIGGER_SOUND = "TS",
    SCAN_RESULT   = "SR",
}

function HS.Comm.Init()
    C_ChatInfo.RegisterAddonMessagePrefix(HS.ADDON_PREFIX)
end

function HS.Comm.GetChannel()
    if IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    end
    return nil
end

function HS.Comm.Send(msgType, data)
    local channel = HS.Comm.GetChannel()
    if not channel then return false end

    local msg = msgType
    if data and data ~= "" then
        msg = msg .. "|" .. data
    end

    C_ChatInfo.SendAddonMessage(HS.ADDON_PREFIX, msg, channel)
    return true
end

function HS.Comm.OnMessage(prefix, msg, channel, sender)
    if prefix ~= HS.ADDON_PREFIX then return end

    local shortSender = sender:match("([^-]+)")

    local msgType, data
    local pipePos = msg:find("|")
    if pipePos then
        msgType = msg:sub(1, pipePos - 1)
        data = msg:sub(pipePos + 1)
    else
        msgType = msg
        data = ""
    end

    if HS.Comm.handlers[msgType] then
        HS.Comm.handlers[msgType](shortSender, data)
    end
end

HS.Comm.handlers = {}
