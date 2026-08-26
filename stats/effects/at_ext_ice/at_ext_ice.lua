function init()
  script.setUpdateDelta(5)

  self.energyRegen = config.getParameter("energyRegen", 3)

  status.modifyResource("health", config.getParameter("instantHealth", 25))
end

function update(dt)
  status.modifyResource("energy", self.energyRegen * dt)
end
