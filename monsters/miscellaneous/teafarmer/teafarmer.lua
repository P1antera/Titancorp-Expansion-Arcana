require "/scripts/behavior.lua"
require "/scripts/pathing.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/poly.lua"
require "/scripts/drops.lua"
require "/scripts/status.lua"
require "/scripts/companions/capturable.lua"
require "/scripts/tenant.lua"
require "/scripts/actions/movement.lua"
require "/scripts/actions/animator.lua"

-- Engine callback - called on initialization of entity
function init()
  self.pathing = {}

  self.shouldDie = true
  self.notifications = {}
  storage.spawnTime = world.time()
  if storage.spawnPosition == nil or config.getParameter("wasRelocated", false) then
    local position = mcontroller.position()
    local groundSpawnPosition
    if mcontroller.baseParameters().gravityEnabled then
      groundSpawnPosition = findGroundPosition(position, -20, 3)
    end
    storage.spawnPosition = groundSpawnPosition or position
  end

  self.behavior = behavior.behavior(config.getParameter("behavior"), sb.jsonMerge(config.getParameter("behaviorConfig", {}), skillBehaviorConfig()), _ENV)
  self.board = self.behavior:blackboard()
  self.board:setPosition("spawn", storage.spawnPosition)

  self.collisionPoly = mcontroller.collisionPoly()

  if animator.hasSound("deathPuff") then
    monster.setDeathSound("deathPuff")
  end
  if config.getParameter("deathParticles") then
    monster.setDeathParticleBurst(config.getParameter("deathParticles"))
  end

  script.setUpdateDelta(config.getParameter("initialScriptDelta", 5))
  mcontroller.setAutoClearControls(false)
  self.behaviorTickRate = config.getParameter("behaviorUpdateDelta", 2)
  self.behaviorTick = math.random(1, self.behaviorTickRate)

  animator.setGlobalTag("flipX", "")
  self.board:setNumber("facingDirection", mcontroller.facingDirection())

  capturable.init()

  -- Listen to damage taken
  self.damageTaken = damageListener("damageTaken", function(notifications)
    for _,notification in pairs(notifications) do
      if notification.healthLost > 0 then
        self.damaged = true
        self.board:setEntity("damageSource", notification.sourceEntityId)
      end
    end
  end)

  self.debug = true
  self.targetPosition = nil
  
  monster.setDamageTeam(world.entityDamageTeam(config.getParameter("spawnerId")))

  message.setHandler("travelToPosition",
      function(_, _, pos, id)
	    
		mcontroller.setPosition({pos[1],pos[2]})
		--sb.logInfo("successfulTravelToPosition")
			
		--world.sendEntityMessage(id, "HELP ME")
      end)
   message.setHandler("targetPosition",
      function(_, _, pos, id)
	    
		self.targetPosition = pos
		--sb.logInfo("successfulTravelToPosition")
			
		--world.sendEntityMessage(id, "HELP ME")
      end)
  message.setHandler("setOwner", --id is supposed to be controlling player's ID
      function(_, _, id)
		--sb.logInfo("settingOwnerInfo")
	    storage.owner = id
		
		monster.setName(id)
		--monster.setDamageTeam(world.entityDamageTeam(id))
		--sb.logInfo(sb.printJson(world.entityDamageTeam(entity.id())))
      end)
  message.setHandler("hasOwner",
      function(_, _, id)
	    if not storage.owner then return false end
		return true
      end)
  message.setHandler("ping",
	  function (_,_)
		animator.playSound("ping")
		animator.setAnimationState("body","fire")
	  end)
  self.speedType = "controlled"
  message.setHandler("changeSpeed",
      function(_, _, speedType)
	    
		self.speedType = speedType
		if speedType == "fast" then
			animator.playSound("speedUp")
		else
			animator.playSound("speedDown")
		end
		--sb.logInfo("changedSpeedTo: "..speedType)
      end)
	

  message.setHandler("notify", function(_,_,notification)
      return notify(notification)
    end)
  message.setHandler("despawn", function()
      monster.setDropPool(nil)
      monster.setDeathParticleBurst(nil)
      monster.setDeathSound(nil)
      self.deathBehavior = nil
      self.shouldDie = true
	  
	  animator.playSound("deactivate")
      status.addEphemeralEffect("monsterdespawn")
    end)

  local deathBehavior = config.getParameter("deathBehavior")
  if deathBehavior then
    self.deathBehavior = behavior.behavior(deathBehavior, config.getParameter("behaviorConfig", {}), _ENV, self.behavior:blackboard())
  end

  self.forceRegions = ControlMap:new(config.getParameter("forceRegions", {}))
  self.damageSources = ControlMap:new(config.getParameter("damageSources", {}))
  self.touchDamageEnabled = false

  if config.getParameter("elite", false) then
    status.setPersistentEffects("elite", {"elitemonster"})
  end

  if config.getParameter("damageBar") then
    monster.setDamageBar(config.getParameter("damageBar"));
  end

  monster.setInteractive(config.getParameter("interactive", false))

  monster.setAnimationParameter("chains", config.getParameter("chains"))
  
  self.checkOwnerTicks = 5
  animator.playSound("activate")
