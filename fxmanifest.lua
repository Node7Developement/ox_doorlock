--[[ FX Information ]]--
fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'rdr3'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

--[[ Resource Information ]]--
name 'ox_doorlock'
version '1.18.0-node7.6'
license 'GPL-3.0-or-later'
author 'Overextended'
repository 'https://github.com/overextended/ox_doorlock'
description 'NODE7 RedM door locking with restart relocking, true player-load lifecycle, targets, inventory, and lockpick integration.'

--[[ Manifest ]]--
shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/utils.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'web/build/index.html'

files {
    'web/build/index.html',
    'web/build/**/*',
    'locales/*.json',
}

dependencies {
    'oxmysql',
    'ox_lib',
    'ox_target',
    'node7-core',
    'node7-inventory',
    'node7-lockpick-minigame',
}

ox_libs {
    'locale',
    'table',
}
