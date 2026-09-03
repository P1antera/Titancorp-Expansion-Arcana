function init()
  self.speedModifier = config.getParameter("speedModifier", 0.95)
  self.groundMovementModifier = config.getParameter("groundMovementModifier", 0.95)
  animator.setParticleEmitterEmissionRate("bubbles", config.getParameter("emissionRate", 1.5))
  animator.setParticleEmitterActive("bubbles", true)
end

function update(dt)
  mcontroller.controlModifiers({
    speedModifier = self.speedModifier,
    groundMovementModifier = self.groundMovementModifier
  })
end
