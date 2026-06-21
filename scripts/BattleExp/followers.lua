-- if you have a follower, advance them automatically on joining and when gaining Battle Exp lvl
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

local function calculateFollowerLevel(battleExpLevel)
  local advances = battleExpLevel - 5

  if advances <= 0 then
    return 1
  end

  local level = 1 + math.floor(3.394 * math.sqrt(advances))
  return level
end

local function syncFollowerToTargetLevel(npc, targetFollowerLevel)
  local trainedCount = getTrainedCount(npc)
  while trainedCount < targetFollowerLevel do
    trainFollowerOnce(npc)
    trainedCount = trainedCount + 1
  end
  setTrainedCount(npc, trainedCount)
end

local function onPlayerBattleExpLevelUp(newSkillLevel)
  local targetFollowerLevel = calculateFollowerLevel(newSkillLevel)
  for _, npc in ipairs(getActiveFollowers()) do
    syncFollowerToTargetLevel(npc, targetFollowerLevel)
  end
end

local function onFollowerRecruited(npc)
  setTrainedCount(npc, 0)
  local currentBattleExpLevel = getPlayerBattleExpLevel()
  local targetFollowerLevel = calculateFollowerLevel(currentBattleExpLevel)
  syncFollowerToTargetLevel(npc, targetFollowerLevel)
end

local function trainFollowerOnce(npc)
  local skills = types.NPC.stats.skills
  local attributes = types.Actor.stats.attributes

  -- bump all skills +1
  local skillList = {
    'acrobatics', 'alchemy', 'alteration', 'armorer', 'athletics',
    'axe', 'block', 'bluntWeapon', 'conjuration', 'destruction',
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

  -- bump HP (+10% of current endurance, as in vanilla, but retroactive)
  local enduranceStat = attributes.endurance(npc)
  local healthMod = math.floor(enduranceStat.modified / 10)

  local healthStat = types.Actor.stats.dynamic.health(npc)
  healthStat.base = healthStat.base + healthMod
end

return {
  trainFollowerOnce = trainFollowerOnce,
  onFollowerRecruited = onFollowerRecruited,
  onPlayerBattleExpLevelUp = onPlayerBattleExpLevelUp,
  syncFollowerToTargetLevel = syncFollowerToTargetLevel,
  calculateFollowerLevel = calculateFollowerLevel
}
