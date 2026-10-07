require "/scripts/util.lua"

function initMediumShip()
  self.moveSpeed = config.getParameter("moveSpeed")
  self.airForce = config.getParameter("airForce")
  self.minHeight = config.getParameter("minHeight")
  self.maxHeight = config.getParameter("maxHeight")
  self.movementSettings = config.getParameter("movementSettings")
  self.occupiedMovementSettings = config.getParameter("occupiedMovementSettings")
  self.vectorThrusterRotationSpeed = math.rad(config.getParameter("vectorThrusterRotationSpeed", 360))
  self.vectorThrusterMinAngle = math.rad(config.getParameter("vectorThrusterMinAngle", -180))
  self.vectorThrusterMaxAngle = math.rad(config.getParameter("vectorThrusterMaxAngle", 180))
  self.vectorThrusterHoverAngle = math.rad(config.getParameter("vectorThrusterHoverAngle", 0))
  self.vectorThrusterAccelerationThreshold = config.getParameter("vectorThrusterAccelerationThreshold", 0.25)
  self.vectorThrusterVelocityThreshold = config.getParameter("vectorThrusterVelocityThreshold", 0.25)
  self.vectorThrusterHasFullRotation = self.vectorThrusterMaxAngle - self.vectorThrusterMinAngle >= math.pi * 2 - 0.001
  self.vectorThrusterAngle = self.vectorThrusterHoverAngle
  self.lastVectorThrusterVelocity = mcontroller.velocity()
  self.vectorThrusterEngines = {
    {part = "engineLeft", group = "engineLeftRotation"},
    {part = "engineMidLeft", group = "engineMidLeftRotation"},
    {part = "engineMidRight", group = "engineMidRightRotation"},
    {part = "engineRight", group = "engineRightRotation"}
  }

  self.protection = config.getParameter("protection")
  storage.health = storage.health or config.getParameter("health")
  self.maxHealth = config.getParameter("health")
  self.ownerKey = config.getParameter("ownerKey")
  self.lastDriver = nil
  self.started = false
  self.afterBurning = false
  self.facingDirection = 1
  self.height = 0

  self.cannonFiring = false
  self.cannonTimer = 0
  self.nextCannon = "front"
  self.frontCannonAimAngle = 0
  self.backCannonAimAngle = 0
  self.frontCannonPivot = {7.5, -3.363}
  self.backCannonPivot = {8.9875, -3.425}
  self.missileMode = "loaded"
  self.missileShots = 0
  self.missileTimer = 0
  self.missileLaunchOffsets = {{4.1, -0.25}, {4.1, -1.25}, {4.1, -2.25}}
  self.missileSmokeEmitters = {"missileMuzzleSmokeTop", "missileMuzzleSmokeMiddle", "missileMuzzleSmokeBottom"}
  self.bombAmmo = 2
  self.bombCooldown = 0

  vehicle.setPersistent(self.ownerKey)
  animator.setAnimationState("body", "landed")
  animator.setAnimationState("engine", "off")
  animator.setAnimationState("thruster", "off")
  animator.setAnimationState("frontcannon", "idle")
  animator.setAnimationState("backcannon", "idle")
  animator.setAnimationState("missilelauncher", "loaded")
  animator.setAnimationState("bombbay", "loaded")

  message.setHandler("store", function(_, _, ownerKey)
    if self.ownerKey and self.ownerKey == ownerKey and self.lastDriver == nil then
      animator.setAnimationState("body", "invisible")
      return {storable = true, healthFactor = storage.health / self.maxHealth}
    end
    return {storable = false, healthFactor = storage.health / self.maxHealth}
  end)
end

