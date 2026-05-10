local nearby = require('openmw.nearby')
local types = require('openmw.types')
local self = require('openmw.self')

return {
    eventHandlers = {
        Died = function()
            local enemyLevel = types.Actor.stats.level(self.object).current

            for _, actor in ipairs(nearby.actors) do
                if actor.type == types.Player then
                    actor:sendEvent('GrantEnduranceReward', { level = enemyLevel })
                end
            end
        end
    }
}
