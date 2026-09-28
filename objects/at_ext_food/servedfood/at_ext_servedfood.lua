local function configuredBites(value)
  value = tonumber(value) or 1
  return math.max(1, math.floor(value))
end

function init()
  self.food = root.assetJson(config.getParameter("foodConfig"))
  self.bites = configuredBites(self.food.bites)
  self.frames = self.food.frames or {"full", "empty"}
  if #self.frames == 0 then self.frames = {"default"} end

  local savedBites = storage.bitesRemaining
  if savedBites == nil then
    savedBites = config.getParameter("bitesRemaining", self.bites)
  end
  storage.bitesRemaining = math.max(0, math.min(self.bites, savedBites))
  object.setConfigParameter("bitesRemaining", storage.bitesRemaining)

  object.setInteractive(true)
  updateVisual()
end

function updateVisual()
  local eaten = self.bites - storage.bitesRemaining
  local frameIndex = math.min(eaten + 1, #self.frames)
  animator.setAnimationState("foodState", self.frames[frameIndex])

  if self.food.steamEmitter then
    animator.setParticleEmitterActive(self.food.steamEmitter, storage.bitesRemaining == self.bites)
  end
end

function feedPlayer(playerId)
  for _, effect in ipairs(self.food.effects or {}) do
    world.sendEntityMessage(playerId, "applyStatusEffect", effect.effect, effect.duration, entity.id())
  end

  if self.food.satietyEffect then
    world.sendEntityMessage(playerId, "applyStatusEffect", self.food.satietyEffect, self.food.satietyEffectDuration or 0.1, entity.id())
  end

  animator.playSound("eat")
end

function onInteraction(args)
  if storage.bitesRemaining <= 0 then
    object.smash(true)
    return
  end

  feedPlayer(args.sourceId)
  storage.bitesRemaining = storage.bitesRemaining - 1
  object.setConfigParameter("bitesRemaining", storage.bitesRemaining)
  updateVisual()
end