function updateMediumShip(dt, driver, moveDir)
  if animator.animationState("body") == "invisible" then
    vehicle.destroy()
    return
  end
  if storage.health <= 0 then
    animator.playSound("explode")
    vehicle.destroy()
    return
  end

  local hasMovementInput = vec2.mag(moveDir) > 0
  local onlyDownwardInput = driver ~= nil and moveDir[1] == 0 and moveDir[2] < 0
  local thrusting = driver ~= nil and hasMovementInput and not onlyDownwardInput
  local hullTilt = 0
  animator.resetTransformationGroup("rotation")

  if driver then
    if self.lastDriver == nil then
      animator.playSound("engineStart")
      animator.playSound("engineLoop", -1)
      animator.setAnimationState("body", "up")
      animator.setLightActive("headlight", true)
      animator.setLightActive("frontCannonSpotlight", true)
      self.started = true
    end
    animator.setAnimationState("engine", "on")
    mcontroller.applyParameters(self.occupiedMovementSettings)
    vehicle.setDamageTeam(driver == 0 and {type = "passive"} or world.entityDamageTeam(driver))
    vehicle.setInteractive(false)

    if moveDir[1] ~= 0 then
      self.facingDirection = util.toDirection(moveDir[1])
      animator.setFlipped(moveDir[1] < 0)
    end

    local start = mcontroller.position()
    local bottom = vec2.add(start, {0, -self.maxHeight * 2.0})
    local groundDist = self.maxHeight * 2.0
    for xOffset = -10, 10 do
      local ground = world.collisionBlocksAlongLine(vec2.add(start, {xOffset, 0}), vec2.add(bottom, {xOffset, 0}))[1]
      if ground then
        groundDist = math.min(groundDist, world.distance(start, vec2.add(ground, {0, 1}))[2])
      end
    end
    if groundDist > self.maxHeight then
      moveDir[2] = math.min((self.maxHeight - groundDist) / self.maxHeight, moveDir[2])
    elseif groundDist < self.minHeight then
      moveDir[2] = math.max((self.minHeight - groundDist) / self.minHeight, moveDir[2])
    end
    self.height = groundDist

    moveDir = vec2.norm(moveDir)
    mcontroller.approachVelocity(vec2.mul(moveDir, self.moveSpeed), self.airForce)
    local tilt = mcontroller.yVelocity() / self.moveSpeed * 0.35
    mcontroller.setRotation(tilt * util.toDirection(moveDir[1]))
    animator.rotateTransformationGroup("rotation", tilt)
    hullTilt = tilt
  else
    vehicle.setDamageTeam({type = "passive"})
    mcontroller.applyParameters(self.movementSettings)
    mcontroller.rotate(-mcontroller.rotation() * dt)
    vehicle.setInteractive(true)
    animator.setAnimationState("engine", "off")
    animator.setAnimationState("thruster", "off")
    if self.started then
      animator.setAnimationState("body", "landing")
      animator.setLightActive("headlight", false)
      animator.setLightActive("frontCannonSpotlight", false)
      animator.stopAllSounds("engineLoop", -1)
      animator.playSound("shutDown")
      self.started = false
    end
  end

  if thrusting and not self.afterBurning then
    animator.playSound("afterBurn", -1)
  elseif not thrusting and self.afterBurning then
    animator.stopAllSounds("afterBurn", 0.5)
  end
  self.afterBurning = thrusting

  local accelerationMagnitude = updateMediumVectorThrusters(dt, driver ~= nil, hullTilt, onlyDownwardInput, hasMovementInput)
  if driver then
    if not hasMovementInput or onlyDownwardInput then
      animator.setAnimationState("thruster", "idle")
    elseif thrusting and (accelerationMagnitude >= self.vectorThrusterAccelerationThreshold or vec2.mag(moveDir) > 0) then
      animator.setAnimationState("thruster", "thrust")
    else
      animator.setAnimationState("thruster", "idle")
    end
  end

  updateWeaponSystems(dt, driver, hullTilt)
  self.lastDriver = driver
end

