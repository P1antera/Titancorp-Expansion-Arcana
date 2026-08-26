require "/scripts/activeitem/stances.lua"

function init()
  initStances()
  self.fired = false
  setStance("idle")
end

function update(dt, fireMode, shiftHeld)
  updateStance(dt)
  updateAim()

  if fireMode ~= "primary" then
    self.fired = false
  end

  if self.stanceName == "idle" and fireMode == "primary" and not self.fired then
    self.fired = true
    animator.playSound("use")
    setStance("use")
  end
end

function finishUse()
  setStance("idle")
end
