require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  -- if config.getParameter("key") == nil then
    -- activeItem.setInstanceValue("key", sb.makeUuid())
  -- end
  self.boundingBox = config.getParameter("boundingBox")
  self.findReconDroneTicks = 0
  self.cameraLocked = false
  script.setUpdateDelta(1)
  
  
  self.pingRange = config.getParameter("pingRange")
  self.pingBandWidth = config.getParameter("pingBandWidth")
  self.pingDuration = config.getParameter("pingDuration")
  self.pingCooldown = config.getParameter("pingCooldown")

  self.pingTimer = 0
  self.cooldownTimer = 0 -- TODO: this should be set in storage to avoid resetting when switching/dropping the item

  local detectConfig = config.getParameter("pingDetectConfig")
  detectConfig.maxRange = self.pingRange
  activeItem.setScriptedAnimationParameter("pingDetectConfig", detectConfig)
  activeItem.setScriptedAnimationParameter("pingLocation", nil)
  
  activeItem.setScriptedAnimationParameter("ownerId", activeItem.ownerEntityId())
  
  animator.setSoundVolume("ping", 4.0)
end

function monsterExists()
 return (storage.monsterId and world.entityExists(storage.monsterId))
end

function activate(fireMode, shiftHeld)
	--local validSpawn = (world.magnitude(mcontroller.position(), activeItem.ownerAimPosition()) <= 10 and placementValid())
    if fireMode == "primary" and not self.primaryHeld and placementValid2() and (storage.monsterId == nil or not world.entityExists(storage.monsterId)) then
		animator.playSound("activate")
		
		local damageTeam = world.entityDamageTeam(activeItem.ownerEntityId())
		local entityId = world.spawnMonster("falconeye", vec2.add(mcontroller.position(),{0,2}),{
			spawnerId = activeItem.ownerEntityId(),
			level = 1,
			damageTeam = damageTeam.team,
			damageTeamType = damageTeam.type,
			aggressive = true
		})
		--sb.logInfo(sb.printJson(entityId))
		
		self.findReconDroneTicks = 45 -- in case of extreme lag
		--findSpawnedReconDrone()
		--sb.logInfo(sb.printJson(monsterId == nil))
	elseif fireMode == "primary" and not self.primaryHeld and monsterExists() then
		--sb.logInfo("despawn plz")
		animator.playSound("deactivate")
		world.sendEntityMessage(storage.monsterId, "despawn")
		storage.monsterId = nil
    end
	
	
	if fireMode == "alt" and ready() and monsterExists() then
		self.pingTimer = self.pingDuration
		local pingLocation = vec2.add(world.entityPosition(storage.monsterId),{-0.5,-0.25})
		activeItem.setScriptedAnimationParameter("pingLocation", pingLocation)
		
		animator.playSound("ping")
		
		world.sendEntityMessage(storage.monsterId, "ping")
	end
  --updateIcon()
end

