fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mw_rental'
author 'Most Wanted Roleplay'
description 'Car rental - Most Wanted Roleplay'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/en.lua',
    'locales/sr.lua',
    'shared/locale.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'bridge/server.lua',
    'server/keys.lua',
    'server/main.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js',
}

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
}