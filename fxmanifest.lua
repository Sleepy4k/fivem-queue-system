--// FX Information \\--
fx_version   'adamant'
use_fxv2_oal 'no'
lua54        'yes'
game         'gta5'

--// Resource Information \\--
name         'NKCore Queue'
author       'Benjamin4k'
version      '1.0.0'
repository   'https://github.com/naka-studios/NKCore'
description  'NKCore player connect handler with queue system'

--// Manifest \\--
server_scripts {
	'config/server.lua',

	'server/function.lua',
	'server/main.lua'
}