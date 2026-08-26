require "/scripts/vec2.lua"

function init()
  self.targetPosition = projectile.getParameter("targetPosition")
  self.explodeDistance = projectile.getParameter("explodeDistance", 1.0)
end

function update(dt)
  if not self.targetPosition then
    return
  end

  local currentPosition = mcontroller.position()
  local toTarget = world.distance(currentPosition, self.targetPosition)
  local distance = vec2.mag(toTarget)


  if distance <= self.explodeDistance then
    projectile.die()
    return
  end


  local velocity = mcontroller.velocity()
  local nextPosition = vec2.add(currentPosition, vec2.mul(velocity, dt))

  local currentToTarget = world.distance(currentPosition, self.targetPosition)
  local nextToTarget = world.distance(nextPosition, self.targetPosition)


  if vec2.dot(currentToTarget, nextToTarget) <= 0 then
    projectile.die()
  end
end