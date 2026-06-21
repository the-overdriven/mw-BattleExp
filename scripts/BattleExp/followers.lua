-- if you have a follower, advance them automatically when recruiting and when gaining Battle Exp lvl
-- BE skill | advances | followerLevel
-- ---------|----------|--------------
--    5     |    0     |      1
--    6     |    1     |      4
--    7     |    2     |      5
--    8     |    3     |      6
--    9     |    4     |      7
--   10     |    5     |      8
--   11     |    6     |      9
--   12     |    7     |      9
--   13     |    8     |     10
--   14     |    9     |     11
--   15     |   10     |     11
--   16     |   11     |     12
--   17     |   12     |     12
--   18     |   13     |     13
--   19     |   14     |     13
--   20     |   15     |     14
--   25     |   20     |     16
--   30     |   25     |     17
--   35     |   30     |     19
--   40     |   35     |     21
--   45     |   40     |     22
--   50     |   45     |     23
--   55     |   50     |     25
--   60     |   55     |     26

local types = require('openmw.types')
local H = require('scripts/BattleExp/helpers')
local log = H.log
local findPlayer = H.findPlayer

-- maps player's Battle Exp skill level to the level the follower will be advanced to (see table above)
local function calculateTargetFollowerLevel(battleExpLevel)
  local advances = battleExpLevel - 5

  if advances <= 0 then
    return 1
  end

  return 1 + math.floor(3.394 * math.sqrt(advances))
end

local function trainFollowerOnce(npc)
  -- local skills = types.NPC.stats.skills
  local skills = types.NPC.stats.skills
  local attributes = types.Actor.stats.attributes

  -- bump all skills +1
  local skillList = {
    'acrobatics', 'alchemy', 'alteration', 'armorer', 'athletics',
    'axe', 'block', 'bluntweapon', 'conjuration', 'destruction',
    'enchant', 'handtohand', 'heavyarmor', 'illusion', 'lightarmor',
    'longblade', 'marksman', 'mediumarmor', 'mercantile', 'mysticism',
    'restoration', 'security', 'shortblade', 'sneak', 'spear',
    'speechcraft', 'unarmored'
  }
  for _, skillId in ipairs(skillList) do
    local stat = skills[skillId](npc)
    stat.base = stat.base + 1
  end

  -- bump all attributes +1
  local attributeList = {
    'agility', 'endurance', 'intelligence', 'luck',
    'personality', 'speed', 'strength', 'willpower'
  }
  for _, attrId in ipairs(attributeList) do
    local stat = attributes[attrId](npc)
    stat.base = stat.base + 1
  end  
end

local function syncFollowerToTargetLevel(npc, targetFollowerLevel)
  log('syncFollowerToTargetLevel')
  local currentLevel = types.NPC.stats.level(npc).current
  local trainedCount = 0

  log('currentLevel: %s, targetFollowerLevel: %s', currentLevel, targetFollowerLevel)

  if currentLevel == targetFollowerLevel then
    return
  end

  log('%s is catching up with player', types.NPC.record(npc).name)

  -- train follower for each level gap (i.e. 3x when he's level 4 and target is 7)
  while (currentLevel + trainedCount) < targetFollowerLevel do
    trainFollowerOnce(npc)
    trainedCount = trainedCount + 1
  end

  -- after the loop, currentLevel + trainedCount should be equal to targetFollowerLevel
  -- bump HP ((currentStrength + currentEndurance) / 2 as base + 10% of current endurance per level - as in vanilla, but retroactive)
  local attributes = types.Actor.stats.attributes
  local currentStrength = attributes.strength(npc).base
  local currentEndurance = attributes.endurance(npc).base
  local totalHP = math.floor((currentStrength + currentEndurance) / 2)
                + math.floor(currentEndurance * 0.1 * (targetFollowerLevel - 1))
  local npcName = types.NPC.record(npc.object).name
  log('%s HP was: %s', npcName, tostring(types.Actor.stats.dynamic.health(npc).base))
  types.Actor.stats.dynamic.health(npc).base = totalHP
  log('%s HP is: %s', npcName, tostring(types.Actor.stats.dynamic.health(npc).base))

  -- bump lvl
  log('%s level: %s', npcName, tostring(types.NPC.stats.level(npc).current))
  types.NPC.stats.level(npc).current = targetFollowerLevel
  log('%s leveled to: %s', npcName, tostring(types.NPC.stats.level(npc).current))
end

local function onPlayerBattleExpLevelUp(newSkillLevel, allFollowers, nearbyActors)
  log('onPlayerBattleExpLevelUp, allFollowers: %s', allFollowers)
  local targetFollowerLevel = calculateTargetFollowerLevel(newSkillLevel)
  
  for recordId, isFollower in pairs(allFollowers) do
    if isFollower then
      local foundLiveNpc = nil
      
      for _, actor in ipairs(nearbyActors) do
        if actor.recordId == recordId then
          foundLiveNpc = actor
          break
        end
      end
      
      if foundLiveNpc then
        log('found follower NPC in world: %s', tostring(foundLiveNpc))
        foundLiveNpc:sendEvent('SyncLevelEvent', { targetFollowerLevel = targetFollowerLevel })
      else
        log('Follower not resolved (not nearby/loaded): %s', tostring(recordId))
      end
    end
  end
end

local function onFollowerRecruited(npc, battleExpLevel)
  log('followers onFollowerRecruited')

  local targetFollowerLevel = calculateTargetFollowerLevel(battleExpLevel)
  syncFollowerToTargetLevel(npc, targetFollowerLevel)
end

return {
  onFollowerRecruited = onFollowerRecruited,
  onPlayerBattleExpLevelUp = onPlayerBattleExpLevelUp,
  syncFollowerToTargetLevel = syncFollowerToTargetLevel,
}
