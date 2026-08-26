function init()
  self.targetzone = tonumber(config.getParameter("targetzone")) or config.getParameter("targetzone")
  self.refreshInterval = config.getParameter("refreshInterval", 5)
  self.samplePosition = config.getParameter("samplePosition")
  self.wasPowered = false
  self.refreshTimer = 0

  if self.samplePosition == nil then
    local objectDungeonId = world.dungeonId(object.position())
    if objectDungeonId == self.targetzone then
      self.samplePosition = object.position()
    end
  end
end

function update(dt)
  local isPowered = object.getInputNodeLevel(0)

  if isPowered then
    if protectionMissing() then
      activate()
      self.refreshTimer = self.refreshInterval
    elseif self.samplePosition == nil then
      self.refreshTimer = self.refreshTimer - dt
      if self.refreshTimer <= 0 then
        activate()
        self.refreshTimer = self.refreshInterval
      end
    end
  else
    self.refreshTimer = 0
  end

  self.wasPowered = isPowered
end

function protectionMissing()
  if self.samplePosition ~= nil then
    return not world.isTileProtected(self.samplePosition)
  end

  return not self.wasPowered
end

function activate()
  world.setTileProtection(self.targetzone, true)
end
