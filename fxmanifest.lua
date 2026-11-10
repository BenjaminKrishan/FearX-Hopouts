fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'FearX-Hopouts'
author 'FearX / open-source contributors'
description 'QBCore ranked PvP hopouts with parties, rounds, storm, ranks and rewards'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'config_maps.lua',
    'shared/images.lua'
}

client_scripts {
    'bridge/client.lua',
    'client/compat.lua',
    'client/radio.lua',
    'client/squad.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'sv_config.lua',
    'bridge/server.lua',
    'server/radio.lua',
    'server/loadout.lua',
    'server/squad.lua',
    'server/discord.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/fonts/*',
    'html/img/*',
    'html/vendor/fontawesome/css/*',
    'html/vendor/fontawesome/webfonts/*'
}

dependencies {
    'qb-core',
    'ox_lib',
    'oxmysql'
}
