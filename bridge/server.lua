-- QBCore server adapter, including crash-recoverable inventory snapshots.
Bridge = {}

local QBCore = exports['qb-core']:GetCoreObject()
local identifiers = {}
local loadedHandlers, logoutHandlers = {}, {}

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

function Bridge.CanCarry(src, name, count)
    if GetResourceState('ox_inventory') == 'started' then
        local ok, result = pcall(function()
            return exports.ox_inventory:CanCarryItem(src, name, count or 1)
        end)
        return ok and result == true
    end
    return Bridge.IsLoaded(src)
end

function Bridge.AddItem(src, name, count, metadata)
    local qb = player(src)
    if not qb then return false end
    if GetResourceState('ox_inventory') == 'started' then
        local ok, result = pcall(function()
            return exports.ox_inventory:AddItem(src, name, count or 1, metadata)
        end)
        return ok and result ~= false
    end
    local ok, result = pcall(function()
        return qb.Functions.AddItem(name, count or 1, false, metadata or {}, 'fearx-hopouts-store')
    end)
    return ok and result ~= false
end

function Bridge.InventoryName()
    if GetResourceState('ox_inventory') == 'started' then return 'ox_inventory' end
    return 'qb-core'
end

function Bridge.CanSwapInventory()
    return Config.Match.clearInventory == true
end

-- Keep slot numbers as well as item data. QBCore inventory is slot based.
function Bridge.SnapshotInventory(src)
    if GetResourceState('ox_inventory') == 'started' then
        local ok, inventory = pcall(function() return exports.ox_inventory:getInventory(src) end)
        if not ok or type(inventory) ~= 'table' then return nil, 'Could not read ox_inventory.' end
        local items = inventory.items or inventory
        local snapshot = {}
        for slot, item in pairs(items) do
            if type(item) == 'table' and item.name and (item.count or 0) > 0 then
                snapshot[#snapshot + 1] = {
                    slot = item.slot or slot, name = item.name, count = item.count,
                    metadata = item.metadata or item.info or {}
                }
            end
        end
        return { backend = 'ox_inventory', items = snapshot }
    end

    local qb = player(src)
    if not qb or type(qb.PlayerData.items) ~= 'table' then return nil, 'Could not read QBCore inventory.' end
    return { backend = 'qb-core', items = json.decode(json.encode(qb.PlayerData.items)) }
end

function Bridge.ClearInventory(src)
    if GetResourceState('ox_inventory') == 'started' then
        local ok, result = pcall(function() return exports.ox_inventory:ClearInventory(src) end)
        return ok and result ~= false
    end
    local qb = player(src)
    if not qb then return false end
    local ok = pcall(function()
        if qb.Functions.ClearInventory then
            qb.Functions.ClearInventory()
        else
            qb.Functions.SetPlayerData('items', {})
        end
    end)
    return ok
end

function Bridge.RestoreInventory(src, snapshot)
    if type(snapshot) ~= 'table' then return false end
    if snapshot.backend == 'ox_inventory' then
        if GetResourceState('ox_inventory') ~= 'started' then return false end
        local cleared = Bridge.ClearInventory(src)
        if not cleared then return false end
        for _, item in ipairs(snapshot.items or {}) do
            local ok, result = pcall(function()
                return exports.ox_inventory:AddItem(src, item.name, item.count, item.metadata, item.slot)
            end)
            if not ok or result == false then return false end
        end
        return true
    end

    local qb = player(src)
    if not qb or snapshot.backend ~= 'qb-core' then return false end
    local ok = pcall(function()
        qb.Functions.SetPlayerData('items', snapshot.items or {})
        qb.Functions.Save()
    end)
    return ok
end

function Bridge.OnPlayerLoaded(fn) loadedHandlers[#loadedHandlers + 1] = fn end
function Bridge.OnPlayerLogout(fn) logoutHandlers[#logoutHandlers + 1] = fn end

local function fire(handlers, src)
    src = tonumber(src)
    if not src then return end
    for i = 1, #handlers do pcall(handlers[i], src) end
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(qb)
    fire(loadedHandlers, type(qb) == 'table' and qb.PlayerData and qb.PlayerData.source or qb)
end)
AddEventHandler('QBCore:Server:OnPlayerLoaded', function(src) fire(loadedHandlers, src) end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) fire(logoutHandlers, src) end)
