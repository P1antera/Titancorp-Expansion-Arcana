require "/scripts/vec2.lua"
require "/scripts/util.lua"

GunFire = WeaponAbility:new()

--  By     Mine With Him 

function GunFire:init()
  self.baseDamageFactor = config.getParameter("baseDamageFactor", 1.0)


  self.elementalType = self.elementalType or self.weapon.elementalType

  self.preCooldownTimer = self.chargeTime
  self.cooldownTimer = self.fireTime


  self.weapon:setStance(self.stances.idle)

  self.weapon.onLeaveAbility = function()
    self:reset()
  end
end

function GunFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)

  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and not status.resourceLocked("energy") then

    self:setState(self.charge)
  end
end


function GunFire:charge()
  self.weapon:updateAim()
  self.weapon:setStance(self.stances.charge)
  animator.setAnimationState("firing", "charge")


  while self.fireMode == (self.activatingFireMode or self.abilitySlot) do

    if self.preCooldownTimer > 0 then
      self.preCooldownTimer = self.preCooldownTimer - self.dt

    elseif self.cooldownTimer == 0 then
      if (not world.lineTileCollision(mcontroller.position(), self:firePosition())) and status.overConsumeResource("energy", self:energyPerShot()) then
        self:fireProjectile()
        self:muzzleFlash()
           if self.stances.fire.duration then
              util.wait(self.stances.fire.duration)
            end 
        self.cooldownTimer = self.fireTime
      end
    end

    coroutine.yield()
  end



  self.preCooldownTimer = self.preCooldown
  util.wait(self.afterCooldown)
end

function GunFire:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, self.muzzleFlashVariants or 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  animator.playSound("fire")

  animator.setLightActive("muzzleFlash", true)
end

function GunFire:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition)
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

  if params.timeToLive then
    params.timeToLive = util.randomInRange(params.timeToLive)
  end

  animator.playSound(self.elementalType.."activate")
  projectileId = world.spawnProjectile(
      projectileType,
      firePosition or self:firePosition(),
      activeItem.ownerEntityId(),
      self:aimVector(inaccuracy or self.inaccuracy),
      false,
      params
    )

  return projectileId
end

function GunFire:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.fireTime)) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier")
end

function GunFire:energyPerShot()
  return self.energyUsage * self.fireTime * (self.energyUsageMultiplier or 1.0)
end

function GunFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(animator.partPoint("stone", "focalPoint")))
end

function GunFire:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function GunFire:reset()
  self.weapon:setStance(self.stances.idle)
  animator.setAnimationState("charge", "idle")

end

function GunFire:uninit(weaponUninit)

end
