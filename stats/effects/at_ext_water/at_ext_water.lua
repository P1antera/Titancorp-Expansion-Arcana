function init()
  script.setUpdateDelta(5)
  self.healRate = config.getParameter("healRate", 1)
end

function update(dt)
  status.modifyResource("health", self.healRate * dt)
end
