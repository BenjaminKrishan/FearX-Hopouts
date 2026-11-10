Radio = {}

local current = 0

local function running(name)
    return GetResourceState(name) == 'started'
end

local function try(fn)
    local ok = pcall(fn)
    return ok
end

local function setPma(channel)
    if not running('pma-voice') then return false end
    return try(function()
        if exports['pma-voice'].setRadioChannel then
            exports['pma-voice']:setRadioChannel(channel)
        else
            exports['pma-voice']:SetRadioChannel(channel)
        end
    end)
end

local function setSalty(channel)
    if not running('saltychat') then return false end
    local value = channel > 0 and tostring(channel) or ''
    return try(function() exports.saltychat:SetRadioChannel(value, true) end)
end

local function setMumble(channel)
    if not running('mumble-voip') then return false end
    if channel > 0 then
        return try(function() exports['mumble-voip']:SetRadioChannel(channel) end)
    end
    return try(function() exports['mumble-voip']:removePlayerFromRadio() end)
        or try(function() exports['mumble-voip']:SetRadioChannel(0) end)
end

local function setToko(channel)
    local res = running('tokovoip_script') and 'tokovoip_script' or (running('tokovoip') and 'tokovoip' or nil)
    if not res then return false end
    if channel > 0 then
        return try(function() exports[res]:addPlayerToRadio(channel) end)
            or try(function() exports[res]:setPlayerData(GetPlayerName(PlayerId()), 'radio:channel', channel, true) end)
    end
    return try(function() exports[res]:removePlayerFromRadio(current) end)
        or try(function() exports[res]:setPlayerData(GetPlayerName(PlayerId()), 'radio:channel', 'nil', true) end)
end

local function setYaca(channel)
    if not running('yaca-voice') then return false end
    if channel > 0 then
        try(function() exports['yaca-voice']:enableRadio(true) end)
        return try(function() exports['yaca-voice']:setRadioFrequency(channel) end)
            or try(function() exports['yaca-voice']:setRadioChannel(channel) end)
            or try(function() exports['yaca-voice']:changeRadioFrequency(channel) end)
    end
    try(function() exports['yaca-voice']:enableRadio(false) end)
    return try(function() exports['yaca-voice']:setRadioFrequency(0) end)
        or try(function() exports['yaca-voice']:setRadioChannel(0) end)
end

local function setNamed(resource, joinNames, leaveNames, channel)
    if not running(resource) then return false end
    local names = channel > 0 and joinNames or leaveNames
    for i = 1, #names do
        local method = names[i]
        local ok = try(function()
            local exp = exports[resource]
            if exp and exp[method] then exp[method](exp, channel > 0 and channel or 0) end
        end)
        if ok then return true end
    end
    return false
end

function Radio.Join(channel)
    if Config.Radio and Config.Radio.enabled == false then return end
    channel = math.floor(tonumber(channel) or 0)
    if channel <= 0 then return Radio.Leave() end
    current = channel

    setPma(channel)
    setSalty(channel)
    setMumble(channel)
    setToko(channel)
    setYaca(channel)
    setNamed('mm_radio', { 'JoinRadio', 'joinRadio', 'SetRadio', 'setRadio' }, { 'LeaveRadio', 'leaveRadio' }, channel)
    setNamed('qs-radio', { 'SetRadio', 'JoinRadio', 'SetRadioChannel', 'joinRadio' }, { 'LeaveRadio', 'RemoveRadio', 'SetRadioChannel' }, channel)
    setNamed('lb-radio', { 'joinRadio', 'JoinRadio', 'setChannel' }, { 'leaveRadio', 'LeaveRadio' }, channel)
    setNamed('ac_radio', { 'setRadioChannel', 'SetRadioChannel' }, { 'setRadioChannel', 'SetRadioChannel' }, channel)
    setNamed('rcore_radio', { 'setChannel', 'SetChannel', 'joinRadio' }, { 'leaveRadio', 'setChannel' }, channel)
    setNamed('mm_voice', { 'setRadioChannel', 'SetRadioChannel' }, { 'setRadioChannel' }, channel)
    setNamed('easy-voice', { 'setRadioChannel', 'SetRadioChannel' }, { 'setRadioChannel' }, channel)

    if running('fx_radio') then
        try(function() exports.fx_radio:SetRadioChannel(channel) end)
    end

    LocalPlayer.state:set('hopoutsRadio', channel, true)
end

function Radio.Leave()
    if current <= 0 and not LocalPlayer.state.hopoutsRadio then return end
    local last = current
    current = 0

    setPma(0)
    setSalty(0)
    setMumble(0)
    if last > 0 then
        current = last
        setToko(0)
        current = 0
    end
    setYaca(0)
    setNamed('mm_radio', { 'JoinRadio' }, { 'LeaveRadio', 'leaveRadio', 'SetRadio' }, 0)
    setNamed('qs-radio', { 'SetRadio' }, { 'LeaveRadio', 'RemoveRadio', 'SetRadioChannel' }, 0)
    setNamed('lb-radio', { 'joinRadio' }, { 'leaveRadio', 'LeaveRadio' }, 0)
    setNamed('ac_radio', { 'setRadioChannel' }, { 'setRadioChannel' }, 0)
    setNamed('rcore_radio', { 'setChannel' }, { 'leaveRadio', 'setChannel' }, 0)
    setNamed('mm_voice', { 'setRadioChannel' }, { 'setRadioChannel' }, 0)
    setNamed('easy-voice', { 'setRadioChannel' }, { 'setRadioChannel' }, 0)

    if running('fx_radio') then
        try(function() exports.fx_radio:SetRadioChannel(0) end)
    end

    LocalPlayer.state:set('hopoutsRadio', 0, true)
end

function Radio.Talking(serverId)
    serverId = tonumber(serverId)
    if not serverId then return false end
    local pid = GetPlayerFromServerId(serverId)
    if pid == -1 then
        local state = Player(serverId).state
        return state.radioActive == true or state.talking == true
    end
    if NetworkIsPlayerTalking(pid) then return true end
    if MumbleIsPlayerTalking and MumbleIsPlayerTalking(pid) then return true end
    if running('pma-voice') then
        local ok, talking = pcall(function() return exports['pma-voice']:isPlayerTalking(pid) end)
        if ok and talking then return true end
    end
    local state = Player(serverId).state
    return state.radioActive == true or state.talking == true
end

RegisterNetEvent('fx_hopouts:client:radio', function(channel)
    channel = tonumber(channel) or 0
    if channel > 0 then Radio.Join(channel) else Radio.Leave() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Radio.Leave()
end)