function updateMediumVectorThrusters(dt, occupied, hullTilt, onlyDownwardInput, hasMovementInput)
  local velocity = mcontroller.velocity()
  local acceleration = {0, 0}
  if dt > 0 then acceleration = vec2.div(vec2.sub(velocity, self.lastVectorThrusterVelocity), dt) end
  self.lastVectorThrusterVelocity = velocity
  local accelerationMagnitude = vec2.mag(acceleration)
  local targetVector
  if occupied and hasMovementInput and not onlyDownwardInput then
    if accelerationMagnitude >= self.vectorThrusterAccelerationThreshold then
      targetVector = acceleration
    elseif vec2.mag(velocity) >= self.vectorThrusterVelocityThreshold then
      targetVector = velocity
    end
  end

  local targetAngle = self.vectorThrusterHoverAngle
  if targetVector then
    targetAngle = math.atan(targetVector[2], targetVector[1] * self.facingDirection) - math.pi / 2 - hullTilt
  end
  targetAngle = util.clamp(targetAngle, self.vectorThrusterMinAngle, self.vectorThrusterMaxAngle)
  local angleDelta = util.angleDiff(self.vectorThrusterAngle, targetAngle)
  local maxStep = self.vectorThrusterRotationSpeed * dt
  if math.abs(angleDelta) <= maxStep then
    self.vectorThrusterAngle = targetAngle
  else
    self.vectorThrusterAngle = self.vectorThrusterAngle + (angleDelta > 0 and maxStep or -maxStep)
  end
  if self.vectorThrusterHasFullRotation then
    self.vectorThrusterAngle = util.wrapAngle(self.vectorThrusterAngle)
  else
    self.vectorThrusterAngle = util.clamp(self.vectorThrusterAngle, self.vectorThrusterMinAngle, self.vectorThrusterMaxAngle)
  end
  for _, engine in ipairs(self.vectorThrusterEngines) do
    animator.resetTransformationGroup(engine.group)
    animator.rotateTransformationGroup(engine.group, self.vectorThrusterAngle, animator.partProperty(engine.part, "offset"))
  end
  return accelerationMagnitude
end

function startCannonFire()
  self.cannonFiring = true
end

function stopCannonFire()
  self.cannonFiring = false
end

function triggerMissileBurst()
  if self.missileMode == "loaded" then
    self.missileMode = "burst"
    self.missileShots = 0
    self.missileTimer = 0
  end
end

function dropBomb()
  if self.bombAmmo <= 0 then return end
  world.spawnProjectile("at_ext_ship_medium_armedbomb", vec2.add(mcontroller.position(), transformedLocalOffset({-4.1, -0.5})), entity.id(), shipForwardVector(), false)
  animator.playSound("fire")
  self.bombAmmo = self.bombAmmo - 1
  if self.bombAmmo == 1 then
    animator.setAnimationState("bombbay", "one")
  else
    animator.setAnimationState("bombbay", "empty")
    self.bombCooldown = 6
  end
end

function updateWeaponSystems(dt, driver, hullTilt)
  updateCannonAim(driver, hullTilt)
  if not driver then
    self.cannonFiring = false
    self.cannonTimer = 0
    self.missileMode = "loaded"
    self.missileShots = 0
    self.missileTimer = 0
    self.bombAmmo = 2
    self.bombCooldown = 0
    animator.setAnimationState("frontcannon", "idle")
    animator.setAnimationState("backcannon", "idle")
    animator.setAnimationState("missilelauncher", "loaded")
    animator.setAnimationState("bombbay", "loaded")
    return
  end

  if self.cannonFiring then
    self.cannonTimer = self.cannonTimer - dt
    while self.cannonTimer <= 0 do
      fireNextCannon()
      self.cannonTimer = self.cannonTimer + 0.12
    end
  else
    self.cannonTimer = 0
  end

  if self.missileMode == "burst" then
    self.missileTimer = self.missileTimer - dt
    while self.missileMode == "burst" and self.missileTimer <= 0 do
      self.missileShots = self.missileShots + 1
      fireMissile()
      if self.missileShots == 1 then
        animator.setAnimationState("missilelauncher", "two")
      elseif self.missileShots == 2 then
        animator.setAnimationState("missilelauncher", "one")
      else
        animator.setAnimationState("missilelauncher", "empty")
        self.missileMode = "cooldown"
        self.missileTimer = 5
        break
      end
      self.missileTimer = self.missileTimer + 0.12
    end
  elseif self.missileMode == "cooldown" then
    self.missileTimer = self.missileTimer - dt
    if self.missileTimer <= 0 then
      self.missileMode = "reload"
      animator.setAnimationState("missilelauncher", "reload")
      self.missileTimer = 0.1
    end
  elseif self.missileMode == "reload" then
    self.missileTimer = self.missileTimer - dt
    if self.missileTimer <= 0 then
      self.missileMode = "loaded"
      animator.setAnimationState("missilelauncher", "loaded")
      animator.playSound("reloadComplete")
    end
  end

  if self.bombAmmo == 0 then
    self.bombCooldown = self.bombCooldown - dt
    if self.bombCooldown <= 0 then
      self.bombAmmo = 2
      animator.setAnimationState("bombbay", "loaded")
      animator.playSound("reloadComplete")
    end
  end
