local nearby = require('openmw.nearby')
local types = require('openmw.types')
local self = require('openmw.self')
local I = require('openmw.interfaces')
local core = require('openmw.core')
local storage = require('openmw.storage')
local summons = storage.globalSection('BattleExpSummons')

local H = require('scripts/BattleExp/helpers')
local log = H.log

local isThisActorPlayerSummon = false
local lastAttacker = nil

local function findPlayer()
  for _, actor in ipairs(nearby.actors) do
    if types.Player.objectIsInstance(actor) then
      return actor
    end
  end
  return nil
end

local function getPlayerActiveSummonEffects(playerObj)
  local summonEffects = {}
  for _, effect in pairs(types.Actor.activeEffects(playerObj)) do
    if effect.id:find('^summon') then
      summonEffects[(effect.name:gsub('Summon', 'Summoned'))] = true
    end
  end
  return summonEffects
end

local function getEnemyName(object)
  if types.NPC.objectIsInstance(object) then
    return types.NPC.record(object).name
  elseif types.Creature.objectIsInstance(object) then
    return types.Creature.record(object).name
  end
  return 'Unknown Enemy'
end

local function checkAndCachePlayerSummon()
  local playerObj = findPlayer()
  if not playerObj then
    log('no player found')
    return
  end

  local creatureName = tostring(getEnemyName(self.object))
  local recordId = self.recordId

  log('checkAndCachePlayerSummon')
  log('creature (self.recordId): %s', tostring(recordId))
  log('creature name: %s', creatureName)

  if not recordId:find('_summ') then
    log('not a summon creature, skipping')
    return
  end

  local AI = I.AI
  if not AI then return end

  -- At spawn time, before combat, Follow->player should be the active package
  -- during combat, summons positioned close to enemy, will be in combat from the start
  local package = AI.getActivePackage(self.object)
  log(string.format('summon has currently package type: %s', tostring(package and package.type)))

  if package and package.type == 'Combat' then
    -- summon is in combat from the start, but might have been summoned by player during combat
    local playerSummonEffects = getPlayerActiveSummonEffects(playerObj)
    if not next(playerSummonEffects) then
      log('player has no active summon effects, not a player summon')
      return
    end

    for key, value in pairs(playerSummonEffects) do
      log('player has active summon spell: %s', tostring(value))
    end

    if playerSummonEffects[creatureName] then
      log('active effect name matched with creature name (not bulletproof)')
    else
      log('player has currently no summon effects active or summon name did not match')
      return
    end

    log('This summon was probably summoned by the player')
    isThisActorPlayerSummon = true
    core.sendGlobalEvent('RegisterPlayerSummon', self.object)
    return
  end

  if not (package and package.type == 'Follow' and package.target and types.Player.objectIsInstance(package.target)) then
    log('This summon was not summoned by the player!')
    return
  end

  log('This summon is a player\'s summon, caching')
  isThisActorPlayerSummon = true
  core.sendGlobalEvent('RegisterPlayerSummon', self.object)
end

I.Combat.addOnHitHandler(function(attack)
  log('addOnHitHandler')
  if attack.attacker then
    log('attacker registered: %s', tostring(attack.attacker))
    lastAttacker = attack.attacker
  end
end)

local function isPlayerAlly(actor)
  if summons:get(actor.id) then 
    log('The killer, %s is player\'s summon!', actor)
    return true 
  end

  local AI = I.AI
  if not AI then return false end
  local package = AI.getActivePackage(actor)
  if not package then return false end
  return package.target and types.Player.objectIsInstance(package.target)
end

return {
  engineHandlers = {
    onInit = checkAndCachePlayerSummon,
  },
  eventHandlers = {
    Died = function()
      local enemyName = getEnemyName(self.object)
      local enemyLevel = types.Actor.stats.level(self.object).current
      local payload = { level = enemyLevel, name = enemyName }
      log(string.format('"Died" event fired for %s', tostring(enemyName)))
      if not lastAttacker then
        -- killer is unknown, maybe magic was used?
        for _, actor in ipairs(nearby.actors) do
          if types.Player.objectIsInstance(actor) then
            actor:sendEvent('GrantBattleExpConditionally', payload)
            break
          end
        end
        log('No lastAttacker!')
        return
      end
      if not lastAttacker.isValid then
        log('lastAttacker not valid!')
        return
      end
      local isKillerPlayer = types.Player.objectIsInstance(lastAttacker)
      local isKillerPlayerAlly = not isKillerPlayer and isPlayerAlly(lastAttacker)
      log(string.format('lastAttacker: %s', tostring(getEnemyName(lastAttacker))))
      log(string.format('isKillerPlayer: %s', tostring(isKillerPlayer)))
      log(string.format('isKillerPlayerAlly: %s', tostring(isKillerPlayerAlly)))
      if not isKillerPlayer and not isKillerPlayerAlly then
        log('Killer is not player or ally, skipping...')
        return
      end

      if isKillerPlayer then
        lastAttacker:sendEvent('GrantBattleExp', payload)
      else
        for _, actor in ipairs(nearby.actors) do
          if types.Player.objectIsInstance(actor) then
            actor:sendEvent('GrantBattleExp', payload)
            break
          end
        end
      end
    end
  }
}
