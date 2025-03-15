fx_version 'cerulean'
game 'gta5'

author 'Enzonami'
description 'Gang turf siege with integrated Advanced AI'
version '1.0.0'

lua54 'yes'

escrow_ignore {
    'shared/config.lua'
}

shared_scripts {
    'shared/config.lua'
}

server_scripts {
    'server/version.lua',
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}

client_scripts {
    '@ox_lib/init.lua',
    'client/client.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/index.js'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'oxmysql',
    'cw-crafting',
    'ox_target',
}

dependency '/assetpacks'
