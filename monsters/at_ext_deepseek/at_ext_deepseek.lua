require "/scripts/pathutil.lua"

function init()
  self.idleTime = config.getParameter("idleTime", {3, 7})
  self.wanderTime = config.getParameter("wanderTime", {2, 4})
  self.wanderRadius = config.getParameter("wanderRadius", 50)
  self.bounds = mcontroller.boundBox()
  self.chatPortrait = config.getParameter("chatPortrait")
  self.dialog = config.getParameter("dialog", {})
  self.dialogRange = config.getParameter("dialogRange", 8)
  self.dialogResetRange = math.max(self.dialogRange, config.getParameter("dialogResetRange", 10))
  self.dialogCooldown = config.getParameter("dialogCooldown", 12)
  self.dialogDuration = config.getParameter("dialogDuration", 8)
  self.dialogStopForce = config.getParameter("movementSettings.groundForce", 250)
  self.dialogTimer = 0
  self.dialogCooldownTimer = 0
  self.dialogInteractTimer = 0
  self.dialogNearby = false
  self.obstaclePathOptions = {
    returnBest = false,
    mustEndOnGround = true,
    maxDistance = 12,
    swimCost = 5,
    dropCost = 5,
    boundBox = self.bounds,
    standingBoundBox = self.bounds,
    droppingBoundBox = rect.pad(self.bounds, {0.2, 0}),
    smallJumpMultiplier = 1 / math.sqrt(2),
    jumpDropXMultiplier = 1,
    enableWalkSpeedJumps = true,
    enableVerticalJumpAirControl = false,
    maxFScore = 400,
    maxNodesToSearch = 70000,
    maxLandingVelocity = -45,
    liquidJumpCost = 15
  }
  storage.homePosition = storage.homePosition or mcontroller.position()

  monster.setDamageTeam({type = "friendly", team = 0})
  monster.setAggressive(false)
  monster.setDamageOnTouch(false)
  monster.setInteractive(config.getParameter("interactive", true))
  mcontroller.setAutoClearControls(true)
  script.setUpdateDelta(config.getParameter("initialScriptDelta", 5))
  enterIdle()
end

function update(dt)
  if status.resourcePositive("stunned") then
    updateAnimation()
    return
  end

  updateDialog(dt)
  if self.dialogTimer > 0 then
    local playerPosition = world.entityPosition(self.dialogTarget)
    if playerPosition then
      local direction = world.distance(playerPosition, mcontroller.position())[1]
      if math.abs(direction) > 0.25 then
        mcontroller.controlFace(direction)
      end
    end
    mcontroller.controlApproachXVelocity(0, self.dialogStopForce)
    updateAnimation()
    return
  end

  -- Finish a step or jump path even while airborne.
  if self.obstacleTarget then
    self.obstacleTimer = math.max(0, self.obstacleTimer - dt)
    local result = mcontroller.controlPathMove(self.obstacleTarget, false, self.obstaclePathOptions)
    if result == true then
      self.obstacleTarget = nil
    elseif result == false or self.obstacleTimer == 0 then
      mcontroller.clearControls()
      self.nextDirection = -self.direction
      enterIdle()
    end
    updateAnimation()
    return
  end

  self.stateTimer = math.max(0, self.stateTimer - dt)
  if self.stateTimer == 0 then
    if self.state == "idle" then
      startWandering()
    else
      enterIdle()
    end
  end

  if self.state == "wander" and mcontroller.onGround() then
    local position = mcontroller.position()
    local distance = world.distance(position, storage.homePosition)[1]
    local walkable, wall = canWalk(self.direction, position)
    if distance * self.direction >= self.wanderRadius then
      self.nextDirection = -self.direction
      enterIdle()
    elseif walkable then
      mcontroller.controlFace(self.direction)
      mcontroller.controlMove(self.direction, false)
    elseif not startObstaclePath(position, not wall) then
      self.nextDirection = -self.direction
      enterIdle()
    end
  end

  updateAnimation()
end

function updateDialog(dt)
  self.dialogTimer = math.max(0, self.dialogTimer - dt)
  self.dialogCooldownTimer = math.max(0, self.dialogCooldownTimer - dt)
  self.dialogInteractTimer = math.max(0, self.dialogInteractTimer - dt)
  if self.dialogTimer > 0 or #self.dialog == 0 then
    return
  end

  local players = world.playerQuery(mcontroller.position(), self.dialogResetRange,
    {order = "nearest", boundMode = "position"})
  if #players == 0 then
    self.dialogNearby = false
    return
  end
  if self.dialogNearby or self.dialogCooldownTimer > 0
      or self.obstacleTarget or not mcontroller.onGround() then
    return
  end

  for _, playerId in ipairs(players) do
    if sayDialog(playerId) then
      break
    end
  end
