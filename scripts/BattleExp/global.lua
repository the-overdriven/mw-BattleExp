local H = require('scripts/BattleExp/helpers')
local log = H.log

local storage = require('openmw.storage')
local summons = storage.globalSection('BattleExpSummons')

return {
  eventHandlers = {
    RegisterPlayerSummon = function(actor)
      log('RegisterPlayerSummon event: %s', tostring(actor.id))
      summons:set(actor.id, true)
    end,
  }
}
