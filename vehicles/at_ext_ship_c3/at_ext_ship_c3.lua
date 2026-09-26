require "/scripts/util.lua"

function initShip()
  self.moveSpeed = config.getParameter("moveSpeed")
  self.airForce = config.getParameter("airForce")
  self.minHeight = config.getParameter("minHeight")
  self.maxHeight = config.getParameter("maxHeight")
  self.movementSettings = config.getParameter("movementSettings")
  self.occupiedMovementSettings = config.getParameter("occupiedMovementSettings")
  self.protection = config.getParameter("protection")
  self.maxHealth = config.getParameter("health")
  storage.health = storage.health or self.maxHealth

  self.height = 0
  self.driving = false
  self.lastDriver = nil
  self.facingDirection = 1
  self.started = false
  self.firing = false
  self.firePods = coroutine.create(firePods)
  self.missileBurst = nil
  self.missileCooldown = 0
  self.aimLimit = config.getParameter("aimlimit") * math.pi / 180
  self.aimAngle = 0

  animator.setAnimationState("thrust", "off")
  animator.setAnimationState("bottomthrust", "off")

  self.ownerKey = config.getParameter("ownerKey")
  vehicle.setPersistent(self.ownerKey)
  message.setHandler("store", function(_, _, ownerKey)
    if self.ownerKey and self.ownerKey == ownerKey and self.lastDriver == nil and animator.animationState("ship") == "landed" then
      setShipState("invisible")
      animator.playSound("returnvehicle")
      return {storable = true, healthFactor = storage.health / self.maxHealth}
    end
    return {storable = false, healthFactor = storage.health / self.maxHealth}
  end)
end

function setShipState(state)
  animator.setAnimationState("ship", state)
  animator.setAnimationState("background", state)
  animator.setAnimationState("shipFullbright", state)
end

function updateShip(dt, driver, moveDir)
  if animator.animationState("ship") == "invisible" then
    vehicle.destroy()
    return
  end

  if storage.health <= 0 then
    animator.burstParticleEmitter("damageShards")
    animator.playSound("explode")
    vehicle.destroy()
    return
  end

  local damaged = storage.health <= 1000
  animator.setParticleEmitterActive("damageShards2", damaged)
  animator.setParticleEmitterActive("damageShards", damaged)

  if mcontroller.atWorldLimit() then
    vehicle.destroy()
    return
  end

  if driver then
    if self.lastDriver == nil then
      animator.playSound("engineStart")
      animator.playSound("engineLoop", -1)
      setShipState("up")
      self.started = true
    end
    if driver == 0 then
      vehicle.setDamageTeam({type = "passive"})
    else
      vehicle.setDamageTeam(world.entityDamageTeam(driver))
    end
    mcontroller.applyParameters(self.occupiedMovementSettings)
    vehicle.setInteractive(false)
  else
    vehicle.setDamageTeam({type = "passive"})
    mcontroller.applyParameters(self.movementSettings)
    vehicle.setInteractive(true)
    if self.started then
      setShipState("landing")
      animator.setAnimationState("thrust", "off")
      animator.setAnimationState("bottomthrust", "off")
      animator.stopAllSounds("engineLoop", -1)
      animator.playSound("shutDown")
      self.started = false
    end
  end
  self.lastDriver = driver

  if self.started and mcontroller.xVelocity() == 0 then
    animator.setAnimationState("thrust", "idle")
  end
  if self.started and mcontroller.yVelocity() == 0 then
    animator.setAnimationState("bottomthrust", "idle")
  end

  local driving = vec2.mag(moveDir) > 0
  if driving and not self.driving then
    animator.playSound("afterBurn", -1)
  elseif not driving then
    animator.stopAllSounds("afterBurn", 0.5)
  end
  self.driving = driving

  if moveDir[1] ~= 0 then
    self.facingDirection = util.toDirection(moveDir[1])
    animator.setFlipped(moveDir[1] < 0)
  end

  animator.resetTransformationGroup("rotation")
  if driver then
    applyFlightMovement(moveDir)
    gunrotate()
  else
    mcontroller.rotate(-mcontroller.rotation() * dt)
  end

  self.missileCooldown = math.max(0, self.missileCooldown - dt)
  if self.missileBurst then
    local ok, result = coroutine.resume(self.missileBurst)
    if not ok then error(result) end
    if coroutine.status(self.missileBurst) == "dead" then
      self.missileBurst = nil
    end
  end

  local ok, result = coroutine.resume(self.firePods)
  if not ok then error(result) end
end

