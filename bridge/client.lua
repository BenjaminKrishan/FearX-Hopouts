--[[
    FearX-Hopouts — fearx_bridge adapter (client)

    Only two things are needed client-side: "is my character loaded", and a
    logout hook so the lobby closes when someone switches character.
    fearx_bridge has no logout hook, so the raw framework events are listened
    for below — they are only event names, and an event whose framework isn't
    running simply never fires.
]]--

local FXB = exports.fearx_bridge

Bridge = {}

--- Has the player finished spawning in as a character?
function Bridge.IsLoaded()
    local ok, loaded = pcall(function() return FXB:IsPlayerLoaded() end)
    return not ok or loaded ~= false
end

function Bridge.GetInventory()
    local ok, name = pcall(function() return FXB:GetInventory() end)
    if ok and type(name) == 'string' and name ~= '' then return name end
    return 'none'
end

function Bridge.Notify(message, kind, title)
    local map = { inform = 'info', success = 'success', error = 'error' }
    pcall(function()
        FXB:Notify(title or 'Hopouts', message or '', map[kind or 'inform'] or 'info', 6000)
    end)
end

-- ── Logout hook ──────────────────────────────────────────────────────────

local logoutHandlers = {}

function Bridge.OnLogout(fn) logoutHandlers[#logoutHandlers + 1] = fn end

local function fireLogout()
    for i = 1, #logoutHandlers do pcall(logoutHandlers[i]) end
end

RegisterNetEvent('esx:onPlayerLogout', fireLogout)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', fireLogout)
RegisterNetEvent('qbx_core:client:playerLoggedOut', fireLogout)
