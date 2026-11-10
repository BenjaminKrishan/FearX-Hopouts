-- QBCore inventory and qb-ambulancejob compatibility.
Compat = { Inventory = {}, Ambulance = {} }

local function running(resource)
    return GetResourceState(resource) == 'started'
end

local function attempt(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and Config.Debug then print('[FearX-Hopouts] compatibility call failed: ' .. tostring(err)) end
end

function Compat.Inventory.lock(locked)
    if Config.Match.lockInventory == false then return end
    LocalPlayer.state:set('invBusy', locked, true)
    LocalPlayer.state:set('inv_busy', locked, true)
    LocalPlayer.state:set('hopoutsLocked', locked, true)
    TriggerEvent('inventory:client:busy:status', locked)
    if locked then
        if running('ox_inventory') then attempt(function() exports.ox_inventory:closeInventory() end) end
        TriggerEvent('inventory:client:CloseInventory')
    end
end

-- ox_inventory removes native weapons unless its weapon wheel guard is enabled.
function Compat.Inventory.suspendWeaponGuard(suspended)
    if running('ox_inventory') then
        attempt(function() exports.ox_inventory:weaponWheel(suspended) end)
    end
end

local DEATH_FLAGS = { 'dead', 'isdead', 'isDead', 'inlaststand', 'isLastStand', 'laststand' }

function Compat.Ambulance.isDead()
    local ped = PlayerPedId()
    if IsEntityDead(ped) or GetEntityHealth(ped) <= 101 then return true end
    local state = LocalPlayer.state
    for i = 1, #DEATH_FLAGS do
        if state[DEATH_FLAGS[i]] then return true end
    end
    return false
end

function Compat.Ambulance.clearDeath()
    local state = LocalPlayer.state
    for i = 1, #DEATH_FLAGS do
        if state[DEATH_FLAGS[i]] then state:set(DEATH_FLAGS[i], false, true) end
    end
end

function Compat.Ambulance.revive()
    if running('qb-ambulancejob') and Compat.Ambulance.isDead() then
        TriggerEvent('hospital:client:Revive')
    end
    Compat.Ambulance.clearDeath()
    local ped = PlayerPedId()
    if IsEntityDead(ped) then
        local coords = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
        ped = PlayerPedId()
    end
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, 200)
    SetPedArmour(ped, Config.RoundArmor or 100)
    return ped
end
