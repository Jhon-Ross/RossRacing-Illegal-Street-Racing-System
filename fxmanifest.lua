--[[ 
██████╗  ██████╗ ███████╗███████╗ 
██╔══██╗██╔═══██╗██╔════╝██╔════╝ 
██████╔╝██║   ██║███████╗███████╗ 
██╔══██╗██║   ██║╚════██║╚════██║ 
██║  ██║╚██████╔╝███████║███████║ 
╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝ 

========================================================= 
R.R.S - ROSS Racing System 
Illegal Street Racing Solution 
Property of ROSS Development 
========================================================= 
]] 

fx_version 'cerulean'
game 'gta5'

author 'RossRacing'
description 'RossRacing – Illegal Street Racing System'
version '1.0.0'

shared_scripts {
    'config.lua',
    'circuitos.lua'
}

client_scripts {
    '@vrp/lib/Utils.lua',
    'client.lua'
}

server_scripts {
    '@vrp/lib/Utils.lua',
    'server-vetrine.lua'
}