end

function update(dt)

  -- if unsucessful in pairing, despawn.
  --sb.logInfo(sb.printJson(world.entityName(entity.id()) == ""))
  if self.checkOwnerTicks > 0 and world.entityName(entity.id()) == "" then
	self.checkOwnerTicks = self.checkOwnerTicks - 1
	
	if self.checkOwnerTicks == 0 then
	  monster.setDropPool(nil)
      monster.setDeathParticleBurst(nil)
      monster.setDeathSound(nil)
      self.deathBehavior = nil
      self.shouldDie = true
	  
	  animator.playSound("deactivate")
      status.addEphemeralEffect("monsterdespawn")
	end
  end
  
  
  capturable.update(dt)
  self.damageTaken:update()

  if status.resourcePositive("stunned") then
    animator.setAnimationState("damage", "stunned")
    animator.setGlobalTag("hurt", "hurt")
    self.stunned = true
    mcontroller.clearControls()
    if self.damaged then
      self.suppressDamageTimer = config.getParameter("stunDamageSuppression", 0.5)
      monster.setDamageOnTouch(false)
    end
    return
  else
    animator.setGlobalTag("hurt", "")
    animator.setAnimationState("damage", "none")
  end

  -- Suppressing touch damage
  if self.suppressDamageTimer then
    monster.setDamageOnTouch(false)
    self.suppressDamageTimer = math.max(self.suppressDamageTimer - dt, 0)
    if self.suppressDamageTimer == 0 then
      self.suppressDamageTimer = nil
    end
  elseif status.statPositive("invulnerable") then
    monster.setDamageOnTouch(false)
  else
    monster.setDamageOnTouch(self.touchDamageEnabled)
  end
  
  -- Drone Movement
  if self.targetPosition then
	local differenceVector = vec2.sub(self.targetPosition,mcontroller.position())
	local magDiff = vec2.mag(differenceVector)
	local velMag = 30
	local minTriggerDistance = 2
	local maxSpeedDistance = 14
	local controlForce = 125
	
	if self.speedType == "fast" then velMag = 60; controlForce = 75; end
	local speedMult = (math.min(magDiff,maxSpeedDistance)-minTriggerDistance)/(maxSpeedDistance-minTriggerDistance)
	velMag = velMag * speedMult
	
	local targetVel = {velMag*differenceVector[1]/magDiff,velMag*differenceVector[2]/magDiff}
	
	--if (magDiff > 3 and magDiff < 3.5 and math.abs(mcontroller.xVelocity()) > 1 and math.abs(mcontroller.yVelocity()) > 1) or (magDiff > 3.5 and mcontroller.xVelocity() == 0 and mcontroller.yVelocity() == 0) then
	if magDiff > minTriggerDistance then
		mcontroller.controlApproachVelocity(targetVel, controlForce)
		
		if targetVel[1] > 0 then
			mcontroller.controlFace(1)
		elseif targetVel[1] < 0 then
			mcontroller.controlFace(-1)
		end
	else
		--mcontroller.setVelocity({0,0})
		mcontroller.controlApproachVelocity({0,0}, controlForce)
	end
  end

  if self.behaviorTick >= self.behaviorTickRate then
    self.behaviorTick = self.behaviorTick - self.behaviorTickRate
    mcontroller.clearControls()

    self.tradingEnabled = false
    self.setFacingDirection = false
    self.moving = false
    self.rotated = false
    self.forceRegions:clear()
    self.damageSources:clear()
    self.damageParts = {}
    clearAnimation()

    if self.behavior then
      local board = self.behavior:blackboard()
      board:setEntity("self", entity.id())
      board:setPosition("self", mcontroller.position())
      board:setNumber("dt", dt * self.behaviorTickRate)
      board:setNumber("facingDirection", self.facingDirection or mcontroller.facingDirection())

      self.behavior:run(dt * self.behaviorTickRate)
    end
    BGroup:updateGroups()

    updateAnimation()

    if not self.rotated and self.rotation then
      mcontroller.setRotation(0)
      animator.resetTransformationGroup(self.rotationGroup)
      self.rotation = nil
      self.rotationGroup = nil
    end

    self.interacted = false
    self.damaged = false
    self.stunned = false
    self.notifications = {}

    setDamageSources()
    setPhysicsForces()
    monster.setDamageParts(self.damageParts)
    overrideCollisionPoly()
  end
  self.behaviorTick = self.behaviorTick + 1
  
  if config.getParameter("facingMode", "control") == "transformation" then
    mcontroller.controlFace(1)
  end
