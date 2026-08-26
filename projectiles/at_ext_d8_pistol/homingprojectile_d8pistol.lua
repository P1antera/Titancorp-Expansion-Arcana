require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.homingDistance = config.getParameter("homingDistance", 20)
  self.rotationRate = config.getParameter("rotationRate")
  self.trackingLimit = config.getParameter("trackingLimit")
  self.sourceEntity = projectile.sourceEntity()
  self.queryParameters = {
    withoutEntityId = self.sourceEntity,
    includedTypes = {"creature"},
    order = "nearest"
  }

  self.amplitude = config.getParameter("amplitude", 1.0)  
  self.frequency = config.getParameter("frequency", 5.0)  
  self.oscillationTime = 0 
  local ttlVariance = config.getParameter("timeToLiveVariance")
  if ttlVariance then
    projectile.setTimeToLive(projectile.timeToLive() + sb.nrand(ttlVariance))
  end
end

function update(dt)
  self.oscillationTime = self.oscillationTime + dt  

  local pos = mcontroller.position()
  local candidates = world.entityQuery(pos, self.homingDistance, self.queryParameters)

  if #candidates == 0 then
    local vel = mcontroller.velocity()
    vel = addOscillation(vel, dt)
    mcontroller.setVelocity(vel)
    mcontroller.setRotation(math.atan(vel[2], vel[1]))
    return
  end

  local vel = mcontroller.velocity()
  local angle = vec2.angle(vel)

  for _, candidate in ipairs(candidates) do
    if world.entityCanDamage(self.sourceEntity, candidate) then
      local canPos = world.entityPosition(candidate)
      if not world.lineTileCollision(pos, canPos) then
        local toTarget = world.distance(canPos, pos)
        local toTargetAngle = util.angleDiff(angle, vec2.angle(toTarget))

        if math.abs(toTargetAngle) > self.trackingLimit then
          break  
        end


        local rotateAngle = math.max(dt * -self.rotationRate, math.min(toTargetAngle, dt * self.rotationRate))
        vel = vec2.rotate(vel, rotateAngle)
        break 
      end
    end
  end


  vel = addOscillation(vel, dt)
  mcontroller.setVelocity(vel)
  mcontroller.setRotation(math.atan(vel[2], vel[1]))
end


function addOscillation(velocity, dt)
  if vec2.mag(velocity) == 0 then return velocity end  
  

  local dir = vec2.norm(velocity)
  local perpendicular = {-dir[2], dir[1]}  
  
 
  local oscillation = math.sin(self.oscillationTime * 2 * math.pi * self.frequency)
  local offset = vec2.mul(perpendicular, oscillation * self.amplitude)
  
  return vec2.add(velocity, offset)
end