function update(dt, fireMode, shiftHeld)
	
   if not monsterExists() then
	self.aimAngle, self.facingDirection = activeItem.aimAngleAndDirection(0, activeItem.ownerAimPosition())
	activeItem.setFacingDirection(self.facingDirection)
   
	activeItem.setArmAngle(self.aimAngle)
   end
   
   if monsterExists() then
    --sb.logInfo("Sending entityMessage...")
	--world.sendEntityMessage(storage.monsterId, "travelToPosition", activeItem.ownerAimPosition(),activeItem.ownerEntityId())
	world.sendEntityMessage(storage.monsterId, "targetPosition", activeItem.ownerAimPosition(),activeItem.ownerEntityId())
	
	-- incase drone doesn't successfully set its owner proper
	if world.entityName(storage.monsterId) == "" then
		world.sendEntityMessage(storage.monsterId, "setOwner", activeItem.ownerEntityId())
	end
	
	if not self.cameraLocked then
		activeItem.setCameraFocusEntity(storage.monsterId)
		self.cameraLocked = true
	end
	activeItem.setScriptedAnimationParameter("monsterId", storage.monsterId)
   else
	activeItem.setScriptedAnimationParameter("monsterId", nil)
   end
   
   if self.findReconDroneTicks > 0 then
	findSpawnedReconDrone()
	self.findReconDroneTicks = self.findReconDroneTicks - 1
   end
   
   
   -- if fireMode == "primary" and not self.primaryHeld then
	-- local monsterId = world.spawnMonster("punchy", activeItem.ownerAimPosition(),{})
	-- sb.logInfo(sb.printJson(monsterId))
   -- end
   
   if shiftHeld and not self.shiftWasHeld and monsterExists() then
	--sb.logInfo("sending change speed")
	animator.playSound("speedUp")
	world.sendEntityMessage(storage.monsterId, "changeSpeed", "fast")
   elseif not shiftHeld and self.shiftWasHeld and monsterExists() then
	world.sendEntityMessage(storage.monsterId, "changeSpeed", "controlled")
	animator.playSound("speedDown")
   end
   
   
   -- PING STUFF --
   self.cooldownTimer = math.max(self.cooldownTimer - dt, 0)

   if self.pingTimer > 0 then
    self.pingTimer = math.max(self.pingTimer - dt, 0)
    if self.pingTimer == 0 then
      self.cooldownTimer = self.pingCooldown
      activeItem.setScriptedAnimationParameter("pingLocation", nil)
    else
      local radius = (self.pingRange + self.pingBandWidth) * ((self.pingDuration - self.pingTimer) / self.pingDuration) - self.pingBandWidth
      activeItem.setScriptedAnimationParameter("pingOuterRadius", radius + self.pingBandWidth)
      activeItem.setScriptedAnimationParameter("pingInnerRadius", math.max(radius, 0))
    end
  end
  -- PING STUFF --
   
   self.primaryHeld = fireMode == "primary"
   self.shiftWasHeld = shiftHeld
end

function ready()
  return self.pingTimer == 0 and self.cooldownTimer == 0
end

function findSpawnedReconDrone() -- for some reason, despite saying so in the documentation, I *cannot* pull the EntityId of the monster I spawn via world.spawnMonster(). have to resort to this, unless I find a better solution.
	local pos = activeItem.ownerAimPosition()
	local queryParameters = {
		withoutEntityId = activeItem.ownerEntityId(),
		includedTypes = {"creature"},
		order = "nearest"
	}
	
	local candidates = world.entityQuery(pos, 100, queryParameters)
	for _, candidate in ipairs(candidates) do
		--sb.logInfo(sb.printJson(candidate))
		--sb.logInfo(world.entityTypeName(candidate))
		--local hasOwner = world.sendEntityMessage(candidate, "hasOwner")
		--sb.logInfo(sb.printJson(hasOwner))
		if world.entityTypeName(candidate) == "falconeye" and world.entityName(candidate) == "" then
			--sb.logInfo(sb.printJson(world.entityName(candidate)))
			--sb.logInfo("found recon drone")
			world.sendEntityMessage(candidate, "setOwner", activeItem.ownerEntityId())
			storage.monsterId = candidate
			activeItem.setCameraFocusEntity(candidate)
			self.cameraLocked = true
			self.findReconDroneTicks = 0
		end
	end
end

function placementValid()
  local aimPosition = activeItem.ownerAimPosition()

  if world.lineTileCollision(mcontroller.position(), aimPosition) then
    return false
  end
  
  local boundingBox = self.boundingBox

  local bounds = {
    boundingBox[1] + aimPosition[1],
    boundingBox[2] + aimPosition[2],
    boundingBox[3] + aimPosition[1],
    boundingBox[4] + aimPosition[2]
  }

  if world.rectTileCollision(bounds, {"Null", "Block", "Dynamic", "Slippery"}) then
    return false
  end

  return true
end

function placementValid2()
  local aimPosition = vec2.add(mcontroller.position(),{0,2})

  if world.lineTileCollision(mcontroller.position(), aimPosition) then
    return false
  end
  
  local boundingBox = self.boundingBox

  local bounds = {
    boundingBox[1] + aimPosition[1],
    boundingBox[2] + aimPosition[2],
    boundingBox[3] + aimPosition[1],
    boundingBox[4] + aimPosition[2]
  }

  if world.rectTileCollision(bounds, {"Null", "Block", "Dynamic", "Slippery"}) then
    return false
  end

  return true
end

function uninit()
	if storage.monsterId then world.sendEntityMessage(storage.monsterId, "despawn") end
	storage.monsterId = nil
	
	self.cameraLocked = false
	activeItem.setCameraFocusEntity()
end