fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'
author 'Evolent'
description 'Evolent Studio: Ingame Photos'
version '1.0.1'

dependencies {
    'ox_lib',
    'oxmysql',
}

shared_script '@ox_lib/init.lua'
client_script 'client/init.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/init.lua',
    'server/discord.js',
}

ui_page 'web/build/index.html'

files {
    'config.lua',
    'shared/*.lua',
    'client/*.lua',
    'web/build/index.html',
    'web/build/assets/*',
    'images/*',
    'photos/*',
}
