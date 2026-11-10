fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FearX'
description 'FearX-Hopouts — ranked street duels (runs on fearx_bridge: ESX / QBCore / Qbox / standalone)'
version '1.1.2'

escrow_ignore {
    'config.lua',
    'config_maps.lua',
    'sv_config.lua',
    'bridge/*.lua',
    'client/compat.lua',
    'client/radio.lua',
    'shared/images.lua',
    'sql/*.sql'
}

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
    'fearx_bridge',
    'ox_lib',
    'oxmysql'
}

dependency '/assetpacks'