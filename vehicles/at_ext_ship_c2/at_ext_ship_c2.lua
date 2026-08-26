require "/scripts/util.lua"

function initShip()
  self.moveSpeed = config.getParameter("moveSpeed")
  self.airForce = config.getParameter("airForce")
 
  self.minHeight = config.getParameter("minHeight")
  self.maxHeight = config.getParameter("maxHeight")
  self.height = 0
  animator.setAnimationState("thrust", "off") 
  animator.setAnimationState("bottomthrust", "off")
  self.movementSettings = config.getParameter("movementSettings")
  self.occupiedMovementSettings = config.getParameter("occupiedMovementSettings")

  self.protection = config.getParameter("protection")
  storage.health = storage.health or config.getParameter("health")
  self.maxHealth = config.getParameter("health")
  
  self.driving = false
  self.lastDriver = nil
  
  self.facingDirection = 1


  self.firing = false
  self.firePods = coroutine.create(firePods)
 self.started = false
 self.bombdir = 0.1
  storage.ammo = storage.ammo or 60
  self.shieldDuration = 600
--store ability

  self.ownerKey = config.getParameter("ownerKey")
  vehicle.setPersistent(self.ownerKey) 
  message.setHandler("store",
      function(_, _, ownerKey)
        if (self.ownerKey and self.ownerKey == ownerKey and self.driver == nil and animator.animationState("ship") == "landed") then
          --animator.setAnimationState("movement", "warpOutPart1")
          --switchHeadLights(1, 1, false)
         animator.setAnimationState("ship", "invisible")
          animator.playSound("returnvehicle")
          return {storable = true, healthFactor = storage.health / self.maxHealth}
        else
          return {storable = false, healthFactor = storage.health / self.maxHealth}
        end
      end)
end

function updateShip(dt, driver, moveDir)
    if (animator.animationState("ship") == "invisible") then
      vehicle.destroy()
    end
  -- 护盾开启/关闭 
  if animator.animationState("shield") == "opened" then
    if self.shieldDuration ~= 0 then
      self.shieldDuration = self.shieldDuration - 1
    else
      toggleShield()
      self.shieldDuration = 600
    end

  end  
  
  if storage.health <= 0 then
    animator.burstParticleEmitter("damageShards")
    animator.playSound("explode")
    vehicle.destroy()
  end

  if storage.health <= 1000 then
     animator.setParticleEmitterActive("damageShards2", true)
     animator.setParticleEmitterActive("damageShards", true)

  else
     animator.setParticleEmitterActive("damageShards2", false)
     animator.setParticleEmitterActive("damageShards", false)
  end

  if mcontroller.atWorldLimit() then
    vehicle.destroy()
    return
  end
-- 载具，启动！/关闭
  if driver then
    if self.lastDriver == nil then
      animator.playSound("engineStart")
      animator.setAnimationState("ship", "up")  --载具启动
       self.started = true
      --animator.setAnimationState("thrust", "idle")
      animator.playSound("engineLoop", -1)

 
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

      if   self.started == true  then
        animator.setAnimationState("ship", "landing")
        animator.setAnimationState("thrust", "off")
        animator.setAnimationState("bottomthrust", "off")
        animator.stopAllSounds("engineLoop", -1) 
        animator.playSound("shutDown", 0)
        self.started = false
      end
  end
  self.lastDriver = driver
-- 启动后推进器待机
if self.started == true and mcontroller.xVelocity() == 0 then

  animator.setAnimationState("thrust", "idle")
end
if self.started == true and mcontroller.yVelocity() == 0 then
  animator.setAnimationState("bottomthrust", "idle")
end

 


--移动时播放加速声
  local driving = vec2.mag(moveDir) > 0.0
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
  --animator.resetTransformationGroup("frontcannon")
--飞行限制
  if driver then
    local start = mcontroller.position()
    local bottom = vec2.add(start, {0, -self.maxHeight * 2.0})
    local ground
    for xOffset = -5, 5 do
      local findGround = world.collisionBlocksAlongLine(vec2.add(start, {xOffset, 0}), vec2.add(bottom, {xOffset, 0}))[1]
      if findGround and (not ground or findGround[2] > ground[2]) then
        ground = findGround
      end
    end

    local groundDist = self.maxHeight * 2.0
    if ground then
      groundDist = world.distance(start, vec2.add(ground, {0, 1}))[2]
    end
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

    --local frontPivot = vec2.mul(animator.partPoint("frontcannon", "rotationCenter"), {self.facingDirection, 1.0})
    --animator.rotateTransformationGroup("frontcannon", -tilt, frontPivot)

  else
    mcontroller.rotate(-mcontroller.rotation() * dt)
  end

  -- Run pod firing coroutine
  local s, result = coroutine.resume(self.firePods)
  if not s then
    error(result)
  end
end

function shipHeight()
  return self.height
end

function toggleShield() --护盾
  if animator.animationState("shield") == "closed" then
    animator.setAnimationState("shield", "open")
    animator.playSound("shieldOn")
    self.moveSpeed = 70
    self.protection = 80
  elseif animator.animationState("shield") == "opened" then
    animator.setAnimationState("shield", "close")
    animator.playSound("shieldOff")
    self.protection = config.getParameter("protection")
    self.moveSpeed = config.getParameter("moveSpeed")
  end
end

function isFiring()
  return self.firing
end

function startFiring()
  self.firing = true
end

function stopFiring()
  self.firing = false
end

-- coroutine for firing pods
function firePods()
  while true do

    local frontLoaded = false

    if self.firing then
      animator.setAnimationState("frontcannon", "open")
 
      util.wait(0.25)
      
      if storage.ammo > 0 and self.firing then
        animator.setAnimationState("frontcannon", "load")
   
  
        frontLoaded = true
        util.wait(0.15)
      end

      while self.firing do
        if frontLoaded then
          animator.setAnimationState("frontcannon", "fire")
          util.wait(0.1)

          local fireOffset = animator.partPoint("frontcannon", "fireOffset")
          local aimDir = 1

          aimDir = aimDir * util.toDirection(self.facingDirection)       

          world.spawnProjectile("at_ext_shipc2missile2", vec2.add(mcontroller.position(), fireOffset), entity.id(), {aimDir, 0}, false)
          animator.burstParticleEmitter("frontMuzzle")
          animator.playSound("fire")
          util.wait(0.1)

          storage.ammo = storage.ammo - 1
          frontLoaded = false
        else
          -- there has to be at least one yield in this loop even when not firing
          coroutine.yield()
        end
        
        if storage.ammo > 0 then
          animator.setAnimationState("frontcannon", "load")
          frontLoaded = true
        end



      end
      util.wait(0.15)

      animator.setAnimationState("frontcannon", "close")


      util.wait(0.15)
    end

    coroutine.yield()
  end
end

function applyDamage(damageRequest)
  local damage = 0
  if damageRequest.damageType == "Damage" then
    damage = damage + root.evalFunction2("protection", damageRequest.damage, self.protection)
  elseif damageRequest.damageType == "IgnoresDef" then
    damage = damage + damageRequest.damage
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