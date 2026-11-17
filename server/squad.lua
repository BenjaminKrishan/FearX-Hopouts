-- Match-only squad health replication. Health reports never change player health.
SquadServer = {}

local function membersFor(match, team, recipient)
    local members = {}
    for memberSrc, member in pairs(match.players) do
        if member.team == team then
            members[#members + 1] = {
                source = memberSrc,
                name = member.name,
                avatar = member.avatar or '',
                health = member.health or 200,
                armor = member.armor or 0,
                alive = member.alive and member.reportedAlive ~= false,
                you = memberSrc == recipient
            }
        end
    end
    table.sort(members, function(a, b) return a.source < b.source end)
    return members
end

function SquadServer.Broadcast(match, team)
    if not match or not match.players then return end
    for recipient, member in pairs(match.players) do
        if member.team == team and GetPlayerPing(recipient) > 0 then
            TriggerClientEvent('fx_hopouts:client:squad', recipient, membersFor(match, team, recipient))
        end
    end
end

function SquadServer.SyncMatch(match)
    if not match or not match.players then return end
    local teams = {}
    for _, member in pairs(match.players) do teams[member.team] = true end
    for team in pairs(teams) do SquadServer.Broadcast(match, team) end
end

RegisterNetEvent('fx_hopouts:server:squadHealth', function(matchId, health, armor, alive)
    local src = source
    local match = Hopouts.GetMatch(matchId)
    local entry = match and match.players[src]
    if not entry then return end

    entry.health = math.max(0, math.min(200, math.floor(tonumber(health) or 0)))
    entry.armor = math.max(0, math.min(100, math.floor(tonumber(armor) or 0)))
    entry.reportedAlive = alive == true
    SquadServer.Broadcast(match, entry.team)
end)
