-- QBCore client adapter. No external bridge resource is required.
Bridge = {}

local QBCore = exports['qb-core']:GetCoreObject()
local loaded = false

function Bridge.IsLoaded()
    return loaded
end

function Bridge.Notify(message, kind, title)
    lib.notify({
        title = title or 'Hopouts',
        description = message or '',
        type = ({ inform = 'info', success = 'success', error = 'error' })[kind or 'inform'] or 'info',
        duration = 5000
    })
end

local logoutHandlers = {}
function Bridge.OnLogout(fn)
    logoutHandlers[#logoutHandlers + 1] = fn
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    loaded = true
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    loaded = false
    for i = 1, #logoutHandlers do
        pcall(logoutHandlers[i])
    end
end)

CreateThread(function()
    if LocalPlayer.state.isLoggedIn then loaded = true end
end)
