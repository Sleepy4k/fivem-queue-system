--// FX Information \\--
fx_version   'adamant'
use_fxv2_oal 'no'
lua54        'yes'
game         'gta5'

--// Resource Information \\--
name         'Fivem Queue'
author       'Benjamin4k'
version      '1.0.0'
repository   'https://github.com/sleepy4k/fivem-queue-system'
description  'Simple queue handler for NKCore Framework, look at https://github.com/naka-studios'

--// Manifest \\--
server_scripts {
	'config/server.lua',

	'server/function.lua',
	'server/main.lua'
}
