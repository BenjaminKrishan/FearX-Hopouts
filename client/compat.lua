--[[═══════════════════════════════════════════════════════════════════════════
    FearX-Hopouts — inventory & ambulance compatibility (client)

    A match takes players out of the normal world: it hands out native weapons,
    empties the inventory and kills people over and over. An inventory script
    and an ambulance script will both fight that unless they are told not to,
    so every popular one is handled here.

    None of it is required. A resource that isn't running is skipped and every
    call is guarded, so an inventory or ambulance this file has never heard of
    still works through the three universal paths:

      * the invBusy / inv_busy flags nearly every inventory reads
      * the loadout watchdog, which simply hands the guns back to anything that
        takes them away
      * a death check that counts "downed" as dead, however that state is held

    Everything here is escrow-ignored — add your own resource to either list.
═══════════════════════════════════════════════════════════════════════════]]--

local FXB = exports.fearx_bridge

Compat = { Inventory = {}, Ambulance = {} }

local function running(resource)
    return GetResourceState(resource) == 'started'
end

--- Every call into another resource goes through here. A missing export or a
--- renamed event is then a silent no-op instead of an error mid-match.
local function attempt(fn, ...)
    local ok = pcall(fn, ...)
    return ok
end

-- ═══════════════════════════════════════════════════════════════════════════
--  INVENTORIES
--
--  close        called once when the match locks the inventory
--  disable      called with true on lock and false on unlock
--  weaponGuard  called with true for the length of the match, false after —
--               for inventories that police the ped's weapons and delete
--               anything without a matching item (which is the whole match
--               loadout). Anything without a documented opt-out is covered by
--               the loadout watchdog in client/main.lua instead.
-- ═══════════════════════════════════════════════════════════════════════════

local INVENTORIES = {
    {
        resource = 'ox_inventory',
        close = function() exports.ox_inventory:closeInventory() end,
        -- Weapon.Disarm runs every 200ms and removes any weapon that is not an
        -- inventory item, which deleted the match loadout right after it was
        -- handed out. Turning the weapon wheel on opts out of that guard.
        weaponGuard = function(suspended) exports.ox_inventory:weaponWheel(suspended) end
    },
    {
        resource = 'qb-inventory',
        close = function() TriggerEvent('inventory:client:CloseInventory') end
    },
    {
        resource = 'ps-inventory',
        close = function() TriggerEvent('inventory:client:CloseInventory') end
    },
    {
        resource = 'qs-inventory',
        close = function() exports['qs-inventory']:closeInventory() end
    },
    {
        resource = 'origen_inventory',
        close = function() exports.origen_inventory:closeInventory() end
    },
    {
        resource = 'codem-inventory',
        close = function() TriggerEvent('codem-inventory:client:closeinventory') end
    },
    {
        resource = 'core_inventory',
        close = function() TriggerEvent('core_inventory:client:closeInventory') end
    },
    {
        resource = 'tgiann-inventory',
        close = function() exports['tgiann-inventory']:CloseInventory() end
    },
    {
        resource = 'esx_inventoryhud',
        close = function() TriggerEvent('esx_inventoryhud:closeInventory') end,
        disable = function(locked) TriggerEvent('esx_inventoryhud:disableInventory', locked) end
    }
}

--- Close the inventory and keep it shut for the match, so nobody uses their
--- own gear. Called with false again when the match hands them back.
function Compat.Inventory.lock(locked)
    if Config.Match.lockInventory == false then return end

    -- The two flags nearly every inventory checks before it will open.
    LocalPlayer.state:set('invBusy', locked, true)
    LocalPlayer.state:set('inv_busy', locked, true)
    -- What the qb-derived inventories listen for instead.
    attempt(TriggerEvent, 'inventory:client:busy:status', locked)

    for i = 1, #INVENTORIES do
        local inventory = INVENTORIES[i]
        if running(inventory.resource) then
            if locked and inventory.close then attempt(inventory.close) end
            if inventory.disable then attempt(inventory.disable, locked) end
        end
    end
end

--- Opt out of the weapon guards that would strip the native match loadout.
function Compat.Inventory.suspendWeaponGuard(suspended)
    for i = 1, #INVENTORIES do
        local inventory = INVENTORIES[i]
        if inventory.weaponGuard and running(inventory.resource) then
            attempt(inventory.weaponGuard, suspended)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  AMBULANCE / DEATH
--
--  The revive itself is fearx_bridge's job — it ships a module per ambulance
--  script (wasabi v1 + v2, qbx_medical, ak47, ars, brutal, p_ambulancejob,
--  esx_ambulancejob, qb-ambulancejob, …) and picks the right one. What hopouts
--  adds on top is the part a duel needs: knowing the moment someone is out of
--  the fight, and never coming back to life the wrong way.
-- ═══════════════════════════════════════════════════════════════════════════

-- Every flag the popular ambulance scripts hold "dead" or "downed" in.
local DEATH_FLAGS = {
    'dead', 'isdead', 'isDead',
    'inlaststand', 'isLastStand', 'laststand'
}

function Compat.Ambulance.name()
    local ok, name = pcall(function() return FXB:GetAmbulance() end)
    if not ok or type(name) ~= 'string' or name == '' then return 'none' end
    return name
end

function Compat.Ambulance.present()
    return Compat.Ambulance.name() ~= 'none'
end

--- True the moment the player is out of the fight — dead OR downed.
---
--- IsEntityDead on its own is not enough. Most modern ambulance scripts leave
--- the ped alive on low health and put them into a downed / last stand state
--- instead, so a round would sit there waiting for a death that never arrives
--- while the "dead" player lies on the floor.
function Compat.Ambulance.isDead()
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return true end

    local state = LocalPlayer.state
    for i = 1, #DEATH_FLAGS do
        if state[DEATH_FLAGS[i]] then return true end
    end

    -- wasabi v1 only exposes it as an export; v2 added the state bag above.
    if running('wasabi_ambulance') then
        local ok, dead = pcall(function() return exports.wasabi_ambulance:isPlayerDead() end)
        if ok and dead == true then return true end
    end

    local ok, dead = pcall(function() return FXB:IsPlayerDead() end)
    return ok and dead == true
end

--- Clear the ambulance script's death state, server side included, so a player
--- who died in a round doesn't walk out of the match still flagged as dead.
function Compat.Ambulance.clearDeath()
    attempt(function() FXB:SetDeathStatus(false) end)
    local state = LocalPlayer.state
    for i = 1, #DEATH_FLAGS do
        local flag = DEATH_FLAGS[i]
        -- Only write the ones that are actually set: every set() replicates.
        if state[flag] then state:set(flag, false, true) end
    end
end

--- Bring the player back for the next round.
---
--- The ambulance script's own revive is always tried first. Several of them
--- (ak47, wasabi v2) ship an anti-exploit that kicks anyone who comes back to
--- life without going through it, so a raw resurrect is the fallback for
--- servers with no ambulance script — never the first move.
function Compat.Ambulance.revive()
    -- Only for players who are actually down. Most rounds most players are
    -- alive, and firing a revive at them would put a burst of pointless server
    -- events through the ambulance script every single round.
    if not Compat.Ambulance.isDead() then return PlayerPedId() end

    if Config.Match.useAmbulanceRevive ~= false and Compat.Ambulance.present() then
        attempt(function() FXB:RevivePlayer() end)
    end
    Compat.Ambulance.clearDeath()

    local ped = PlayerPedId()
    if IsEntityDead(ped) then
        local coords = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
        ped = PlayerPedId()
    end
    return ped
end
