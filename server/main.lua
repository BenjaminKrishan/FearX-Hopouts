Hopouts = {
    sessions = {}, parties = {}, queue = {}, matches = {},
    stats = {}, partySeq = 0, matchSeq = 0, readySeq = 0,
    readyChecks = {}
}

local sessions, parties, queue, matches = Hopouts.sessions, Hopouts.parties, Hopouts.queue, Hopouts.matches
local readyChecks = Hopouts.readyChecks
local enabledMaps = {}
for _, map in ipairs(Config.Maps) do if map.enabled then enabledMaps[#enabledMaps + 1] = map end end
assert(#enabledMaps > 0, '[FearX-Hopouts] Enable at least one map in config_maps.lua')

local function debug(message)
    if Config.Debug then print('[FearX-Hopouts] ' .. message) end
end

local function online(src)
    return src and GetPlayerPing(src) and GetPlayerPing(src) > 0
end

local function session(src)
    if not sessions[src] then sessions[src] = { status = 'world' } end
    return sessions[src]
end

local function defaultStats(src)
    return {
        identifier = Bridge.GetIdentifier(src), rating = Config.Ranks.startRating,
        wins = 0, losses = 0, kills = 0, deaths = 0, headshots = 0,
        playtime = 0, streak = 0, best_streak = 0, credits = 0,
        gang = Bridge.GetGang(src), name = Bridge.GetName(src), avatar = '',
        loadout_owned = nil, loadout_eq = nil
    }
end

function Hopouts.GetStats(src)
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return defaultStats(src) end
    local cached = Hopouts.stats[identifier]
    if cached then return cached end
    MySQL.insert.await('INSERT IGNORE INTO fx_hopouts_stats (identifier, rating, name, gang) VALUES (?, ?, ?, ?)', {
        identifier, Config.Ranks.startRating, Bridge.GetName(src), Bridge.GetGang(src)
    })
    local stats = MySQL.single.await('SELECT * FROM fx_hopouts_stats WHERE identifier = ?', { identifier })
    Hopouts.stats[identifier] = stats or defaultStats(src)
    return Hopouts.stats[identifier]
end

function Hopouts.RefreshStats(src)
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    Hopouts.stats[identifier] = nil
    return Hopouts.GetStats(src)
end

function Hopouts.GetMatch(id)
    id = tonumber(id)
    return id and matches[id] or nil
end

local function myRank(identifier)
    if Config.Ranks.enabled then
        return MySQL.single.await('SELECT COUNT(*) + 1 AS position FROM fx_hopouts_stats WHERE rating > (SELECT rating FROM fx_hopouts_stats WHERE identifier = ?)', { identifier }).position
    end
    return MySQL.single.await('SELECT COUNT(*) + 1 AS position FROM fx_hopouts_stats WHERE wins > (SELECT wins FROM fx_hopouts_stats WHERE identifier = ?)', { identifier }).position
end

local function rankLabel(rating)
    for _, tier in ipairs(Config.Ranks.tiers) do
        if rating >= tier.min and (not tier.max or rating < tier.max) then return tier.label end
    end
    return 'Unranked'
end

-- ── Friends ──────────────────────────────────────────────────────────────
local function friendData(src)
    if not Config.Friends then return { friends = {}, incoming = {}, outgoing = {} } end
    local id = Bridge.GetIdentifier(src)
    local rows = MySQL.query.await('SELECT * FROM fx_hopouts_friends WHERE a = ? OR b = ? ORDER BY created DESC', { id, id }) or {}
    local onlineByIdentifier = {}
    for _, playerId in ipairs(GetPlayers()) do
        local playerIdNumber = tonumber(playerId)
        local identifier = Bridge.GetIdentifier(playerIdNumber)
        if identifier then onlineByIdentifier[identifier] = playerIdNumber end
    end
    local result = { friends = {}, incoming = {}, outgoing = {} }
    for _, row in ipairs(rows) do
        local other = row.a == id and row.b or row.a
        local stats = MySQL.single.await('SELECT name FROM fx_hopouts_stats WHERE identifier = ?', { other })
        local entry = { id = row.id, license = other, name = stats and stats.name ~= '' and stats.name or other }
        if row.status == 'accepted' then
            entry.online = onlineByIdentifier[other] ~= nil
            result.friends[#result.friends + 1] = entry
        elseif row.status == 'pending' and row.b == id then result.incoming[#result.incoming + 1] = entry
        elseif row.status == 'pending' then result.outgoing[#result.outgoing + 1] = entry end
    end
    return result
end

local function pushFriends(src)
    TriggerClientEvent('fx_hopouts:client:friendsUpdate', src, friendData(src))
end

-- ── Parties ──────────────────────────────────────────────────────────────
local function removeQueue(partyId)
    for i = #queue, 1, -1 do if queue[i] == partyId then table.remove(queue, i) end end
end

local function broadcastParty(partyId)
    local party = parties[partyId]
    if not party then return end
    local names, avatars = {}, {}
    for slot, src in ipairs(party.members) do
        names[tostring(slot)] = Bridge.GetName(src)
        avatars[tostring(slot)] = Hopouts.GetStats(src).avatar or ''
    end
    for slot, src in ipairs(party.members) do
        TriggerClientEvent('fx_hopouts:client:teamUpdate', src, {
            size = #party.members, slots = names, avatars = avatars,
            yourSlot = slot, leaderSlot = 1
        })
    end
end

local function createParty(src)
    local state = session(src)
    if state.party and parties[state.party] then return state.party end
    Hopouts.partySeq = Hopouts.partySeq + 1
    local id = Hopouts.partySeq
    parties[id] = { id = id, members = { src } }
    state.party = id
    broadcastParty(id)
    return id
end

local function disbandParty(id)
    local party = parties[id]
    if not party then return end
    removeQueue(id)
    for _, src in ipairs(party.members) do
        if sessions[src] then
            sessions[src].party = nil
            if sessions[src].status == 'queue' then sessions[src].status = 'lobby' end
            TriggerClientEvent('fx_hopouts:client:queueState', src, false)
        end
    end
    parties[id] = nil
end

local function leaveParty(src, skipCreate)
    local state = session(src)
    local party = state.party and parties[state.party]
    if not party then return end
    if state.status == 'match' or state.status == 'ready' then return end
    removeQueue(party.id)
    for i, member in ipairs(party.members) do
        if member == src then table.remove(party.members, i); break end
    end
    state.party = nil
    state.status = 'lobby'
    TriggerClientEvent('fx_hopouts:client:queueState', src, false)
    if #party.members == 0 then parties[party.id] = nil
    else
        for _, member in ipairs(party.members) do
            if sessions[member] and sessions[member].status == 'queue' then sessions[member].status = 'lobby' end
            TriggerClientEvent('fx_hopouts:client:queueState', member, false)
        end
        broadcastParty(party.id)
    end
    if not skipCreate then createParty(src) end
end

local function partyCanQueue(party)
    if not party or #party.members < 1 or #party.members > Config.MaxQueueSize then return false end
    for _, src in ipairs(party.members) do
        if not online(src) or not Bridge.IsLoaded(src) or not sessions[src] or sessions[src].status ~= 'queue' then return false end
    end
    return true
end

-- ── Match lifecycle ──────────────────────────────────────────────────────
local beginRound, finishMatch

local function playerList(match, team)
    local list = {}
    for src, entry in pairs(match.players) do
        if entry.team == team then list[#list + 1] = { source = src, name = entry.name, avatar = entry.avatar or '', ready = entry.ready == true } end
    end
    table.sort(list, function(a, b) return a.source < b.source end)
    return list
end

local function startReady(partyA, partyB)
    Hopouts.readySeq = Hopouts.readySeq + 1
    local id = Hopouts.readySeq
    local check = { id = id, parties = { partyA.id, partyB.id }, players = {}, seconds = Config.ReadyCheck.seconds, done = false }
    readyChecks[id] = check
    for _, party in ipairs({ partyA, partyB }) do
        for _, src in ipairs(party.members) do
            check.players[src] = false
            sessions[src].status = 'ready'; sessions[src].ready = id
        end
    end

    CreateThread(function()
        while not check.done do
            local everyone = true
            for src, accepted in pairs(check.players) do if not accepted then everyone = false; break end end
            if everyone then
                check.done = true; readyChecks[id] = nil
                local a, b = parties[check.parties[1]], parties[check.parties[2]]
                if a and b then CreateThread(function() Hopouts.CreateMatch(a, b) end) end
                return
            end
            for src in pairs(check.players) do
                -- Ready rosters are built directly to retain acceptance states.
                local mine, theirs = {}, {}
                for member, accepted in pairs(check.players) do
                    local target = (sessions[member] and sessions[member].party == sessions[src].party) and mine or theirs
                    target[#target + 1] = { name = Bridge.GetName(member), avatar = Hopouts.GetStats(member).avatar or '', ready = accepted }
                end
                TriggerClientEvent('fx_hopouts:client:readyCheck', src, {
                    id = id, size = math.floor((#mine + #theirs) / 2), seconds = check.seconds,
                    total = Config.ReadyCheck.seconds, mine = mine, theirs = theirs
                })
            end
            if check.seconds <= 0 then
                check.done = true; readyChecks[id] = nil
                for _, partyId in ipairs(check.parties) do
                    local party = parties[partyId]
                    if party then
                        local accepted = true
                        for _, src in ipairs(party.members) do if not check.players[src] then accepted = false end end
                        for _, src in ipairs(party.members) do
                            if sessions[src] then sessions[src].status = accepted and 'queue' or 'lobby'; sessions[src].ready = nil end
                            TriggerClientEvent('fx_hopouts:client:readyDone', src)
                            TriggerClientEvent('fx_hopouts:client:queueState', src, accepted)
                            if not accepted then Bridge.Notify(src, 'Hopouts', 'Ready check failed. Your party left the queue.', 'error') end
                        end
                        if accepted then table.insert(queue, 1, party.id) else removeQueue(party.id) end
                    end
                end
                return
            end
            check.seconds = check.seconds - 1
            Wait(1000)
        end
    end)
end

local function cancelMatch(match, reason)
    if matches[match.id] then matches[match.id] = nil end
    for src in pairs(match.players) do
        if online(src) then
            SetPlayerRoutingBucket(src, 0)
            if sessions[src] then sessions[src].status = 'world'; sessions[src].match = nil end
            TriggerClientEvent('fx_hopouts:serverCancelled', src, reason)
        end
    end
end

function Hopouts.CreateMatch(partyA, partyB)
    removeQueue(partyA.id); removeQueue(partyB.id)
    if not partyA or not partyB or #partyA.members ~= #partyB.members then return end
    Hopouts.matchSeq = Hopouts.matchSeq + 1
    local id = Hopouts.matchSeq
    local match = {
        id = id, map = enabledMaps[math.random(#enabledMaps)], players = {}, parties = { partyA.id, partyB.id },
        score = { [1] = 0, [2] = 0 }, round = 0, phase = 'starting', started = os.time()
    }
    matches[id] = match

    for team, party in ipairs({ partyA, partyB }) do
        for slot, src in ipairs(party.members) do
            if not online(src) or not Bridge.IsLoaded(src) then cancelMatch(match, 'A player disconnected before the match started.'); return end
            local identifier = Bridge.GetIdentifier(src)
            local stats = Hopouts.GetStats(src)
            match.players[src] = {
                source = src, identifier = identifier, team = team, slot = slot,
                name = Bridge.GetName(src), avatar = stats.avatar or '', alive = true,
                kills = 0, deaths = 0, headshots = 0, health = 200, armor = 100
            }
            sessions[src].status = 'match'; sessions[src].match = id; sessions[src].ready = nil
            SetPlayerRoutingBucket(src, Config.RoutingBucketBase + id)
        end
    end

    for src, entry in pairs(match.players) do
        local opponents = playerList(match, entry.team == 1 and 2 or 1)
        local names = {}
        for _, opponent in ipairs(opponents) do names[#names + 1] = opponent.name end
        TriggerClientEvent('fx_hopouts:client:matchStart', src, {
            id = id, map = match.map.name, opponent = table.concat(names, ', '), team = entry.team, slot = entry.slot
        })
    end
    -- Seed the in-match squad HUD immediately; don't wait for the first health
    -- report from each client before teammates can see one another.
    SquadServer.SyncMatch(match)
    debug(('Match %d started: %dv%d on %s'):format(id, #partyA.members, #partyB.members, match.map.id))
    SetTimeout(1000, function() if matches[id] then beginRound(match) end end)
end

local function zonePhase(match, round, phase)
    CreateThread(function()
        local previous = match.map.storm.radius
        for index, definition in ipairs(Config.Storm.phases) do
            if not matches[match.id] or match.round ~= round or match.phase ~= 'live' then return end
            local radius = match.map.storm.radius * definition.radiusMult
            for src in pairs(match.players) do
                if online(src) then TriggerClientEvent('fx_hopouts:client:zoneUpdate', src, {
                    id = match.id, round = round, center = match.map.storm.center,
                    fromRadius = previous, radius = radius, duration = definition.shrink,
                    dps = definition.dps
                }) end
            end
            Wait(definition.shrink + definition.hold)
            previous = radius
        end
    end)
end

beginRound = function(match)
    if not matches[match.id] then return end
    match.round = match.round + 1
    match.phase = 'countdown'
    for src, entry in pairs(match.players) do
        entry.alive = online(src); entry.reportedAlive = true
        if online(src) then
            local team = entry.team == 1 and 'red' or 'blue'
            local spawn = match.map[team].spawns[((entry.slot - 1) % #match.map[team].spawns) + 1]
            TriggerClientEvent('fx_hopouts:client:roundStart', src, {
                id = match.id, round = match.round, ms = Config.CountdownMs, score = match.score,
                spawn = spawn, kit = LoadoutServer.Kit(src), vehicles = match.map[team].vehicles,
                vehicleOwner = entry.slot == 1
            })
        end
    end
    local round = match.round
    SetTimeout(Config.CountdownMs, function()
        if not matches[match.id] or match.round ~= round then return end
        match.phase = 'live'
        for src in pairs(match.players) do
            if online(src) then TriggerClientEvent('fx_hopouts:client:roundLive', src, { id = match.id, round = round, roundTime = Config.RoundTime }) end
        end
        zonePhase(match, round)
        SetTimeout(Config.RoundTime, function()
            if matches[match.id] and match.round == round and match.phase == 'live' then
                -- Timeout is a draw and the same round is replayed; no random winner.
                for src in pairs(match.players) do
                    if online(src) then TriggerClientEvent('fx_hopouts:client:roundEnd', src, { id = match.id, score = match.score, draw = true }) end
                end
                match.phase = 'intermission'
                SetTimeout(Config.IntermissionMs, function() if matches[match.id] then beginRound(match) end end)
            end
        end)
    end)
end

local function endRound(match, winner)
    if match.phase ~= 'live' then return end
    match.phase = 'intermission'
    if winner then match.score[winner] = match.score[winner] + 1 end
    for src, entry in pairs(match.players) do
        if online(src) then TriggerClientEvent('fx_hopouts:client:roundEnd', src, {
            id = match.id, score = match.score, won = winner == entry.team, draw = winner == nil
        }) end
    end
    if winner and match.score[winner] >= Config.RoundsToWin then
        SetTimeout(Config.IntermissionMs, function() if matches[match.id] then finishMatch(match, winner) end end)
    else
        SetTimeout(Config.IntermissionMs, function() if matches[match.id] then beginRound(match) end end)
    end
end

local function streakBonus(streak)
    local credits, elo, milestone = 0, 0, 0
    for _, bonus in ipairs(Config.WinStreaks) do
        if streak >= bonus.wins then credits, elo = bonus.credits, bonus.elo end
        if streak == bonus.wins then milestone = bonus.milestone or 0 end
    end
    return credits, elo, milestone
end

local function rewardPlayer(match, src, entry, winner)
    local won = entry.team == winner
    local stats = MySQL.single.await('SELECT * FROM fx_hopouts_stats WHERE identifier = ?', { entry.identifier }) or defaultStats(src)
    local oldRating = stats.rating or Config.Ranks.startRating
    local tier
    for _, candidate in ipairs(Config.Ranks.tiers) do
        if oldRating >= candidate.min and (not candidate.max or oldRating < candidate.max) then tier = candidate; break end
    end
    tier = tier or Config.Ranks.tiers[1]
    local streak = won and (stats.streak or 0) + 1 or 0
    local bonusCredits, bonusElo, milestone = 0, 0, 0
    if won then bonusCredits, bonusElo, milestone = streakBonus(streak) end
    local delta = Config.Ranks.enabled and ((won and tier.win or -tier.loss) + bonusElo) or 0
    local rating = math.max(0, oldRating + delta)
    local credits = (won and Config.Credits.win or Config.Credits.loss) + (entry.kills * Config.Credits.perKill) + bonusCredits + milestone
    credits = credits + match.score[entry.team] * Config.Credits.perRound
    local cash = Config.Cash.enabled and (won and Config.Cash.win or Config.Cash.loss) or 0
    MySQL.update.await([[UPDATE fx_hopouts_stats SET rating = ?, wins = wins + ?, losses = losses + ?,
        kills = kills + ?, deaths = deaths + ?, headshots = headshots + ?, playtime = playtime + ?,
        streak = ?, best_streak = GREATEST(best_streak, ?), credits = credits + ?, gang = ?, name = ? WHERE identifier = ?]], {
        rating, won and 1 or 0, won and 0 or 1, entry.kills, entry.deaths, entry.headshots,
        math.max(0, os.time() - match.started), streak, streak, credits, entry.gang or '', entry.name, entry.identifier
    })
    Hopouts.stats[entry.identifier] = nil
    if online(src) and cash > 0 then Bridge.AddMoney(src, Config.Cash.account, cash) end
    return { won = won, rating = rating, ratingDelta = rating - oldRating, reward = { credits = credits, cash = cash } }
end

finishMatch = function(match, winner, forfeiter)
    if not matches[match.id] or match.phase == 'ended' then return end
    match.phase = 'ended'
    matches[match.id] = nil
    for src, entry in pairs(match.players) do entry.gang = online(src) and Bridge.GetGang(src) or '' end
    for src, entry in pairs(match.players) do
        local result = rewardPlayer(match, src, entry, winner)
        if online(src) then
            TriggerClientEvent('fx_hopouts:client:matchEnd', src, {
                id = match.id, score = match.score, won = result.won, rating = result.rating,
                ratingDelta = result.ratingDelta, reward = result.reward
            })
        end
    end
    TriggerEvent('fx_hopouts:server:matchEnded', {
        id = match.id, map = match.map.id, winner = winner, score = match.score,
        forfeiter = forfeiter, players = match.players
    })
    SetTimeout(Config.EndScreenMs, function()
        for src in pairs(match.players) do
            if online(src) then
                RadioServer.Leave(src)
                SetPlayerRoutingBucket(src, 0)
                if sessions[src] then sessions[src].status = 'world'; sessions[src].match = nil end
                TriggerClientEvent('fx_hopouts:client:matchCleanup', src, { id = match.id })
            end
        end
    end)
end

local function checkElimination(match)
    if match.phase ~= 'live' then return end
    local alive = { [1] = false, [2] = false }
    for _, entry in pairs(match.players) do if entry.alive then alive[entry.team] = true end end
    if alive[1] and alive[2] then return end
    endRound(match, alive[1] and 1 or (alive[2] and 2 or nil))
end

RegisterNetEvent('fx_hopouts:server:died', function(matchId, round, killer, headshot)
    local src = source
    local match = Hopouts.GetMatch(matchId)
    local victim = match and match.players[src]
    if not victim or match.round ~= tonumber(round) or match.phase ~= 'live' or not victim.alive then return end
    victim.alive = false; victim.reportedAlive = false; victim.deaths = victim.deaths + 1
    killer = tonumber(killer)
    local attacker = killer and match.players[killer]
    if attacker and attacker.team ~= victim.team and attacker.alive then
        attacker.kills = attacker.kills + 1
        if headshot == true then attacker.headshots = attacker.headshots + 1 end
    end
    checkElimination(match)
end)

-- ── Queue worker ─────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(750)
        for i = 1, #queue do
            local paired = false
            for j = i + 1, #queue do
                local a, b = parties[queue[i]], parties[queue[j]]
                if a and b and #a.members == #b.members and partyCanQueue(a) and partyCanQueue(b) then
                    removeQueue(a.id); removeQueue(b.id)
                    if Config.ReadyCheck.enabled then startReady(a, b)
                    else CreateThread(function() Hopouts.CreateMatch(a, b) end) end
                    paired = true
                    break
                end
            end
            if paired then break end
        end
    end
end)

-- ── Lobby payload and career ─────────────────────────────────────────────
local function lobbyData(src)
    local state = session(src)
    DiscordAvatars.Refresh(src)
    local stats = Hopouts.GetStats(src)
    local order = Config.Ranks.enabled and 'rating DESC, wins DESC' or 'wins DESC, rating DESC'
    local leaderboard = MySQL.query.await(('SELECT * FROM fx_hopouts_stats ORDER BY %s LIMIT %d'):format(order, Config.Leaderboard.limit)) or {}
    local total = MySQL.single.await('SELECT COUNT(*) AS total FROM fx_hopouts_stats', {})
    for _, row in ipairs(leaderboard) do row.you = row.identifier == stats.identifier end
    local data = {
        ok = true, playerName = Bridge.GetName(src), rating = stats.rating, wins = stats.wins,
        losses = stats.losses, kills = stats.kills, deaths = stats.deaths, credits = stats.credits,
        avatar = stats.avatar or '', myRank = myRank(stats.identifier), totalPlayers = total.total,
        cash = Config.Cash, jackpot = Config.Jackpot, monthly = Config.Monthly,
        friends = friendData(src), leaderboard = leaderboard,
        inQueue = state.status == 'queue', partyInvite = state.invite
    }
    return data
end

local function careerData(src)
    local stats = Hopouts.GetStats(src)
    local matchesPlayed = (stats.wins or 0) + (stats.losses or 0)
    return {
        name = Bridge.GetName(src), avatar = stats.avatar or '', rating = stats.rating,
        rank = myRank(stats.identifier), rankLabel = rankLabel(stats.rating), wins = stats.wins,
        losses = stats.losses, matches = matchesPlayed,
        winRate = matchesPlayed > 0 and math.floor(stats.wins / matchesPlayed * 100 + 0.5) or 0,
        wl = stats.losses > 0 and stats.wins / stats.losses or stats.wins,
        kills = stats.kills, deaths = stats.deaths,
        kd = stats.deaths > 0 and stats.kills / stats.deaths or stats.kills,
        headshots = stats.headshots, hsRate = stats.kills > 0 and math.floor(stats.headshots / stats.kills * 100 + 0.5) or 0,
        streak = stats.streak, bestStreak = stats.best_streak,
        playedHours = math.floor((stats.playtime or 0) / 360) / 10, credits = stats.credits
    }
end

-- ── Secure NUI callbacks ─────────────────────────────────────────────────
local function register(name, handler)
    lib.callback.register('fx_hopouts:server:' .. name, function(src, data)
        if not Bridge.IsLoaded(src) then return { ok = false, reason = 'Character not loaded.' } end
        return handler(src, type(data) == 'table' and data or {})
    end)
end

register('getLobby', function(src) return lobbyData(src) end)
register('career', function(src) return careerData(src) end)
register('storeGet', function(src) return LoadoutServer.Store(src) end)
register('loadoutGet', function(src) return LoadoutServer.Get(src) end)
register('storeBuy', function(src, data) return LoadoutServer.BuyStore(src, tostring(data.id or '')) end)
register('loadoutBuy', function(src, data) return LoadoutServer.Buy(src, tostring(data.id or '')) end)
register('loadoutEquip', function(src, data) return LoadoutServer.Equip(src, tostring(data.id or '')) end)

register('queue', function(src, data)
    local state = session(src)
    if state.status == 'match' or state.status == 'ready' then return { ok = false, reason = 'You are already in a match.' } end
    local partyId = createParty(src)
    local party = parties[partyId]
    if party.members[1] ~= src then return { ok = false, reason = 'Only the party leader can queue.', inQueue = state.status == 'queue' } end
    if data.join then
        if #party.members > Config.MaxQueueSize then return { ok = false, reason = ('Maximum queue size is %d.'):format(Config.MaxQueueSize) } end
        for _, member in ipairs(party.members) do
            if not online(member) or not sessions[member] or sessions[member].status ~= 'lobby' then
                return { ok = false, reason = 'Every party member must have the hopouts lobby open.', inQueue = false }
            end
        end
        removeQueue(partyId); queue[#queue + 1] = partyId
        for _, member in ipairs(party.members) do sessions[member].status = 'queue'; TriggerClientEvent('fx_hopouts:client:queueState', member, true) end
        return { ok = true, inQueue = true }
    end
    removeQueue(partyId)
    for _, member in ipairs(party.members) do sessions[member].status = 'lobby'; TriggerClientEvent('fx_hopouts:client:queueState', member, false) end
    return { ok = true, inQueue = false }
end)

register('partyLeave', function(src)
    if session(src).status == 'match' or session(src).status == 'ready' then return { ok = false, reason = 'You cannot leave now.' } end
    leaveParty(src); return { ok = true }
end)

register('partyKick', function(src, data)
    local party = parties[session(src).party]
    local slot = tonumber(data.slot)
    if not party or party.members[1] ~= src or not slot or not party.members[slot] then return { ok = false, reason = 'Only the leader can kick a valid slot.' } end
    if session(src).status ~= 'lobby' then return { ok = false, reason = 'Leave the queue first.' } end
    local target = party.members[slot]
    if target == src then return { ok = false, reason = 'Use Leave Party instead.' } end
    leaveParty(target); broadcastParty(party.id); return { ok = true }
end)

register('partyRespond', function(src, data)
    local state = session(src)
    local invite = state.invite
    state.invite = nil
    if not invite or not data.accept then return { ok = true } end
    local party = parties[invite.party]
    if not party or not online(party.members[1]) or #party.members >= Config.MaxParty then return { ok = false, reason = 'That party is no longer available.' } end
    if state.status ~= 'lobby' then return { ok = false, reason = 'Open the hopouts lobby before accepting.' } end
    leaveParty(src, true)
    party.members[#party.members + 1] = src
    state.party, state.status = party.id, 'lobby'
    broadcastParty(party.id)
    return { ok = true }
end)

register('friendsAdd', function(src, data)
    if not Config.Friends then return { ok = false, reason = 'Friends are disabled.' } end
    local target = tonumber(data.id)
    if not target or target == src or not online(target) or not Bridge.IsLoaded(target) then return { ok = false, reason = 'Enter a valid online player ID.' } end
    local a, b = Bridge.GetIdentifier(src), Bridge.GetIdentifier(target)
    local existing = MySQL.single.await('SELECT * FROM fx_hopouts_friends WHERE (a = ? AND b = ?) OR (a = ? AND b = ?)', { a, b, b, a })
    if existing then return { ok = false, reason = existing.status == 'accepted' and 'You are already friends.' or 'A request is already pending.' } end
    MySQL.insert.await('INSERT INTO fx_hopouts_friends (a, b, status, created) VALUES (?, ?, ?, ?)', { a, b, 'pending', os.time() })
    pushFriends(src); pushFriends(target)
    return { ok = true, friends = friendData(src) }
end)

register('friendsRespond', function(src, data)
    local id, b = tonumber(data.id), Bridge.GetIdentifier(src)
    local row = id and MySQL.single.await('SELECT * FROM fx_hopouts_friends WHERE id = ? AND b = ? AND status = ?', { id, b, 'pending' })
    if not row then return { ok = false, reason = 'Request not found.' } end
    if data.accept then MySQL.update.await('UPDATE fx_hopouts_friends SET status = ? WHERE id = ?', { 'accepted', id })
    else MySQL.update.await('DELETE FROM fx_hopouts_friends WHERE id = ?', { id }) end
    for _, playerId in ipairs(GetPlayers()) do
        local playerSrc = tonumber(playerId)
        if Bridge.GetIdentifier(playerSrc) == row.a then pushFriends(playerSrc) end
    end
    return { ok = true, friends = friendData(src) }
end)

register('friendsInvite', function(src, data)
    local state = session(src)
    local id = Bridge.GetIdentifier(src)
    local accepted = MySQL.single.await('SELECT * FROM fx_hopouts_friends WHERE status = ? AND ((a = ? AND b = ?) OR (a = ? AND b = ?))', {
        'accepted', id, tostring(data.license or ''), tostring(data.license or ''), id
    })
    if not accepted then return { ok = false, reason = 'You can only invite friends.' } end
    local target
    for _, playerId in ipairs(GetPlayers()) do
        local playerSrc = tonumber(playerId)
        if Bridge.GetIdentifier(playerSrc) == tostring(data.license) then target = playerSrc; break end
    end
    if not target then return { ok = false, reason = 'That friend is offline.' } end
    if session(target).status ~= 'lobby' then return { ok = false, reason = 'Your friend must be in the hopouts lobby.' } end
    local partyId = createParty(src)
    local party = parties[partyId]
    if party.members[1] ~= src or #party.members >= Config.MaxParty then return { ok = false, reason = 'Your party cannot accept more players.' } end
    if session(src).status ~= 'lobby' then return { ok = false, reason = 'Leave the queue before inviting.' } end
    local now = os.time()
    if state.lastInvite and now - state.lastInvite < Config.PartyInviteCooldown then
        return { ok = false, reason = 'Please wait before sending another party invite.' }
    end
    state.lastInvite = now
    session(target).invite = { party = partyId, name = Bridge.GetName(src) }
    TriggerClientEvent('fx_hopouts:client:partyInvite', target, session(target).invite)
    return { ok = true }
end)

register('ready', function(src, data)
    local state = session(src)
    local check = state.ready and readyChecks[state.ready]
    if not check or check.players[src] == nil then return { ok = false } end
    if data.accept then check.players[src] = true
    else
        check.done = true; readyChecks[check.id] = nil
        for _, partyId in ipairs(check.parties) do
            local party = parties[partyId]
            if party then
                local accepted = true
                for _, member in ipairs(party.members) do if not check.players[member] then accepted = false end end
                for _, member in ipairs(party.members) do
                    if sessions[member] then sessions[member].status = accepted and 'queue' or 'lobby'; sessions[member].ready = nil end
                    TriggerClientEvent('fx_hopouts:client:readyDone', member)
                    TriggerClientEvent('fx_hopouts:client:queueState', member, accepted)
                end
                removeQueue(partyId)
                if accepted then table.insert(queue, 1, partyId) end
            end
        end
        Bridge.Notify(src, 'Hopouts', 'Match declined. The fully ready party kept its queue position.', 'inform')
    end
    return { ok = true }
end)

-- ── Connection and command lifecycle ─────────────────────────────────────
RegisterNetEvent('fx_hopouts:server:open', function()
    local src = source
    if not Bridge.IsLoaded(src) or session(src).status == 'match' then return end
    local state = session(src)
    state.status = state.status == 'queue' and 'queue' or 'lobby'
    local ped = GetPlayerPed(src)
    if ped and ped > 0 then
        local coords = GetEntityCoords(ped)
        state.returnCoords = { x = coords.x, y = coords.y, z = coords.z, w = GetEntityHeading(ped) }
    end
    createParty(src)
end)

RegisterNetEvent('fx_hopouts:server:close', function()
    local src = source
    local state = session(src)
    if state.status == 'queue' then
        local party = parties[state.party]
        if party then
            removeQueue(party.id)
            for _, member in ipairs(party.members) do
                sessions[member].status = 'lobby'
                TriggerClientEvent('fx_hopouts:client:queueState', member, false)
            end
        end
    end
    if state.status ~= 'match' and state.status ~= 'ready' then state.status = 'world' end
end)

RegisterNetEvent('fx_hopouts:server:forfeit', function()
    local src = source
    local state = session(src)
    local match = state.match and matches[state.match]
    if not match then return end
    local entry = match.players[src]
    finishMatch(match, entry.team == 1 and 2 or 1, src)
end)

local function disconnected(src)
    src = tonumber(src)
    local state = sessions[src]
    if state then
        local match = state.match and matches[state.match]
        if match and match.players[src] then
            match.players[src].alive = false
            finishMatch(match, match.players[src].team == 1 and 2 or 1, src)
        elseif state.ready and readyChecks[state.ready] then
            local check = readyChecks[state.ready]
            check.done = true; readyChecks[check.id] = nil
            for member in pairs(check.players) do
                if sessions[member] then sessions[member].status = 'lobby'; sessions[member].ready = nil end
                TriggerClientEvent('fx_hopouts:client:readyDone', member)
                TriggerClientEvent('fx_hopouts:client:queueState', member, false)
            end
            removeQueue(check.parties[1]); removeQueue(check.parties[2])
        end
        state.status = 'world'; state.match = nil; state.ready = nil
        leaveParty(src, true)
    end
    sessions[src] = nil
    Bridge.ForgetIdentifier(src)
end

AddEventHandler('playerDropped', function() disconnected(source) end)
Bridge.OnPlayerLogout(function(src) disconnected(src) end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, match in pairs(matches) do
        for src in pairs(match.players) do
            if online(src) then
                SetPlayerRoutingBucket(src, 0)
                RadioServer.Leave(src)
            end
        end
    end
end)

CreateThread(function()
    Wait(1000)
    print('^2[FearX-Hopouts]^0 QBCore-only open-source build ready. ox_lib + oxmysql loaded.')
end)