function applyFlightMovement(moveDir)
  local start = mcontroller.position()
  local bottom = vec2.add(start, {0, -self.maxHeight * 2})
  local ground
  for xOffset = -5, 5 do
    local findGround = world.collisionBlocksAlongLine(vec2.add(start, {xOffset, 0}), vec2.add(bottom, {xOffset, 0}))[1]
    if findGround and (not ground or findGround[2] > ground[2]) then ground = findGround end
  end
  local groundDist = self.maxHeight * 2
  if ground then groundDist = world.distance(start, vec2.add(ground, {0, 1}))[2] end
  if groundDist > self.maxHeight then
    moveDir[2] = math.min((self.maxHeight - groundDist) / self.maxHeight, moveDir[2])
  end
  if groundDist < self.minHeight then
    moveDir[2] = math.max((self.minHeight - groundDist) / self.minHeight, moveDir[2])
  end
  self.height = groundDist

  moveDir = vec2.norm(moveDir)
  mcontroller.approachVelocity(vec2.mul(moveDir, self.moveSpeed), self.airForce)
  local tilt = mcontroller.yVelocity() / self.moveSpeed * 0.5
  mcontroller.setRotation(tilt * util.toDirection(moveDir[1]))
  animator.rotateTransformationGroup("rotation", tilt)
end

function gunrotate()
  local tilt = mcontroller.yVelocity() / self.moveSpeed * 0.5
  local diff = world.distance(vehicle.aimPosition("seat"), mcontroller.position())
  local aimAngle = math.atan(diff[2], diff[1])
  if self.facingDirection < 0 then
    if aimAngle > 0 then
      aimAngle = math.max(aimAngle, math.pi - self.aimLimit + tilt)
    else
      aimAngle = math.min(aimAngle, -math.pi + self.aimLimit + tilt)
    end
    animator.rotateGroup("guns", math.pi - aimAngle + tilt)
  else
    if aimAngle - tilt > 0 then
      aimAngle = math.min(aimAngle, self.aimLimit + tilt)
    else
      aimAngle = math.max(aimAngle, -self.aimLimit + tilt)
    end
    animator.rotateGroup("guns", aimAngle - tilt)
  end
  self.aimAngle = aimAngle
end

function aimVector(inaccuracy)
  return vec2.rotate({1, 0}, self.aimAngle + sb.nrand(inaccuracy, 0))
end

function shipHeight()
  return self.height
end

function startFiring()
  self.firing = true
end

function stopFiring()
  self.firing = false
end

function firePods()
  while true do
    if self.firing then
      animator.setAnimationState("frontcannon", "fire")
      animator.setAnimationState("frontcannonFullbright", "fire")
      local fireOffset = animator.partPoint("frontcannon", "fireOffset")
      world.spawnProjectile("at_ext_ship4", vec2.add(mcontroller.position(), fireOffset), entity.id(), aimVector(0.02), false)
      animator.playSound("cannonFire")
      util.wait(0.12)
    else
      coroutine.yield()
    end
  end
end

function triggerMissileBurst()
  if self.missileBurst == nil and self.missileCooldown == 0 then
    self.missileCooldown = 3.0
    self.missileBurst = coroutine.create(fireMissileBurst)
  end
end

function fireMissileBurst()
  -- Keep launch points under the wings as the ship flips and tilts. Projectiles
  -- render in the foreground, at the same visual priority as the cannon.
  local launchOffsets = {{0.75, -1.5}, {0.75, -1.5}}
  local spread = {-0.12, -0.072, -0.024, 0.024, 0.072, 0.12}
  for i = 1, 6 do
    local launcherIndex = ((i - 1) % 2) + 1
    local localOffset = launchOffsets[launcherIndex]
    local fireOffset = vec2.rotate({localOffset[1] * self.facingDirection, localOffset[2]}, mcontroller.rotation())
    world.spawnProjectile("at_ext_ship_c3missile", vec2.add(mcontroller.position(), fireOffset), entity.id(), vec2.rotate(aimVector(0.02), spread[i]), false)
    if launcherIndex == 1 then
      animator.burstParticleEmitter("leftMissileMuzzleSmoke")
    else
      animator.burstParticleEmitter("rightMissileMuzzleSmoke")
    end
    animator.playSound("missileFire")
    util.wait(0.08)
  end
end

function applyDamage(damageRequest)
  local damage = 0
  if damageRequest.damageType == "Damage" then
    damage = root.evalFunction2("protection", damageRequest.damage, self.protection)
  elseif damageRequest.damageType == "IgnoresDef" then
    damage = damageRequest.damage
  else
    return {}
  end
  local healthLost = math.min(damage, storage.health)
  storage.health = storage.health - healthLost
  return {{
    sourceEntityId = damageRequest.sourceEntityId,
    targetEntityId = entity.id(),
    position = mcontroller.position(),
    damageDealt = damage,
    healthLost = healthLost,
    hitType = "Hit",
    damageSourceKind = damageRequest.damageSourceKind,
    targetMaterialKind = "robotic",
    killed = storage.health <= 0
  }}
end
