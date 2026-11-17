HopClient = {
    matchId = nil,
    team = nil,
    slot = nil,
    round = 0,
    live = false,
    lobbyOpen = false
}

local screen = 'world'
local returnCoords, lobbyCam
local currentKit, currentSpawn, currentVehicles = {}, nil, {}
local ownedVehicles = {}
local deathReported = false
local zone
local inReady = false

local function uiConfig()
    return {
        ui = Config.UI, pages = Config.Pages, ranksEnabled = Config.Ranks.enabled,
        ranks = Config.Ranks.tiers, storeEnabled = Config.Store.enabled,
        loadoutEnabled = Config.LoadoutShop.enabled, credits = Config.Credits,
        cash = Config.Cash, leaderboard = Config.Leaderboard, friends = Config.Friends,
        maxParty = Config.MaxParty
    }
end

local function callback(name, data)
    local ok, result = pcall(function() return lib.callback.await('fx_hopouts:server:' .. name, false, data) end)
    if not ok then
        if Config.Debug then print(('[FearX-Hopouts] callback %s failed: %s'):format(name, result)) end
        return { ok = false, reason = 'Server request failed. Please try again.' }
    end
    return result or { ok = false, reason = 'No server response.' }
end

local function teleport(coords)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16); Wait(200) end
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(ped, coords.w or coords[4] or 0.0)
end

local function deleteVehicles()
    for _, vehicle in ipairs(ownedVehicles) do
        if DoesEntityExist(vehicle) then
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteEntity(vehicle)
        end
    end
    ownedVehicles = {}
end

local function clearPedWeapons()
    RemoveAllPedWeapons(PlayerPedId(), true)
end

local function restoreWorld()
    screen = 'world'
    HopClient.matchId, HopClient.team, HopClient.slot = nil, nil, nil
    HopClient.live, HopClient.lobbyOpen = false, false
    currentKit, currentSpawn, currentVehicles, zone = {}, nil, {}, nil
    deathReported = false
    deleteVehicles()
    Squad.Clear()
    Radio.Leave()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetPlayerControl(PlayerId(), true, 0)
    SetPedInfiniteAmmoClip(ped, false)
    SetPedRelationshipGroupHash(ped, joaat('PLAYER'))
    NetworkSetFriendlyFireOption(true)
    clearPedWeapons()
    if lobbyCam then
        RenderScriptCams(false, true, Config.LobbyFadeMs, true, true)
        DestroyCam(lobbyCam, false)
        lobbyCam = nil
    end
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'lobbyClose' })
    SendNUIMessage({ action = 'matchHide' })
    SendNUIMessage({ action = 'readyDone' })
    if returnCoords then
        teleport(Config.ExitSpot or returnCoords)
        returnCoords = nil
    end
end

local function setupLobbyCamera()
    local pos = Config.LobbySpot
    local offset = Config.LobbyCam
    lobbyCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',
        pos.x, pos.y + offset.dist, pos.z + offset.height, 0.0, 0.0, 180.0,
        offset.fov, false, 0)
    PointCamAtCoord(lobbyCam, pos.x, pos.y, pos.z + offset.aim)
    SetCamActive(lobbyCam, true)
    RenderScriptCams(true, true, Config.LobbyFadeMs, true, true)
end

local function closeLobby()
    if screen ~= 'lobby' then return end
    if inReady then callback('ready', { accept = false }) end
    TriggerServerEvent('fx_hopouts:server:close')
    restoreWorld()
end

local function openLobby()
    if screen == 'match' then return Bridge.Notify('Finish or leave your match first.', 'error') end
    if screen == 'lobby' then return closeLobby() end
    if not Bridge.IsLoaded() then return Bridge.Notify('Your character is still loading.', 'error') end

    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    returnCoords = vector4(pos.x, pos.y, pos.z, GetEntityHeading(ped))
    TriggerServerEvent('fx_hopouts:server:open', returnCoords)
    DoScreenFadeOut(Config.LobbyFadeMs)
    Wait(Config.LobbyFadeMs + 50)
    teleport(Config.LobbySpot)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    clearPedWeapons()
    setupLobbyCamera()
    screen = 'lobby'
    HopClient.lobbyOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'config', data = uiConfig() })
    local data = callback('getLobby')
    if screen ~= 'lobby' then return end
    if not data or data.ok == false then
        Bridge.Notify(data and data.reason or 'Could not load the lobby.', 'error')
        restoreWorld()
        DoScreenFadeIn(Config.LobbyFadeMs)
        return
    end
    SendNUIMessage({ action = 'lobbyOpen', data = data })
    DoScreenFadeIn(Config.LobbyFadeMs)
