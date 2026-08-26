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

function atExtMaintainLostSight(args, board)
  while args.entity ~= nil
      and world.entityExists(args.entity)
      and atExtIsCurrentTrackedTarget(board, args.entity)
      and not entity.entityInSight(args.entity) do
    local idleAimPosition = vec2.add(mcontroller.position(), {mcontroller.facingDirection() * 4, -4})
    board:setNumber("atExtCrouchTimer", 0)
    board:setPosition("pursuitPosition", world.entityPosition(args.entity))
    board:setPosition("aimPosition", idleAimPosition)
    self.primaryFire = false
    self.altFire = false
    npc.endPrimaryFire()
    npc.endAltFire()
    npc.setAimPosition(idleAimPosition)
    coroutine.yield()
  end

  if args.entity ~= nil and world.entityExists(args.entity) and entity.entityInSight(args.entity) then
    local targetPosition = world.entityPosition(args.entity)
    board:setPosition("aimPosition", targetPosition)
    npc.setAimPosition(targetPosition)
  else
    local idleAimPosition = vec2.add(mcontroller.position(), {mcontroller.facingDirection() * 4, -4})
    board:setPosition("aimPosition", idleAimPosition)
    npc.setAimPosition(idleAimPosition)
  end
  npc.endPrimaryFire()
  npc.endAltFire()
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
      board:setPosition("aimPosition", world.entityPosition(args.entity))
    else
      board:setNumber("atExtPursuitActive", 1)
      board:setNumber("atExtCrouchTimer", 0)
      board:setPosition("pursuitPosition", world.entityPosition(args.entity))
      self.primaryFire = false
      self.altFire = false
      npc.endPrimaryFire()
      npc.endAltFire()
    end

    coroutine.yield()
  end

  self.primaryFire = false
  self.altFire = false
  board:setNumber("atExtPursuitActive", 0)
  npc.endPrimaryFire()
  npc.endAltFire()
  npc.setAimPosition(vec2.add(mcontroller.position(), {mcontroller.facingDirection() * 4, -4}))
  return false
end
