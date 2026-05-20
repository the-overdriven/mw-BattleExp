local H = require('scripts/BattleExp/helpers')
local log = H.log

local storage = require('openmw.storage')
local summons = storage.globalSection('BattleExpSummons')

local settings = storage.globalSection('SettingsBattleExp')
local DEBUG = settings:get('debug')
H.setDebug(DEBUG)

return {
  eventHandlers = {
    RegisterPlayerSummon = function(actor)
      log('RegisterPlayerSummon event: %s', tostring(actor.id))
      summons:set(actor.id, true)
    end,
  }
}