end

function sayDialog(playerId)
  if #self.dialog == 0 or self.dialogInteractTimer > 0
      or self.obstacleTarget or not mcontroller.onGround() then
    return false
  end
  local playerPosition = world.entityPosition(playerId)
  local position = mcontroller.position()
  if not playerPosition or world.magnitude(playerPosition, position) > self.dialogRange then
    return false
  end
  local playerMouth = world.entityMouthPosition(playerId) or playerPosition
  if world.lineTileCollision(monster.mouthPosition(), playerMouth,
      {"Null", "Block", "Dynamic", "Slippery"}) then
    return false
  end

  local index = (storage.dialogIndex or 0) % #self.dialog + 1
  if not monster.sayPortrait(self.dialog[index], self.chatPortrait) then
    return false
  end
  storage.dialogIndex = index
  self.dialogTarget = playerId
  self.dialogTimer = self.dialogDuration
  self.dialogCooldownTimer = self.dialogCooldown
  self.dialogInteractTimer = 1
  self.dialogNearby = true
  enterIdle()
  return true
end

function interact(args)
  sayDialog(args.sourceId)
end

function enterIdle()
  self.obstacleTarget = nil
  self.state = "idle"
  self.stateTimer = randomTime(self.idleTime)
  animator.setGlobalTag("idlePose", "5")
end

function startWandering()
  local distance = world.distance(mcontroller.position(), storage.homePosition)[1]
  if math.abs(distance) >= self.wanderRadius then
    self.direction = distance > 0 and -1 or 1
  else
    self.direction = self.nextDirection or (math.random(0, 1) == 0 and -1 or 1)
  end
  self.nextDirection = nil
  self.state = "wander"
  self.stateTimer = randomTime(self.wanderTime)
end

function startObstaclePath(position, descending)
  -- Downward steps use a closer target so a staircase is handled a few steps at a time.
  -- Only accept a lower landing within two blocks; do not jump across a gap.
  local aheadDistance = descending and 2 or 3
  local ahead = {position[1] + self.direction * aheadDistance, position[2]}
  if math.abs(world.distance(ahead, storage.homePosition)[1]) > self.wanderRadius then
    return false
  end
  local minHeight = descending and -2 or -1
  local maxHeight = descending and 0 or 3
  local target = findGroundPosition(ahead, minHeight, maxHeight, true,
    {"Null", "Block", "Dynamic", "Slippery"}, self.bounds)
  if not target or (descending and target[2] >= position[2] - 0.125) then
    return false
  end
  self.obstacleTarget = target
  self.obstacleTimer = 3
  return true
end

function canWalk(direction, position)
  -- Leave a little room above the floor so the wall test does not hit the ground.
  local wall = {
    position[1] + self.bounds[1] + direction * 0.5,
    position[2] + self.bounds[2] + 0.25,
    position[1] + self.bounds[3] + direction * 0.5,
    position[2] + self.bounds[4] - 0.125
  }
  if world.rectTileCollision(wall, {"Null", "Block", "Dynamic", "Slippery"}) then
    return false, true
  end

  -- Platforms support her feet but do not count as walls.
  local edge = direction > 0 and self.bounds[3] or self.bounds[1]
  local ahead = position[1] + edge + direction * 0.5
  local feet = position[2] + self.bounds[2]
  return world.lineTileCollision({ahead, feet + 0.125}, {ahead, feet - 1.0},
    {"Null", "Block", "Dynamic", "Slippery", "Platform"})
end

function updateAnimation()
  local verticalVelocity = mcontroller.yVelocity()
  local grounded = mcontroller.onGround()
  -- Native pathing marks Land as ground movement before onGround becomes true.
  if not grounded and mcontroller.groundMovement()
      and not mcontroller.jumping() and not mcontroller.falling() then
    grounded = math.abs(verticalVelocity) < 0.1
  end

  local state
  if not grounded then
    state = verticalVelocity > 0 and "jump" or "fall"
  elseif math.abs(mcontroller.xVelocity()) > 0.1 then
    state = "walk"
  else
    state = "idle"
  end
  animator.setAnimationState("movement", state)
end

function randomTime(range)
  return range[1] + math.random() * (range[2] - range[1])
end

function shouldDie()
  return status.resource("health") <= 0
end
