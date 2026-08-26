function init()
  script.setUpdateDelta(5)
  self.healRate = config.getParameter("healRate", 2)
end

function update(dt)
  status.modifyResource("health", self.healRate * dt)
end
