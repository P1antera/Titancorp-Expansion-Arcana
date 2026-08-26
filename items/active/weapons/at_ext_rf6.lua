require "/scripts/util.lua"
require "/scripts/interp.lua"

GunFire = WeaponAbility:new()

function GunFire:init()
  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self.fireTime
  self.sustainedFireTimer = 0
  self.minFireTime = self.minFireTime or self.fireTime
  self.minInaccuracy = self.minInaccuracy or self.inaccuracy
  self.spinUpTime = self.spinUpTime or 3.0
  self.overheatTime = self.overheatTime or 6.0
  self.overheatWarningTime = self.overheatWarningTime or 1.0
  self.overheatCooldownTime = self.overheatCooldownTime or 3.0
  self.overheatHealthCostPercent = self.overheatHealthCostPercent or 0.2
  self.overheated = false
  self.overheatWarning = false
  self.playedOverheatAlarm = false
  self.overheatProjectileType = self.overheatProjectileType or "at_ext_rf6_2"
  self.alwaysOnFlashlight = config.getParameter("alwaysOnFlashlight", true)
  if self.alwaysOnFlashlight then
    animator.setLightActive("flashlight", true)
  end

  self.weapon.onLeaveAbility = function()
    animator.setAnimationState("firing", "off")
    animator.setParticleEmitterActive("coolingSmoke", false)
    if self.alwaysOnFlashlight then
      animator.setLightActive("flashlight", true)
    end
    self.weapon:setStance(self.stances.idle)
  end
end

function GunFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if animator.animationState("muzzleFlash") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end
  if self.alwaysOnFlashlight then
    animator.setLightActive("flashlight", true)
  end

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then

    if self.fireType == "auto" then
      self:setState(self.auto)
    elseif self.fireType == "burst" then
      self:setState(self.burst)
    end
  elseif self.fireMode ~= (self.activatingFireMode or self.abilitySlot) and not self.weapon.currentAbility then
    self:resetSustainedFire()
  end
end

function GunFire:auto()
  local released = false

  while self.fireMode == (self.activatingFireMode or self.abilitySlot)
      and not world.lineTileCollision(mcontroller.position(), self:firePosition()) do

    local shotInterval = self:currentShotInterval()

    self.weapon:setStance(self.stances.fire)
    self:fireProjectile(self:currentProjectileType(), nil, self:currentInaccuracy())
    self:muzzleFlash()

    if self.stances.fire.duration then
      util.wait(self.stances.fire.duration)
    end

    self.sustainedFireTimer = self.sustainedFireTimer + shotInterval
    if self.sustainedFireTimer >= self.overheatTime then
      self:setState(self.overheat)
      return
    end

    self:updateOverheatWarning()
    self:shotCooldown(shotInterval)
  end

  released = self.fireMode ~= (self.activatingFireMode or self.abilitySlot)
  if released then
    animator.playSound("deactivate")
  end

  self:resetSustainedFire()
end

function GunFire:burst()
  self.weapon:setStance(self.stances.fire)

  local shots = self.burstCount
  while shots > 0 and status.overConsumeResource("energy", self:energyPerShot()) do
    self:fireProjectile()
    self:muzzleFlash()
    shots = shots - 1

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.armRotation))

    util.wait(self.burstTime)
  end

  self.cooldownTimer = (self.fireTime - self.burstTime) * self.burstCount
end

function GunFire:cooldown()
  self:shotCooldown(self.stances.cooldown.duration)
  self:resetSustainedFire()
end

function GunFire:shotCooldown(duration)
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()

  if duration <= 0 then
    self.weapon:setStance(self.stances.idle)
    return
  end

  local progress = 0
  util.wait(duration, function()
    local from = self.stances.cooldown.weaponOffset or {0,0}
    local to = self.stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.weaponRotation, self.stances.idle.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.armRotation, self.stances.idle.armRotation))

    progress = math.min(1.0, progress + (self.dt / duration))
  end)

  self.weapon:setStance(self.stances.idle)
end

function GunFire:overheat()
  self.overheated = true
  animator.setLightActive("muzzleFlash", false)
  animator.setAnimationState("firing", "cooling")
  animator.playSound("cooling")
  animator.setParticleEmitterActive("coolingSmoke", true)
  self:applyOverheatHealthCost()
  self.weapon:setStance(self.stances.overheat or self.stances.cooldown)
  self.weapon:updateAim()

  util.wait(self.overheatCooldownTime, function()
    self.weapon:setStance(self.stances.overheat or self.stances.cooldown)
  end)

  self.overheated = false
  self:resetSustainedFire()
  animator.setParticleEmitterActive("coolingSmoke", false)
  animator.setAnimationState("firing", "off")
  self.weapon:setStance(self.stances.idle)
end

function GunFire:currentShotInterval()
  local spinProgress = 1.0
  if self.spinUpTime > 0 then
    spinProgress = math.min(1.0, self.sustainedFireTimer / self.spinUpTime)
  end

  return interp.linear(spinProgress, self.fireTime, self.minFireTime)
end

function GunFire:applyOverheatHealthCost()
  local healthCost = status.resourceMax("health") * self.overheatHealthCostPercent
  status.modifyResource("health", -healthCost)
end

function GunFire:currentInaccuracy()
  local spinProgress = 1.0
  if self.spinUpTime > 0 then
    spinProgress = math.min(1.0, self.sustainedFireTimer / self.spinUpTime)
  end

  return interp.linear(spinProgress, self.inaccuracy, self.minInaccuracy)
end

function GunFire:currentProjectileType()
  if self.overheatWarning then
    return self.overheatProjectileType
  end

  return self.projectileType
end

function GunFire:resetSustainedFire()
  self.sustainedFireTimer = 0
  self.cooldownTimer = 0
  self.overheatWarning = false
  self.playedOverheatAlarm = false
  if not self.overheated and animator.animationState("firing") == "overheat" then
    animator.setAnimationState("firing", "off")
  end
end

function GunFire:updateOverheatWarning()
  local warningStart = math.max(0, self.overheatTime - self.overheatWarningTime)
  self.overheatWarning = self.sustainedFireTimer >= warningStart

  if self.overheatWarning then
    animator.setAnimationState("firing", "overheat")
    if not self.playedOverheatAlarm then
      animator.playSound("alarm")
      self.playedOverheatAlarm = true
    end
  end
end

function GunFire:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, self.muzzleFlashVariants or 3))
  animator.setAnimationState("muzzleFlash", "off")
  animator.setAnimationState("muzzleFlash", "fire")
  if not self.overheatWarning then
    animator.setAnimationState("firing", "off")
    animator.setAnimationState("firing", "fire")
  end
  animator.burstParticleEmitter("muzzleFlash")
  animator.playSound("fire")

  animator.setLightActive("muzzleFlash", true)
end

function GunFire:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  params.power = self:damagePerShot()
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)

  if not projectileType then
    projectileType = self.projectileType
  end
  if type(projectileType) == "table" then
    projectileType = projectileType[math.random(#projectileType)]
  end

  local projectileId = 0
  for i = 1, (projectileCount or self.projectileCount) do
    if params.timeToLive then
      params.timeToLive = util.randomInRange(params.timeToLive)
    end

    projectileId = world.spawnProjectile(
        projectileType,
        firePosition or self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(inaccuracy or self.inaccuracy),
        false,
        params
      )
  end
  return projectileId
end

function GunFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function GunFire:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function GunFire:energyPerShot()
  return 0
end

function GunFire:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.fireTime)) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
end

function GunFire:uninit()
end
