function init()
  script.setUpdateDelta(1)
  self.speedModifier = config.getParameter("speedModifier", 1.05)
  self.groundMovementModifier = config.getParameter("groundMovementModifier", 1.05)
end

function update(dt)
  mcontroller.controlModifiers({
    speedModifier = self.speedModifier,
    groundMovementModifier = self.groundMovementModifier
  })
end
