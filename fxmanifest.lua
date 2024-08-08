fx_version 'cerulean'
game 'gta5'
use_experimental_fxv2_oal 'yes'
lua54        'yes'

files {
    'config/server.lua',
    'config/client.lua',
}

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
}

client_scripts {
    -- imports
    '@qbx_core/modules/playerdata.lua',

    -- locals
    'client/main.lua',
}

server_scripts {
    -- imports
    '@oxmysql/lib/MySQL.lua',

    -- locals
    'server/main.lua',
}

