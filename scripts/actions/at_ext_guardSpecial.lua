require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/behavior/bgroup.lua"

function atExtRandomAltFire(args, board, nodeId)
  if args.entity == nil or not world.entityExists(args.entity) then
    return false
  end

  if not entity.entityInSight(args.entity) then
    return false
  end

  if status.resourceLocked("energy") then
    return false
  end

  local minEnergyPercentage = args.minEnergyPercentage or 0
  local energyPercentage = status.resourcePercentage("energy") or 0
  if minEnergyPercentage > 0 and energyPercentage < minEnergyPercentage then
    return false
  end

  local selfPosition = mcontroller.position()
  local targetPosition = world.entityPosition(args.entity)
  local distance = world.magnitude(selfPosition, targetPosition)
  local minRange = args.minRange or 0
  local maxRange = args.maxRange or 0

  if distance < minRange or (maxRange > 0 and distance > maxRange) then
    return false
  end

  local now = world.time()
  local prefix = "atExtAltFire-" .. nodeId
  local nextAttempt = board:getNumber(prefix .. "-next") or 0

  if now < nextAttempt then
    return false
  end

  local chance = args.chance or 0.2
  local retryInterval = args.retryInterval or 1
  local cooldown = args.cooldown or 8

  if math.random() >= chance then
    board:setNumber(prefix .. "-next", now + retryInterval)
    return false
  end

  board:setNumber(prefix .. "-next", now + cooldown)

  local holdTime = args.holdTime or 0.6
  local timer = holdTime

  while timer > 0 do
    if not world.entityExists(args.entity) or not entity.entityInSight(args.entity) then
      break
    end

    local currentTargetPosition = world.entityPosition(args.entity)
    board:setPosition("aimPosition", currentTargetPosition)
    npc.setAimPosition(currentTargetPosition)
    self.primaryFire = false
    self.altFire = true

    timer = timer - script.updateDt()
    coroutine.yield()
  end

  self.altFire = false
  npc.endAltFire()

  return true
end

local function atExtListContainsEntity(list, entityId)
  for _, listedEntityId in ipairs(list or {}) do
    if listedEntityId == entityId then
      return true
    end
  end
  return false
end

local function atExtIsCurrentTrackedTarget(board, entityId)
  if board:getEntity("target") ~= entityId then
    return false
  end

  return atExtListContainsEntity(board:getList("targets"), entityId)
      or atExtListContainsEntity(board:getList("outOfSight"), entityId)
end

local function atExtIdleRangedAim(board)
  local idleAimPosition = vec2.add(mcontroller.position(), {mcontroller.facingDirection() * 4, -4})
  board:setNumber("atExtCrouchTimer", 0)
  board:setNumber("atExtRetreatHold", 0)
  board:setPosition("aimPosition", idleAimPosition)
  self.primaryFire = false
  self.altFire = false
  npc.endPrimaryFire()
  npc.endAltFire()
  npc.setAimPosition(idleAimPosition)
end

function atExtMaintainLostSight(args, board)
  while args.entity ~= nil
      and world.entityExists(args.entity)
      and atExtIsCurrentTrackedTarget(board, args.entity)
      and not entity.entityInSight(args.entity) do
    atExtIdleRangedAim(board)
    board:setPosition("pursuitPosition", world.entityPosition(args.entity))
    coroutine.yield()
  end

  atExtIdleRangedAim(board)
  if args.entity ~= nil and world.entityExists(args.entity) and entity.entityInSight(args.entity) then
    local targetPosition = world.entityPosition(args.entity)
    board:setPosition("aimPosition", targetPosition)
    npc.setAimPosition(targetPosition)
  end
  return false
end

