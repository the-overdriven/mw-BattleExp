-- if you have a follower, advance them automatically when recruiting and when gaining Battle Exp lvl
-- BE skill | advances | followerLevel | HP (new recruit) | HP (with player since lvl 1)
-- -------- | -------- | ------------- | ---------------- | ----------------------------
--        5 |        0 |             1 |               40 |                           40
--        6 |        1 |             4 |               55 |                           56
--        7 |        2 |             5 |               61 |                           63
--        8 |        3 |             6 |               67 |                           70
--        9 |        4 |             7 |               73 |                           78
--       10 |        5 |             8 |               79 |                           85
--       11 |        6 |             9 |               86 |                           94
--       12 |        7 |             9 |               86 |                           95
--       13 |        8 |            10 |               93 |                          104
--       14 |        9 |            11 |              100 |                          113
--       15 |       10 |            11 |              100 |                          115
--       16 |       11 |            12 |              107 |                          124
--       17 |       12 |            12 |              107 |                          126
--       18 |       13 |            13 |              114 |                          136
--       19 |       14 |            13 |              114 |                          138
--       20 |       15 |            14 |              121 |                          148
--       25 |       20 |            16 |              137 |                          177
--       30 |       25 |            18 |              153 |                          208
--       35 |       30 |            19 |              162 |                          231
--       40 |       35 |            21 |              180 |                          267
--       45 |       40 |            22 |              189 |                          293
--       50 |       45 |            23 |              198 |                          319
--       55 |       50 |            25 |              217 |                          362
--       60 |       55 |            26 |              227 |                          392
-- examples in the table assume the follower NPC join the player on lvl 1-3 with 40 Endurance and Strength
-- these are extreme cases, most NPC start with higher lvls and it pays off to recruit them early game

local types = require('openmw.types')

local H = require('scripts/BattleExp/helpers')
local log = H.log
local findPlayer = H.findPlayer

local storage = require('openmw.storage')
local settings = storage.globalSection('SettingsBattleExp')

-- scales follower level with the player's Battle Exp skill level (see table above)
local function calculateTargetFollowerLevel(battleExpLevel)
  local playerBattleExpAdvances = battleExpLevel - 5

  if playerBattleExpAdvances <= 0 then
    return 1
  end

  return 1 + math.floor(3.4 * math.sqrt(playerBattleExpAdvances))
end

local function trainFollowerOnce(npc)
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
    types.NPC.stats.skills[skillId](npc).base = types.NPC.stats.skills[skillId](npc).base + 1
  end

  -- bump all attributes +1
  local attributeList = {
    'agility', 'endurance', 'intelligence', 'luck',
    'personality', 'speed', 'strength', 'willpower'
  }
  for _, attrId in ipairs(attributeList) do
    types.Actor.stats.attributes[attrId](npc).base = types.Actor.stats.attributes[attrId](npc).base + 1
  end  
end

local function recalculateHP(npc, level)
  -- bump HP ((currentStrength + currentEndurance) / 2 as base + 10% of current endurance per level - as in vanilla, but retroactive)
  local npcName = types.NPC.record(npc.object).name
  local attributes = types.Actor.stats.attributes
  local currentStrength = attributes.strength(npc).base
  local currentEndurance = attributes.endurance(npc).base
  local totalHP = math.floor((currentStrength + currentEndurance) / 2)
                + math.floor(currentEndurance * 0.1 * (level - 1))
  log('%s HP was: %s', npcName, tostring(types.Actor.stats.dynamic.health(npc).base))
  types.Actor.stats.dynamic.health(npc).base = totalHP
  log('%s HP is: %s', npcName, tostring(types.Actor.stats.dynamic.health(npc).base))
end

local function grantBonusEndurance(npc)
  local npcLevel = types.NPC.stats.level(npc).current
  local npcName = types.NPC.record(npc.object).name -- TODO: move to helpers?
  log('%s is granted 1 point of bonus Endurance (due to player\'s BattleExp advance)', npcName)
  local attributes = types.Actor.stats.attributes
  local currentEndurance = attributes.endurance(npc).base
  log('endurance before: %s', attributes.endurance(npc).base)
  attributes.endurance(npc).base = attributes.endurance(npc).base + 1
  log('endurance after: %s', attributes.endurance(npc).base)

  recalculateHP(npc, npcLevel) -- recalculateHP does not run every time in syncFollowerToTargetLevel
end

local function syncFollowerToTargetLevel(npc, targetFollowerLevel)
  log('syncFollowerToTargetLevel')
  local npcName = types.NPC.record(npc.object).name
  local currentLevel = types.NPC.stats.level(npc).current
  local trainedCount = 0

  log('currentLevel: %s, targetFollowerLevel: %s', currentLevel, targetFollowerLevel)

  if currentLevel >= targetFollowerLevel then
    log('%s lvl already matches player\'s BattleExp level', npcName)
    return
  end

  log('%s is catching up with player', npcName)

  -- train follower for each level gap (i.e. 3x when he's level 4 and target is 7)
  while (currentLevel + trainedCount) < targetFollowerLevel do
    trainFollowerOnce(npc)
    trainedCount = trainedCount + 1
  end

  -- bump lvl
  log('%s level: %s', npcName, tostring(types.NPC.stats.level(npc).current))
  types.NPC.stats.level(npc).current = targetFollowerLevel
  log('%s leveled to: %s', npcName, tostring(types.NPC.stats.level(npc).current))

  -- after the loop, currentLevel + trainedCount should be equal to targetFollowerLevel
  recalculateHP(npc, targetFollowerLevel)
end

local function onPlayerBattleExpLevelUp(newSkillLevel, allFollowers, nearbyActors)
  log('onPlayerBattleExpLevelUp, allFollowers: %s', allFollowers)
  allFollowers = allFollowers or {}
  nearbyActors = nearbyActors or {}
  local targetFollowerLevel = calculateTargetFollowerLevel(newSkillLevel)
  
  for recordId, isFollower in pairs(allFollowers) do
    if isFollower then
      local foundLiveNpc = nil

      for _, actor in ipairs(nearbyActors) do
        -- log('is this actor.id %s our follower? %s', actor.id, recordId)

        -- if actor.recordId == recordId then
        if actor.id == recordId then
          foundLiveNpc = actor
          break
        end
      end
      
      if foundLiveNpc then
        log('found follower NPC in world: %s', tostring(foundLiveNpc))

        if (settings:get('rewardLongTermFollowers')) then
          foundLiveNpc:sendEvent('GrantFollowerBonusEndurance')          
        end

        foundLiveNpc:sendEvent('SyncLevelEvent', { targetFollowerLevel = targetFollowerLevel })
      else
        log('Follower not resolved (not nearby/loaded): %s', tostring(recordId))
      end
    end
  end
end

local function onFollowerRecruited(npc, battleExpLevel)
  local targetFollowerLevel = calculateTargetFollowerLevel(battleExpLevel)
  syncFollowerToTargetLevel(npc, targetFollowerLevel)
end

return {
  onFollowerRecruited = onFollowerRecruited,
  onPlayerBattleExpLevelUp = onPlayerBattleExpLevelUp,
  syncFollowerToTargetLevel = syncFollowerToTargetLevel,
  grantBonusEndurance = grantBonusEndurance,
}
