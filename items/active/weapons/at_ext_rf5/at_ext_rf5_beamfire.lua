require "/scripts/interp.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"

Rf5BeamFire = WeaponAbility:new()

function Rf5BeamFire:init()
  self.damageConfig.baseDamage = self.baseDps * self.fireTime
  self.weapon:setStance(self.stances.idle)

  self.weapon.onLeaveAbility = function()
    self:reset()
    self.weapon:setStance(self.stances.idle)
  end
end

function Rf5BeamFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and not world.lineTileCollision(mcontroller.position(), self:firePosition())
    and not status.resourceLocked("energy") then

    self:setState(self.fire)
  end
end

function Rf5BeamFire:fire()
  self.weapon:setStance(self.stances.fire)

  -- GunFire consumes energyUsage * fireTime for each automatic shot.
  if status.overConsumeResource("energy", (self.energyUsage or 0) * self.fireTime) then
    local beamStart = self:firePosition()
    local beamEnd = vec2.add(beamStart, vec2.mul(vec2.norm(self:aimVector(0)), self.beamLength))
    local beamLength = self.beamLength
    local collidePoint = world.lineCollision(beamStart, beamEnd)

    if collidePoint then
      beamEnd = collidePoint
      beamLength = world.magnitude(beamStart, beamEnd)

      self:spawnImpact(collidePoint)
    end

    self:spawnEntityImpacts(beamStart, beamEnd)
    self.weapon:setDamage(
      self.damageConfig,
      {self.weapon.muzzleOffset, {self.weapon.muzzleOffset[1] + beamLength, self.weapon.muzzleOffset[2]}},
      self.fireTime
    )
    self:drawBeam(beamStart, beamEnd, collidePoint)
    self:muzzleFlash()
    util.wait(self.beamFlashTime)
  end

  self:reset()
  self:setState(self.cooldown)
end

function Rf5BeamFire:spawnEntityImpacts(beamStart, beamEnd)
  local entities = world.entityLineQuery(beamStart, beamEnd, {
    includedTypes = {"monster", "npc"},
    withoutEntityId = activeItem.ownerEntityId()
  })
  local direction = vec2.norm(world.distance(beamEnd, beamStart))

  for _, entityId in ipairs(entities) do
    local entityPosition = world.entityPosition(entityId)
    if entityPosition then
      -- Place the impact on the beam line, closest to the entity's center.
      local offset = world.distance(entityPosition, beamStart)
      local distanceAlongBeam = offset[1] * direction[1] + offset[2] * direction[2]
      self:spawnImpact(vec2.add(beamStart, vec2.mul(direction, distanceAlongBeam)))
    end
  end
end

function Rf5BeamFire:spawnImpact(position)
  world.spawnProjectile(
    "at_ext_rf5_beamimpact",
    position,
    activeItem.ownerEntityId(),
    {0, 0},
    false
  )
end

function Rf5BeamFire:drawBeam(startPos, endPos, didCollide)
  local chain = copy(self.chain)
  chain.startPosition = vec2.add(startPos, {0, 0})
  chain.endPosition = endPos

  if didCollide then
    chain.endSegmentImage = nil
  end

  activeItem.setScriptedAnimationParameter("chains", {chain})
end

function Rf5BeamFire:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, self.muzzleFlashVariants or 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  animator.playSound("fire")
  animator.setLightActive("muzzleFlash", true)
end

function Rf5BeamFire:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()
  util.wait(self.stances.cooldown.duration, function()
  end)
end

function Rf5BeamFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function Rf5BeamFire:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function Rf5BeamFire:uninit()
  self:reset()
end

function Rf5BeamFire:reset()
  self.weapon:setDamage()
  activeItem.setScriptedAnimationParameter("chains", {})
end
