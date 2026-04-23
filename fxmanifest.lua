fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'TMG_Manic'
description 'Allows players to work in the recycling plant for money'
version '1.0.0'

shared_scripts {
  '@tmg-core/shared/locale.lua',
  'locales/en.lua',
  'locales/*.lua',
  'config.lua'
}

client_script {
  'client/main.lua',
  '@PolyZone/client.lua',
  '@PolyZone/BoxZone.lua',
  '@PolyZone/CircleZone.lua'
}

server_script 'server/main.lua'
