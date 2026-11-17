-- QBCore server adapter.
Bridge = {}

local QBCore = exports['qb-core']:GetCoreObject()
local identifiers = {}
local logoutHandlers = {}

local function player(src)
    return QBCore.Functions.GetPlayer(tonumber(src))
end

function Bridge.GetPlayer(src)
    return player(src)
end

function Bridge.IsLoaded(src)
    local qb = player(src)
    return qb ~= nil and qb.PlayerData ~= nil and qb.PlayerData.citizenid ~= nil
end

function Bridge.GetIdentifier(src)
    src = tonumber(src)
    if not src then return nil end
    if identifiers[src] then return identifiers[src] end
    local qb = player(src)
    local id = qb and qb.PlayerData and qb.PlayerData.citizenid
    if id then identifiers[src] = id end
    return id
end

function Bridge.ForgetIdentifier(src)
    identifiers[tonumber(src) or 0] = nil
end

function Bridge.GetName(src)
    local qb = player(src)
    local char = qb and qb.PlayerData and qb.PlayerData.charinfo
    if char then
        return ((char.firstname or 'Unknown') .. ' ' .. (char.lastname or '')):gsub('%s+$', '')
    end
    return GetPlayerName(src) or 'Unknown'
end

function Bridge.GetGang(src)
    if Config.Leaderboard.gangSource == 'none' then return '' end
    local qb = player(src)
    local data = qb and qb.PlayerData and qb.PlayerData[Config.Leaderboard.gangSource == 'job' and 'job' or 'gang']
    if not data or data.name == 'none' then return '' end
    return data.label or data.name or ''
end

function Bridge.GetDiscordId(src)
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier:sub(1, 8) == 'discord:' then return identifier:sub(9) end
    end
end

function Bridge.Notify(src, title, message, kind)
    TriggerClientEvent('ox_lib:notify', src, {
        title = title or 'Hopouts', description = message or '',
        type = ({ inform = 'info', success = 'success', error = 'error' })[kind or 'inform'] or 'info',
        duration = 5000
    })
end

function Bridge.AddMoney(src, account, amount)
    amount = math.floor(tonumber(amount) or 0)
    local qb = player(src)
    if amount <= 0 or not qb then return false end
    if account ~= 'cash' and account ~= 'bank' then return false end
    return qb.Functions.AddMoney(account, amount, 'fearx-hopouts-reward') ~= false
end

function Bridge.OnPlayerLogout(fn) logoutHandlers[#logoutHandlers + 1] = fn end

local function fire(handlers, src)
    src = tonumber(src)
    if not src then return end
    for i = 1, #handlers do pcall(handlers[i], src) end
end

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) fire(logoutHandlers, src) end)