end

function skillBehaviorConfig()
  local skills = config.getParameter("skills", {})
  local skillConfig = {}

  for _,skillName in pairs(skills) do
    local skillHostileActions = root.monsterSkillParameter(skillName, "hostileActions")
    if skillHostileActions then
      construct(skillConfig, "hostileActions")
      util.appendLists(skillConfig.hostileActions, skillHostileActions)
    end
  end

  return skillConfig
end

function interact(args)
  self.interacted = true
  self.board:setEntity("interactionSource", args.sourceId)
end

function shouldDie()
  return (self.shouldDie and status.resource("health") <= 0) or capturable.justCaptured
end

function die()
  if not capturable.justCaptured then
    if self.deathBehavior then
      self.deathBehavior:run(script.updateDt())
    end
    capturable.die()
  end
  spawnDrops()
end

function uninit()
  BGroup:uninit()
end

function setDamageSources()
  local partSources = {}
  for part,ds in pairs(config.getParameter("damageParts", {})) do
    local damageArea = animator.partPoly(part, "damageArea")
    if damageArea then
      ds.poly = damageArea
      table.insert(partSources, ds)
    end
  end

  local damageSources = util.mergeLists(partSources, self.damageSources:values())
  damageSources = util.map(damageSources, function(ds)
    ds.damage = ds.damage * root.evalFunction("monsterLevelPowerMultiplier", monster.level()) * status.stat("powerMultiplier")
    if ds.knockback and type(ds.knockback) == "table" then
      ds.knockback[1] = ds.knockback[1] * mcontroller.facingDirection()
    end

    local team = entity.damageTeam()
    ds.team = { type = ds.damageTeamType or team.type, team = ds.damageTeam or team.team }

    return ds
  end)
  monster.setDamageSources(damageSources)
end

function setPhysicsForces()
  local regions = util.map(self.forceRegions:values(), function(region)
    if region.type == "RadialForceRegion" then
      region.center = vec2.add(mcontroller.position(), region.center)
    elseif region.type == "DirectionalForceRegion" then
      if region.rectRegion then
        region.rectRegion = rect.translate(region.rectRegion, mcontroller.position())
        util.debugRect(region.rectRegion, "blue")
      elseif region.polyRegion then
        region.polyRegion = poly.translate(region.polyRegion, mcontroller.position())
      end
    end

    return region
  end)

  monster.setPhysicsForces(regions)
end

function overrideCollisionPoly()
  local collisionParts = config.getParameter("collisionParts", {})

  for _,part in pairs(collisionParts) do
    local collisionPoly = animator.partPoly(part, "collisionPoly")
    if collisionPoly then
      -- Animator flips the polygon by default
      -- to have it unflipped we need to flip it again
      if not config.getParameter("flipPartPoly", true) and mcontroller.facingDirection() < 0 then
        collisionPoly = poly.flip(collisionPoly)
      end
      mcontroller.controlParameters({collisionPoly = collisionPoly, standingPoly = collisionPoly, crouchingPoly = collisionPoly})
      break
    end
  end
end

function setupTenant(...)
  require("/scripts/tenant.lua")
  tenant.setHome(...)
end