end

RegisterCommand(Config.Command, openLobby, false)
RegisterCommand(Config.LeaveCommand, function()
    if screen == 'match' then TriggerServerEvent('fx_hopouts:server:forfeit')
    elseif screen == 'lobby' then closeLobby() end
end, false)

if Config.KeyMapping and Config.KeyMapping.enabled then
    RegisterKeyMapping(Config.Command, 'Open the Hopouts lobby', 'keyboard', Config.KeyMapping.key or 'F7')
end

local function nui(name, handler)
    RegisterNUICallback(name, function(data, cb)
        local result = handler(data or {})
        cb(result or { ok = true })
    end)
end

nui('uiReady', function() SendNUIMessage({ action = 'config', data = uiConfig() }); return { ok = true } end)
nui('close', function() closeLobby(); return { ok = true } end)
nui('queue', function(data) return callback('queue', data) end)
nui('partyKick', function(data) return callback('partyKick', data) end)
nui('partyLeave', function() return callback('partyLeave') end)
nui('partyRespond', function(data) return callback('partyRespond', data) end)
nui('friendsAdd', function(data) return callback('friendsAdd', data) end)
nui('friendsRespond', function(data) return callback('friendsRespond', data) end)
nui('friendsInvite', function(data) return callback('friendsInvite', data) end)
nui('career', function() return callback('career') end)
nui('storeGet', function() return callback('storeGet') end)
nui('storeBuy', function(data) return callback('storeBuy', data) end)
nui('loadoutGet', function() return callback('loadoutGet') end)
nui('loadoutBuy', function(data) return callback('loadoutBuy', data) end)
nui('loadoutEquip', function(data) return callback('loadoutEquip', data) end)
nui('ready', function(data) return callback('ready', data) end)

RegisterNetEvent('fx_hopouts:client:teamUpdate', function(data)
    SendNUIMessage({ action = 'teamUpdate', data = data })
end)
RegisterNetEvent('fx_hopouts:client:queueState', function(inQueue)
    SendNUIMessage({ action = 'queueState', data = { inQueue = inQueue } })
end)
RegisterNetEvent('fx_hopouts:client:partyInvite', function(data)
    SendNUIMessage({ action = 'partyInvite', data = data })
end)
RegisterNetEvent('fx_hopouts:client:friendsUpdate', function(data)
    SendNUIMessage({ action = 'friendsUpdate', data = data })
end)

RegisterNetEvent('fx_hopouts:client:readyCheck', function(data)
    inReady = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'readyCheck', data = data })
end)
RegisterNetEvent('fx_hopouts:client:readyDone', function()
    inReady = false
    SendNUIMessage({ action = 'readyDone' })
    if screen ~= 'lobby' then SetNuiFocus(false, false) end
end)

