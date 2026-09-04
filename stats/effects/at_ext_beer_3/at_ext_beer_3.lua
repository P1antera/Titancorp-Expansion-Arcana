function init()
  self.speedModifier = config.getParameter("speedModifier", 0.9)
  self.groundMovementModifier = config.getParameter("groundMovementModifier", 0.9)
  self.parentDirectives = config.getParameter("parentDirectives", "fade=FFF0C0=0.08")
  animator.setParticleEmitterEmissionRate("bubbles", config.getParameter("emissionRate", 4.5))
  animator.setParticleEmitterActive("bubbles", true)
  effect.setParentDirectives(self.parentDirectives)
end

function update(dt)
  mcontroller.controlModifiers({
    speedModifier = self.speedModifier,
    groundMovementModifier = self.groundMovementModifier
  })
end

function uninit()
  effect.setParentDirectives("")
end
