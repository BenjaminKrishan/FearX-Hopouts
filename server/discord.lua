-- Optional Discord avatar cache. The token is server-only in sv_config.lua.
DiscordAvatars = { attempts = {} }

function DiscordAvatars.Refresh(src)
    local settings = SvConfig.Discord
    if not settings.enabled or settings.botToken == '' then return end
    local discordId = Bridge.GetDiscordId(src)
    if not discordId then return end
    local now = os.time()
    local previous = DiscordAvatars.attempts[src]
    if previous and now - previous < (settings.cacheMinutes or 120) * 60 then return end
    DiscordAvatars.attempts[src] = now

    PerformHttpRequest('https://discord.com/api/v10/users/' .. discordId, function(status, body)
        if status ~= 200 then return end
        local ok, user = pcall(json.decode, body)
        if not ok or type(user) ~= 'table' then return end
        local avatar = ''
        if user.avatar then
            avatar = ('https://cdn.discordapp.com/avatars/%s/%s.png?size=256'):format(discordId, user.avatar)
        end
        local identifier = Bridge.GetIdentifier(src)
        if identifier then
            MySQL.update('UPDATE fx_hopouts_stats SET avatar = ? WHERE identifier = ?', { avatar, identifier })
            if Hopouts.stats[identifier] then Hopouts.stats[identifier].avatar = avatar end
        end
    end, 'GET', '', { ['Authorization'] = 'Bot ' .. settings.botToken, ['Content-Type'] = 'application/json' })
end

AddEventHandler('playerDropped', function() DiscordAvatars.attempts[source] = nil end)
