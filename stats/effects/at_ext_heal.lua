function init()
  animator.setParticleEmitterOffsetRegion("healing", mcontroller.boundBox())
  animator.setParticleEmitterEmissionRate("healing", config.getParameter("emissionRate", 3))
  animator.setParticleEmitterActive("healing", true)

  script.setUpdateDelta(5)

  self.healRate = config.getParameter("healRate", 0.1) * status.resourceMax("health")

  effect.addStatModifierGroup({
    { stat = "protection", amount = -15 },
    { stat = "physicalResistance", amount = -0.1 }
  })
end

function update(dt)
 
   healing()
 
end

function uninit()
  
end

function healing()

  if status.resource("health") >= status.resourceMax("health") * 0.1  then
    status.modifyResource("health", self.healRate * dt)
  end


end