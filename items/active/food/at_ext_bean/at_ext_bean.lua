require "/scripts/util.lua"

function init()
  self.idleArmAngle = config.getParameter("idleArmAngle", -0.5)
  self.idleJuiceAngle = config.getParameter("idleJuiceAngle", 0.0)
  self.drinkArmAngle = config.getParameter("drinkArmAngle", -1.35)
  self.drinkJuiceAngle = config.getParameter("drinkJuiceAngle", -0.7)
  self.raiseTime = config.getParameter("raiseTime", 0.25)
  self.drinkTime = config.getParameter("drinkTime", 3.0)
  self.emptyTime = config.getParameter("emptyTime", 1.0)
  self.itemName = config.getParameter("itemName", "at_ext_bean")
  self.effectName = config.getParameter("effectName", "at_ext_mungbeanjuice")
  self.effectDuration = config.getParameter("effectDuration", 1200)

  idle()
end

function activate(fireMode, shiftHeld)
  if self.state == "idle" and fireMode == "primary" then
    raise()
  end
end

function update(dt, fireMode, shiftHeld)
  self.stateTimer = math.max(0, self.stateTimer - dt)

  if self.state == "raise" then
    setPose(self.drinkArmAngle, self.drinkJuiceAngle, "drink")

    if self.stateTimer == 0 then
      drink()
    end
  elseif self.state == "drink" then
    setPose(self.drinkArmAngle, self.drinkJuiceAngle, "drink")

    if self.stateTimer == 0 then
      empty()
    end
  elseif self.state == "empty" then
    setPose(self.drinkArmAngle, self.drinkJuiceAngle, "empty")

    if self.stateTimer == 0 then
      finish()
    end
  end
end

function idle()
  self.state = "idle"
  self.stateTimer = 0
  activeItem.setTwoHandedGrip(false)
  activeItem.setBackArmFrame("swim.4")
  activeItem.setFrontArmFrame("swim.2")
  setPose(self.idleArmAngle, self.idleJuiceAngle, "idle")
end

function raise()
  self.state = "raise"
  self.stateTimer = self.raiseTime
  activeItem.setTwoHandedGrip(true)
  activeItem.setBackArmFrame("swim.1")
  activeItem.setFrontArmFrame("swim.2")
  animator.playSound("drink")  
end

function drink()
  self.state = "drink"
  self.stateTimer = self.drinkTime
  activeItem.setTwoHandedGrip(false)
  activeItem.setBackArmFrame("swim.1")
  activeItem.setFrontArmFrame("swim.2")

end

function empty()
  self.state = "empty"
  self.stateTimer = self.emptyTime
  activeItem.setBackArmFrame("swim.1")
  activeItem.setFrontArmFrame("swim.2")
end

function finish()
  if self.finished then
    return
  end

  self.finished = true

  status.addEphemeralEffect(self.effectName, self.effectDuration)

  local consumed = false
  if player and player.consumeItem then
    consumed = player.consumeItem({name = self.itemName, count = 1})
  end

  if not consumed then
    item.consume(1)
    return
  end

  self.finished = false
  idle()
end

function setPose(armAngle, juiceAngle, frame)
  activeItem.setArmAngle(armAngle)
  animator.resetTransformationGroup("juice")
  animator.rotateTransformationGroup("juice", juiceAngle - armAngle)
  animator.setAnimationState("juiceState", frame)
end