function atExtPursueLostTarget(args, board)
  local target = args.entity
  if target == nil or not world.entityExists(target)
      or not atExtIsCurrentTrackedTarget(board, target) or entity.entityInSight(target) then
    return false
  end

  if board:getEntity("atExtPursuitTarget") ~= target then
    board:setEntity("atExtPursuitTarget", target)
    board:setNumber("atExtPursuitRetryAt", 0)
  end

  -- Keep the original ground search and path options in moveToPosition. Hold
  -- this branch while waiting so failure cannot fall through to ranged movement.
  local moveArgs = {
    avoidLiquid = true, groundPosition = true, minGround = -20, maxGround = 5,
    run = args.run ~= false
  }
  local movement
  local retryDelay = args.retryDelay or 1
  while world.entityExists(target)
      and atExtIsCurrentTrackedTarget(board, target)
      and not entity.entityInSight(target) do
    atExtIdleRangedAim(board)
    moveArgs.position = world.entityPosition(target)
    board:setPosition("pursuitPosition", moveArgs.position)

    if atExtMovementAllowed(args, board) then
      if not movement and world.time() >= (board:getNumber("atExtPursuitRetryAt") or 0) then
        movement = coroutine.create(function() return moveToPosition(moveArgs, board) end)
      end
      if movement then
        local ok, result = coroutine.resume(movement)
        if not ok then error(result) end
        if coroutine.status(movement) == "dead" then
          movement = nil
          board:setNumber("atExtPursuitRetryAt", world.time() + retryDelay)
        end
      end
    end

    -- Movement can change aim/facing. Finish the tick with weapons lowered.
    atExtIdleRangedAim(board)
    coroutine.yield(nil, {pathfinding = movement ~= nil and mcontroller.pathfinding() or false})
  end

  board:setNumber("atExtPursuitRetryAt", 0)
  atExtIdleRangedAim(board)
  if world.entityExists(target) and atExtIsCurrentTrackedTarget(board, target)
      and entity.entityInSight(target) then
    local targetPosition = world.entityPosition(target)
    board:setPosition("aimPosition", targetPosition)
    npc.setAimPosition(targetPosition)
  end
  return false
end

function atExtPrepareRangedFire(args, board)
  if args.entity == nil or not world.entityExists(args.entity) or not entity.entityInSight(args.entity) then
    self.primaryFire = false
    self.altFire = false
    npc.endPrimaryFire()
    npc.endAltFire()
    return false
  end

  local targetPosition = world.entityPosition(args.entity)
  board:setPosition("targetPosition", targetPosition)
  board:setPosition("aimPosition", targetPosition)
  npc.setAimPosition(targetPosition)
  mcontroller.controlFace(util.toDirection(world.distance(targetPosition, mcontroller.position())[1]))
  return true
end

function atExtResetRangedCombat(args, board)
  self.primaryFire = false
  self.altFire = false
  board:setNumber("atExtPursuitActive", 0)
  board:setNumber("atExtCrouchTimer", 0)
  board:setNumber("atExtRetreatHold", 0)
  board:setNumber("atExtPursuitRetryAt", 0)
  npc.endPrimaryFire()
  npc.endAltFire()
  npc.setAimPosition(vec2.add(mcontroller.position(), {mcontroller.facingDirection() * 4, -4}))

  if BGroup then
    BGroup:leaveTask("combat", "ranged")
    BGroup:leaveGroup("combat")
  end

  return true
end

function atExtRangedFireMonitor(args, board)
  while args.entity ~= nil
      and world.entityExists(args.entity)
      and atExtIsCurrentTrackedTarget(board, args.entity) do
    local movePosition = BGroup:getResource("combat", "movePosition")
    if movePosition ~= nil then
      board:setPosition("rangedPosition", movePosition)
    end

    if entity.entityInSight(args.entity) then
      board:setNumber("atExtPursuitActive", 0)
      board:setNumber("atExtPursuitRetryAt", 0)
      board:setPosition("aimPosition", world.entityPosition(args.entity))
    else
      board:setNumber("atExtPursuitActive", 1)
      board:setPosition("pursuitPosition", world.entityPosition(args.entity))
      atExtIdleRangedAim(board)
    end

    coroutine.yield()
  end

  board:setNumber("atExtPursuitActive", 0)
  board:setNumber("atExtPursuitRetryAt", 0)
  atExtIdleRangedAim(board)
  return false
end
