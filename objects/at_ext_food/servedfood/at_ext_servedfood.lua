local function configuredBites(value)
  value = tonumber(value) or 1
  return math.max(1, math.floor(value))
end

function init()
  self.food = root.assetJson(config.getParameter("foodConfig"))
  self.bites = configuredBites(self.food.bites)
  self.frames = self.food.frames or {"full", "empty"}
  if #self.frames == 0 then self.frames = {"default"} end

  storage.bitesRemaining = storage.bitesRemaining
    and math.max(0, math.min(self.bites, storage.bitesRemaining))
    or self.bites

  object.setInteractive(true)
  updateVisual()
end

function updateVisual()
  local eaten = self.bites - storage.bitesRemaining
  local frameIndex = math.min(eaten + 1, #self.frames)
  animator.setAnimationState("foodState", self.frames[frameIndex])
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
  updateVisual()
end
