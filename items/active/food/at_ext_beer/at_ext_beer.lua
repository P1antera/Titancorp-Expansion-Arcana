function init()
  self.idleArmAngle = config.getParameter("idleArmAngle", -0.5)
  self.idleDrinkAngle = config.getParameter("idleDrinkAngle", 0.0)
  self.raiseArmAngle = config.getParameter("raiseArmAngle", 0)
  self.raiseDrinkAngle = config.getParameter("raiseDrinkAngle", 0.0)
  self.drinkArmAngle = config.getParameter("drinkArmAngle", 0)
  self.drinkDrinkAngle = config.getParameter("drinkDrinkAngle", -0.7)
  self.raiseTime = config.getParameter("raiseTime", 1)
  self.drinkTime = config.getParameter("drinkTime", 3.0)
  self.recapTime = config.getParameter("recapTime", 1.0)
  self.itemName = config.getParameter("itemName", "at_ext_beer")
  self.firstEffectName = config.getParameter("firstEffectName", "at_ext_beer_1")
  self.firstEffectDuration = config.getParameter("firstEffectDuration", 60)
  self.secondEffectName = config.getParameter("secondEffectName", "at_ext_beer_2")
  self.secondEffectDuration = config.getParameter("secondEffectDuration", 120)
  self.thirdEffectName = config.getParameter("thirdEffectName", "at_ext_beer_3")
  self.thirdEffectDuration = config.getParameter("thirdEffectDuration", 180)
  self.emptyBottleItem = config.getParameter("emptyBottleItem")
  idle()
end

function activate(fireMode, shiftHeld)
  if self.state == "idle" and fireMode == "primary" then raise() end
end

function update(dt, fireMode, shiftHeld)
  self.stateTimer = math.max(0, self.stateTimer - dt)
  if self.state == "raise" then
    setPose(self.raiseArmAngle, self.raiseDrinkAngle, "raise")
    if self.stateTimer == 0 then drink() end
  elseif self.state == "drink" then
    setPose(self.drinkArmAngle, self.drinkDrinkAngle, "drink")
    if self.stateTimer == 0 then recap() end
  elseif self.state == "recap" then
    setPose(self.raiseArmAngle, self.raiseDrinkAngle, "recap")
    if self.stateTimer == 0 then finish() end
  end
end

function idle()
  self.state = "idle"
  self.stateTimer = 0
  activeItem.setTwoHandedGrip(false)
  activeItem.setBackArmFrame("swim.4")
  activeItem.setFrontArmFrame("swim.2")
  setPose(self.idleArmAngle, self.idleDrinkAngle, "idle")
end

function raise()
  self.state = "raise"
  self.stateTimer = self.raiseTime
  activeItem.setTwoHandedGrip(true)
  activeItem.setBackArmFrame("swim.1")
  activeItem.setFrontArmFrame("swim.4")
  animator.playSound("drink")
end

function drink()
  self.state = "drink"
  self.stateTimer = self.drinkTime
  activeItem.setTwoHandedGrip(false)
  activeItem.setBackArmFrame("swim.1")
  activeItem.setFrontArmFrame("swim.2")
end

function recap()
  self.state = "recap"
  self.stateTimer = self.recapTime
  activeItem.setTwoHandedGrip(true)
  activeItem.setBackArmFrame("swim.1")
  activeItem.setFrontArmFrame("swim.4")
end

function finish()
  if self.finished then return end
  self.finished = true
  local activeEffects = activeEffectNames()
  local effectName = self.firstEffectName
  local effectDuration = self.firstEffectDuration
  if activeEffects[self.thirdEffectName] or activeEffects[self.secondEffectName] then
    effectName = self.thirdEffectName
    effectDuration = self.thirdEffectDuration
  elseif activeEffects[self.firstEffectName] then
    effectName = self.secondEffectName
    effectDuration = self.secondEffectDuration
  end
  status.removeEphemeralEffect(self.firstEffectName)
  status.removeEphemeralEffect(self.secondEffectName)
  status.removeEphemeralEffect(self.thirdEffectName)
  status.addEphemeralEffect(effectName, effectDuration)
  local consumed = false
  if player and player.consumeItem then
    consumed = player.consumeItem({name = self.itemName, count = 1})
  end
  if not consumed then
    giveEmptyBottle()
    item.consume(1)
    return
  end
  giveEmptyBottle()
  self.finished = false
  idle()
end

function activeEffectNames()
  local effects = {}
  for _, effect in ipairs(status.activeUniqueStatusEffectSummary() or {}) do
    if effect[1] and effect[1] ~= "" then effects[effect[1]] = true end
  end
  return effects
end

function giveEmptyBottle()
  if self.emptyBottleItem and player and player.giveItem then
    player.giveItem({name = self.emptyBottleItem, count = 1})
  end
end

function setPose(armAngle, drinkAngle, frame)
  activeItem.setArmAngle(armAngle)
  animator.resetTransformationGroup("drink")
  animator.rotateTransformationGroup("drink", drinkAngle - armAngle)
  animator.setAnimationState("drinkState", frame)
end
