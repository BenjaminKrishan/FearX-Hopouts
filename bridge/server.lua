--[[
    FearX-Hopouts — fearx_bridge adapter (server)

    This resource contains no framework code of its own. Every ESX / QBCore /
    Qbox / inventory difference is fearx_bridge's job, configured in
    fearx_bridge/config.lua — set the framework, inventory and notify system
    there and hopouts follows automatically.

    Three things are normalised here, because fearx_bridge exposes them
    per-backend rather than uniformly:
      * item snapshots      ({name, count} vs {name, amount}, metadata vs info)
      * ESX's weapon loadout, which lives outside the item list
      * character loaded / logged out, which fearx_bridge has no hook for
]]--

local FXB = exports.fearx_bridge

Bridge = {}

CreateThread(function()
    -- fearx_bridge re-runs its own detection on a timer; give it a moment so
    -- the line we print is the one hopouts will actually run with.
    Wait(2500)
    Bridge.Framework = FXB:GetFramework()
    Bridge.InventoryKind = FXB:GetInventory()
    print(('[fx_hopouts] using fearx_bridge — framework: %s | inventory: %s'):format(
        tostring(Bridge.Framework), tostring(Bridge.InventoryKind)))
    if not Bridge.CanSwapInventory() and Config.Match and Config.Match.clearInventory then
        print('[fx_hopouts] ^3no inventory detected — match inventory swap is off, players keep their own items^0')
    end
end)

-- ── Identity ─────────────────────────────────────────────────────────────

-- Dropping and logging out both destroy the framework player object before our
-- handlers run, so the resolved identifier is remembered per session. Without
-- it a leaving player's stats would save under the wrong key.
local identifierCache = {}

function Bridge.GetIdentifier(src)
    src = tonumber(src)
    if not src then return nil end
    if identifierCache[src] then return identifierCache[src] end
    local ok, identifier = pcall(function() return FXB:GetPlayerIdentifier(src) end)
    if not ok or not identifier or identifier == '' then return nil end
    identifierCache[src] = identifier
    return identifier
end

--- Call once a leaving/logging-out player has been fully cleaned up.
function Bridge.ForgetIdentifier(src)
    identifierCache[tonumber(src) or 0] = nil
end

function Bridge.GetDiscordId(src)
    local ok, id = pcall(function() return FXB:GetPlayerDiscord(src) end)
    return ok and id or nil
end

-- ── Players ──────────────────────────────────────────────────────────────

function Bridge.IsLoaded(src)
    local ok, loaded = pcall(function() return FXB:IsPlayerLoaded(src) end)
    return ok and loaded == true
end

function Bridge.GetName(src)
    local ok, name = pcall(function() return FXB:GetPlayerName(src) end)
    if ok and type(name) == 'string' and name ~= '' then return name end
    return GetPlayerName(src) or 'Unknown'
end

--- Text for the leaderboard's gang column. See Config.Leaderboard.gangSource.
--- ESX has no gangs, so fearx_bridge returns the job there.
function Bridge.GetGang(src)
    local mode = (Config.Leaderboard and Config.Leaderboard.gangSource) or 'gang'
    if mode == 'none' then return '' end
    local ok, name, label = pcall(function()
        if mode == 'job' then return FXB:GetPlayerJob(src) end
        return FXB:GetPlayerGang(src)
    end)
    if not ok or not name or name == '' or name == 'none' then return '' end
    if type(label) == 'string' and label ~= '' then return label end
    return tostring(name)
end