local function giveLoadout(kit)
    currentKit = kit or {}
    local ped = PlayerPedId()
    clearPedWeapons()
    for _, weapon in ipairs(currentKit) do
        local hash = joaat(weapon.name)
        GiveWeaponToPed(ped, hash, weapon.ammo or 60, false, true)
    end
    SetPedInfiniteAmmoClip(ped, Config.Match.unlimitedAmmo == true)
    if currentKit[1] then SetCurrentPedWeapon(ped, joaat(currentKit[1].name), true) end
    local data = {}
    for _, weapon in ipairs(currentKit) do
        if weapon.role == 'equipment' then
            data.equipment = data.equipment or {}; data.equipment[#data.equipment + 1] = weapon
        else data[weapon.role] = weapon end
    end
    SendNUIMessage({ action = 'loadout', data = data })
end

local function spawnVehicles(definitions)
    deleteVehicles()
    for _, definition in ipairs(definitions or {}) do
        local model = joaat(definition.model)
        if IsModelValid(model) then
            lib.requestModel(model, 5000)
            local pos = definition.pos
            local vehicle = CreateVehicle(model, pos.x, pos.y, pos.z, pos.w or 0.0, true, false)
            if vehicle ~= 0 then
                SetEntityAsMissionEntity(vehicle, true, true)
                SetVehicleOnGroundProperly(vehicle)
                SetVehicleColours(vehicle, definition.colors and definition.colors[1] or 0, definition.colors and definition.colors[2] or 0)
                if definition.livery then SetVehicleLivery(vehicle, definition.livery) end
                SetVehicleDoorsLocked(vehicle, 1)
                ownedVehicles[#ownedVehicles + 1] = vehicle
            end
            SetModelAsNoLongerNeeded(model)
        end
    end
end

RegisterNetEvent('fx_hopouts:client:matchStart', function(data)
    screen = 'match'
    HopClient.matchId = data.id
    HopClient.team, HopClient.slot = data.team, data.slot
    HopClient.lobbyOpen, inReady = false, false
    SetNuiFocus(false, false)
    if lobbyCam then RenderScriptCams(false, true, 250, true, true); DestroyCam(lobbyCam, false); lobbyCam = nil end
    Radio.Join(Config.Radio.baseChannel + data.id)
    SendNUIMessage({ action = 'readyDone' })
    SendNUIMessage({ action = 'matchStart', data = data })
end)

RegisterNetEvent('fx_hopouts:client:roundStart', function(data)
    if data.id ~= HopClient.matchId then return end
    HopClient.round, HopClient.live = data.round, false
    deathReported, zone = false, nil
    currentSpawn, currentVehicles = data.spawn, data.vehicles or {}
    local ped = Compat.Ambulance.revive()
    FreezeEntityPosition(ped, false)
    teleport(currentSpawn)
    SetEntityInvincible(ped, true)
    SetEntityHealth(ped, 200)
    SetPedArmour(ped, Config.RoundArmor or 100)
    local relationship = joaat('HOPOUTS_TEAM_' .. tostring(HopClient.team))
    SetPedRelationshipGroupHash(ped, relationship)
    SetRelationshipBetweenGroups(0, relationship, relationship)
    SetCanAttackFriendly(ped, Config.Squad.friendlyFire == true, false)
    NetworkSetFriendlyFireOption(Config.Squad.friendlyFire == true)
    ClearPedBloodDamage(ped)
    giveLoadout(data.kit)
    FreezeEntityPosition(ped, true)
    if data.vehicleOwner then spawnVehicles(currentVehicles) else deleteVehicles() end
    SendNUIMessage({ action = 'countdown', data = data })
    SendNUIMessage({ action = 'stormClear' })
end)

RegisterNetEvent('fx_hopouts:client:roundLive', function(data)
    if data.id ~= HopClient.matchId or data.round ~= HopClient.round then return end
    HopClient.live = true
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SendNUIMessage({ action = 'live', data = data })
end)

RegisterNetEvent('fx_hopouts:client:roundEnd', function(data)
    if data.id ~= HopClient.matchId then return end
    HopClient.live, zone = false, nil
    FreezeEntityPosition(PlayerPedId(), true)
    SetEntityInvincible(PlayerPedId(), true)
    SendNUIMessage({ action = 'roundEnd', data = data })
    SendNUIMessage({ action = 'stormClear' })
end)

RegisterNetEvent('fx_hopouts:client:zoneUpdate', function(data)
    if data.id ~= HopClient.matchId or data.round ~= HopClient.round then return end
    zone = data
    zone.started = GetGameTimer()
end)

RegisterNetEvent('fx_hopouts:client:matchEnd', function(data)
    if data.id ~= HopClient.matchId then return end
    HopClient.live, zone = false, nil
    SetEntityInvincible(PlayerPedId(), true)
    SendNUIMessage({ action = 'matchEnd', data = data })
    SendNUIMessage({ action = 'stormClear' })
end)

RegisterNetEvent('fx_hopouts:client:matchCleanup', function(data)
    if data and data.id and data.id ~= HopClient.matchId then return end
    restoreWorld()
end)

RegisterNetEvent('fx_hopouts:serverCancelled', function(reason)
    Bridge.Notify(reason or 'The match was cancelled.', 'error')
    restoreWorld()
end)

-- Client reports only its own death. The server validates match, round and killer.
CreateThread(function()
    while true do
        if HopClient.matchId and HopClient.live and not deathReported and Compat.Ambulance.isDead() then
            deathReported = true
            local ped = PlayerPedId()
            local killerPed = GetPedSourceOfDeath(ped)
            local killer = 0
            if killerPed ~= 0 and IsPedAPlayer(killerPed) then
                local killerPlayer = NetworkGetPlayerIndexFromPed(killerPed)
                if killerPlayer and NetworkIsPlayerActive(killerPlayer) then killer = GetPlayerServerId(killerPlayer) end
            end
            local bone = select(2, GetPedLastDamageBone(ped))
            TriggerServerEvent('fx_hopouts:server:died', HopClient.matchId, HopClient.round, killer, bone == 31086)
        end
        Wait(HopClient.live and 150 or 750)
    end
end)

-- Storm rendering and damage use the server-issued phase, never client-supplied radii.
CreateThread(function()
    while true do
        if HopClient.live and zone then
            local progress = math.min(1.0, (GetGameTimer() - zone.started) / math.max(1, zone.duration or 1))
            zone.currentRadius = zone.fromRadius + (zone.radius - zone.fromRadius) * progress
            DrawMarker(28, zone.center.x, zone.center.y, zone.center.z, 0.0, 0.0, 0.0,
                0.0, 0.0, 0.0, zone.currentRadius * 2.0, zone.currentRadius * 2.0, 300.0,
                Config.Storm.color.r, Config.Storm.color.g, Config.Storm.color.b, Config.Storm.color.a,
                false, false, 2, false, nil, nil, false)
            Wait(0)
        else Wait(250) end
    end
end)

CreateThread(function()
    while true do
        if HopClient.live and zone and zone.currentRadius then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local distance = #(vector2(pos.x, pos.y) - vector2(zone.center.x, zone.center.y))
            if distance > zone.currentRadius and not Compat.Ambulance.isDead() then
                SendNUIMessage({ action = 'storm' })
                SetEntityHealth(ped, math.max(0, GetEntityHealth(ped) - math.floor(zone.dps or 1)))
            else SendNUIMessage({ action = 'stormClear' }) end
            Wait(1000)
        else Wait(500) end
    end
end)

-- Weapon hotkeys and a match-weapon watchdog.
CreateThread(function()
    while true do
        if HopClient.matchId then
            local ped = PlayerPedId()
            if not HopClient.live then DisablePlayerFiring(PlayerId(), true) end
            for index, key in ipairs({ 157, 158, 160 }) do
                if IsControlJustReleased(0, key) then
                    local role = ({ 'primary', 'secondary', 'equipment' })[index]
                    for _, weapon in ipairs(currentKit) do
                        if weapon.role == role then
                            SetCurrentPedWeapon(ped, joaat(weapon.name), true)
                            SendNUIMessage({ action = 'loadoutSel', data = weapon })
                            break
                        end
                    end
                end
            end
            if Config.Match.loadoutWatchdog then
                for _, weapon in ipairs(currentKit) do
                    local hash = joaat(weapon.name)
                    if not HasPedGotWeapon(ped, hash, false) then GiveWeaponToPed(ped, hash, weapon.ammo or 60, false, true) end
                end
            end
            Wait(250)
        else Wait(750) end
    end
end)

Bridge.OnLogout(function()
    if screen ~= 'world' then restoreWorld() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if screen ~= 'world' then
        local coords = returnCoords
        if coords then SetEntityCoordsNoOffset(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false) end
    end
    deleteVehicles()
    Squad.Clear()
    FreezeEntityPosition(PlayerPedId(), false)
    SetEntityInvincible(PlayerPedId(), false)
    SetPedRelationshipGroupHash(PlayerPedId(), joaat('PLAYER'))
    NetworkSetFriendlyFireOption(true)
    RemoveAllPedWeapons(PlayerPedId(), true)
    SetNuiFocus(false, false)
end)