end

function updateCannonAim(driver, hullTilt)
  if not driver then return end
  local aimPosition = vehicle.aimPosition("seat")
  local frontPivotPosition = vec2.add(mcontroller.position(), transformedLocalOffset(self.frontCannonPivot))
  local backPivotPosition = vec2.add(mcontroller.position(), transformedLocalOffset(self.backCannonPivot))
  local frontDiff = world.distance(aimPosition, frontPivotPosition)
  local backDiff = world.distance(aimPosition, backPivotPosition)

  self.frontCannonAimAngle = math.atan(frontDiff[2], frontDiff[1])
  self.backCannonAimAngle = math.atan(backDiff[2], backDiff[1])

  local function localCannonAngle(aimAngle)
    if self.facingDirection < 0 then
      return math.pi - aimAngle + hullTilt
    end
    return aimAngle - hullTilt
  end

  local frontCannonLocalAngle = localCannonAngle(self.frontCannonAimAngle)
  animator.rotateGroup("frontCannon", frontCannonLocalAngle)
  animator.rotateGroup("backCannon", localCannonAngle(self.backCannonAimAngle))
  animator.resetTransformationGroup("frontCannonLightAim")
  animator.rotateTransformationGroup("frontCannonLightAim", frontCannonLocalAngle, self.frontCannonPivot)
end

function fireNextCannon()
  local front = self.nextCannon == "front"
  animator.setAnimationState(front and "frontcannon" or "backcannon", "fire")
  local pivot = front and self.frontCannonPivot or self.backCannonPivot
  local aimPosition = vehicle.aimPosition("seat")
  local pivotPosition = vec2.add(mcontroller.position(), transformedLocalOffset(pivot))
  local aimDirection = directionTo(aimPosition, pivotPosition, front and self.frontCannonAimAngle or self.backCannonAimAngle)
  local muzzlePosition = vec2.add(pivotPosition, vec2.mul(aimDirection, 2.75))
  local firingDirection = directionTo(aimPosition, muzzlePosition, front and self.frontCannonAimAngle or self.backCannonAimAngle)
  local projectileType = front and "at_ext_ship_medium_armedcannon" or "at_ext_ship_medium_armedbackcannon"
  world.spawnProjectile(projectileType, muzzlePosition, entity.id(), vec2.rotate(firingDirection, sb.nrand(0.02, 0)), false)
  animator.playSound("cannonFire")
  self.nextCannon = front and "back" or "front"
end

function fireMissile()
  local launcherIndex = self.missileShots
  local launchOffset = self.missileLaunchOffsets[launcherIndex]
  world.spawnProjectile("at_ext_ship_medium_armedmissile", vec2.add(mcontroller.position(), transformedLocalOffset(launchOffset)), entity.id(), shipForwardVector(), false)
  animator.burstParticleEmitter(self.missileSmokeEmitters[launcherIndex])
  animator.playSound("missileFire")
end

function shipForwardVector()
  return vec2.rotate({self.facingDirection, 0}, mcontroller.rotation())
end

function transformedLocalOffset(offset)
  return vec2.rotate({offset[1] * self.facingDirection, offset[2]}, mcontroller.rotation())
end

function directionTo(targetPosition, originPosition, fallbackAngle)
  local difference = world.distance(targetPosition, originPosition)
  if vec2.mag(difference) <= 0.001 then
    return vec2.rotate({1, 0}, fallbackAngle)
  end
  return vec2.norm(difference)
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