--- Loaded players as { source = n, identifier = s }.
function Bridge.GetPlayers()
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and Bridge.IsLoaded(src) then
            out[#out + 1] = { source = src, identifier = Bridge.GetIdentifier(src) }
        end
    end
    return out
end

-- ── Money & items ────────────────────────────────────────────────────────

--- account is 'cash' or 'bank'; fearx_bridge maps those onto each framework.
function Bridge.AddMoney(src, account, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    local ok, result = pcall(function() return FXB:AddMoney(src, amount, account or 'cash') end)
    -- Only an explicit false means "not paid" (that is what the standalone
    -- stub returns); a backend that returns nothing is assumed to have worked.
    return ok and result ~= false
end

function Bridge.CanCarry(src, name, count)
    local ok, can = pcall(function() return FXB:CanCarryItem(src, name, count or 1) end)
    return not ok or can ~= false
end

function Bridge.AddItem(src, name, count, metadata)
    count = math.floor(tonumber(count) or 1)
    if count < 1 then return false end
    local ok, result = pcall(function() return FXB:AddItem(src, name, count, metadata) end)
    return ok and result ~= false
end

-- ── Notifications ────────────────────────────────────────────────────────

local NOTIFY_KIND = { inform = 'info', success = 'success', error = 'error' }

function Bridge.Notify(src, title, message, kind)
    pcall(function()
        FXB:Notify(src, title or 'Hopouts', message or '', NOTIFY_KIND[kind] or 'info', 6000)
    end)
end

-- ── Match inventory swap ─────────────────────────────────────────────────
-- Everything a player is carrying is stashed to the database and handed back
-- when the match ends, so nobody brings their own gear in.

function Bridge.InventoryName()
    local ok, name = pcall(function() return FXB:GetInventory() end)
    return ok and name or 'none'
end

--- true when the resolved inventory can actually be read + cleared.
function Bridge.CanSwapInventory()
    if not (Config.Match and Config.Match.clearInventory) then return false end
    local inventory = Bridge.InventoryName()
    return inventory ~= nil and inventory ~= 'none'
end

-- ESX's own inventory is the only backend that keeps weapons outside the item
-- list. Everywhere else weapons ARE items, so asking for them separately would
-- stash — and then duplicate — every gun.
local function hasSeparateLoadout()
    return Bridge.InventoryName() == 'esx'
end

local function weaponList(src)
    local ok, weapons = pcall(function() return FXB:GetWeapons(src) end)
    if not ok or type(weapons) ~= 'table' then return {} end
    return weapons
end

--- Snapshot of everything the player is carrying.
function Bridge.SnapshotInventory(src)
    local saved = {}

    local ok, items = pcall(function() return FXB:GetItems(src) end)
    if ok and type(items) == 'table' then
        for _, item in pairs(items) do
            if type(item) == 'table' and item.name then
                local count = tonumber(item.count or item.amount) or 0
                if count > 0 then
                    saved[#saved + 1] = {
                        name = item.name,
                        count = count,
                        metadata = item.metadata or item.info
                    }
                end
            end
        end
    end

    if hasSeparateLoadout() then
        for _, weapon in pairs(weaponList(src)) do
            if type(weapon) == 'table' and weapon.name then
                saved[#saved + 1] = { name = weapon.name, count = tonumber(weapon.ammo) or 0, weapon = true }
            end
        end
    end

    return saved
end

function Bridge.ClearInventory(src)
    -- ESX's ClearInventory only empties the item list, so strip the loadout too.
    if hasSeparateLoadout() then
        for _, weapon in pairs(weaponList(src)) do
            if type(weapon) == 'table' and weapon.name then
                pcall(function() FXB:RemoveWeapon(src, weapon.name) end)
            end
        end
    end
    pcall(function() FXB:ClearInventory(src) end)
end

--- Hand a stashed snapshot back.
function Bridge.RestoreInventory(src, items)
    if type(items) ~= 'table' then return end
    for i = 1, #items do
        local item = items[i]
        if item and item.name then
            if item.weapon then
                pcall(function() FXB:AddWeapon(src, item.name, item.count or 0) end)
            else
                Bridge.AddItem(src, item.name, item.count or 1, item.metadata)
            end
        end
    end
end

-- ── Lifecycle hooks ──────────────────────────────────────────────────────
-- fearx_bridge exposes no "character loaded / logged out" hook, so the raw
-- framework events are listened for here. They are only event names — an event
-- whose framework isn't running simply never fires.

local loadedHandlers, logoutHandlers = {}, {}

function Bridge.OnPlayerLoaded(fn) loadedHandlers[#loadedHandlers + 1] = fn end
function Bridge.OnPlayerLogout(fn) logoutHandlers[#logoutHandlers + 1] = fn end

local function fireLoaded(src)
    src = tonumber(src)
    if not src then return end
    for i = 1, #loadedHandlers do pcall(loadedHandlers[i], src) end
end

local function fireLogout(src)
    src = tonumber(src)
    if not src then return end
    for i = 1, #logoutHandlers do pcall(logoutHandlers[i], src) end
end

local function qbSource(player)
    if type(player) == 'table' and player.PlayerData then return player.PlayerData.source end
    return tonumber(player)
end

AddEventHandler('esx:playerLoaded', function(src) fireLoaded(src) end)
AddEventHandler('esx:playerLogout', function(src) fireLogout(src) end)
-- Qbox fires the QBCore-named events for compatibility, plus its own.
AddEventHandler('QBCore:Server:PlayerLoaded', function(player) fireLoaded(qbSource(player)) end)
AddEventHandler('QBCore:Server:OnPlayerLoaded', function(player) fireLoaded(qbSource(player)) end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) fireLogout(src) end)
AddEventHandler('qbx_core:server:playerLoaded', function(player) fireLoaded(qbSource(player)) end)
AddEventHandler('qbx_core:server:playerLoggedOut', function(src) fireLogout(src) end)
