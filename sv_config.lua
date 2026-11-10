SvConfig = {}

-- Discord avatars + display names (lobby, ready check, in-match squads).
-- The bot only needs to exist — no guild permissions required.
-- "Bot" is prepended to the token for you.
SvConfig.Discord = {
    enabled = false,
    botToken = '',
    cacheMinutes = 120
}
