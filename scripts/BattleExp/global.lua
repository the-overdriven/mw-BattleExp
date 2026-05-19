local H = require('scripts/BattleExp/helpers')
local log = H.log

local storage = require('openmw.storage')
local summons = storage.globalSection('BattleExpSummons')

local playerSummons = {}

return {
  interfaceName = 'BattleExp',
  interface = {
    registerSummon = function(actor)
      log('registerSummon: %s', tostring(actor.id))
      playerSummons[actor.id] = true
    end,
    unregisterSummon = function(actor)
      log('unregisterSummon: %s', tostring(actor.id))
      playerSummons[actor.id] = nil
    end,
    isPlayerSummon = function(actor)
      local result = playerSummons[actor.id] == true
      log('isPlayerSummon: %s -> %s', tostring(actor.id), tostring(result))
      return result
    end,
  },
  eventHandlers = {
    RegisterPlayerSummon = function(actor)
      log('RegisterPlayerSummon event: %s', tostring(actor.id))
      summons:set(actor.id, true)
    end,
  }
}
