Squad = { members = {}, blips = {} }

local function removeBlip(source)
    local entry = Squad.blips[source]
    if entry and DoesBlipExist(entry.blip) then RemoveBlip(entry.blip) end
    Squad.blips[source] = nil
end

local function clearBlips()
    for source in pairs(Squad.blips) do removeBlip(source) end
end

function Squad.Clear()
    Squad.members = {}
    clearBlips()
    SendNUIMessage({ action = 'squadHide' })
end

RegisterNetEvent('fx_hopouts:client:squad', function(members)
    Squad.members = members or {}
    if HopClient and HopClient.team then
        local relationship = joaat('HOPOUTS_TEAM_' .. tostring(HopClient.team))
        for _, member in ipairs(Squad.members) do
            local playerId = GetPlayerFromServerId(tonumber(member.source) or -1)
            if playerId ~= -1 then SetPedRelationshipGroupHash(GetPlayerPed(playerId), relationship) end
        end
    end
    SendNUIMessage({ action = 'squad', data = { members = Squad.members } })
end)

CreateThread(function()
    while true do
        local matchId = HopClient and HopClient.matchId
        if matchId and Config.Squad.enabled then
            local ped = PlayerPedId()
            TriggerServerEvent('fx_hopouts:server:squadHealth', matchId, GetEntityHealth(ped), GetPedArmour(ped), not Compat.Ambulance.isDead())
            Wait(1000)
        else
            Wait(1000)
        end
    end
end)

-- Keep teammate blips alive between refreshes rather than removing and
-- recreating them every cycle, which caused visible flicker and map gaps.
CreateThread(function()
    while true do
        local matchId = HopClient and HopClient.matchId
        if matchId and Config.Squad.enabled then
            local wanted = {}
            for _, member in ipairs(Squad.members) do
                local source = tonumber(member.source)
                if source and not member.you and member.alive ~= false then
                    local playerId = GetPlayerFromServerId(source)
                    if playerId ~= -1 then
                        local ped = GetPlayerPed(playerId)
                        if ped ~= 0 and DoesEntityExist(ped) then
                            wanted[source] = true
                            local current = Squad.blips[source]
                            if current and current.ped ~= ped then
                                removeBlip(source)
                                current = nil
                            end
                            if not current or not DoesBlipExist(current.blip) then
                                local blip = AddBlipForEntity(ped)
                                if blip and blip ~= 0 then
                                    SetBlipSprite(blip, Config.Squad.blip.sprite or 1)
                                    SetBlipColour(blip, Config.Squad.blip.color or 2)
                                    SetBlipScale(blip, Config.Squad.blip.scale or 0.8)
                                    SetBlipAsShortRange(blip, false)
                                    SetBlipDisplay(blip, 2)
                                    BeginTextCommandSetBlipName('STRING')
                                    AddTextComponentSubstringPlayerName(member.name or 'Teammate')
                                    EndTextCommandSetBlipName(blip)
                                    Squad.blips[source] = { blip = blip, ped = ped }
                                end
                            end
                        end
                    end
                end
            end
            for source in pairs(Squad.blips) do
                if not wanted[source] then removeBlip(source) end
            end
            Wait(math.max(500, tonumber(Config.Squad.blipRefresh) or 2000))
        else
            clearBlips()
            Wait(1000)
        end
    end
end)
