require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.homingDistance = config.getParameter("homingDistance", 20)
  self.rotationRate = config.getParameter("rotationRate")
  self.trackingLimit = config.getParameter("trackingLimit")
  self.homingDelay = config.getParameter("homingDelay", 0)
  self.sourceEntity = projectile.sourceEntity()
  self.queryParameters = {
    withoutEntityId = self.sourceEntity,
    includedTypes = {"creature"},
    order = "nearest"
  }

  local ttlVariance = config.getParameter("timeToLiveVariance")
  if ttlVariance then
    projectile.setTimeToLive(projectile.timeToLive() + sb.nrand(ttlVariance))
  end
end

function update(dt)
  if self.homingDelay > 0 then
    self.homingDelay = self.homingDelay - dt
    return
  end

  local pos = mcontroller.position()
  local candidates = world.entityQuery(pos, self.homingDistance, self.queryParameters)
  if #candidates == 0 then return end

  local velocity = mcontroller.velocity()
  local angle = vec2.angle(velocity)
  for _, candidate in ipairs(candidates) do
    if world.entityCanDamage(self.sourceEntity, candidate) then
      local targetPosition = world.entityPosition(candidate)
      if not world.lineTileCollision(pos, targetPosition) then
        local targetAngle = util.angleDiff(angle, vec2.angle(world.distance(targetPosition, pos)))
        if math.abs(targetAngle) > self.trackingLimit then return end
        velocity = vec2.rotate(velocity, math.max(dt * -self.rotationRate, math.min(targetAngle, dt * self.rotationRate)))
        mcontroller.setVelocity(velocity)
        break
      end
    end
  end
  mcontroller.setRotation(math.atan(velocity[2], velocity[1]))
end
