require "/scripts/util.lua"

local function atExtMovementBlockedByCrouch(board)
  return (board:getNumber("atExtCrouchTimer") or 0) > 0 or mcontroller.crouching()
end

function atExtControlledGuardFire(args, board, nodeId)
  if args.entity == nil or not world.entityExists(args.entity) then
    return false
  end

  if not entity.entityInSight(args.entity) then
    self.primaryFire = false
    npc.endPrimaryFire()
    return false
  end

  local burstRange = args.burstRange or 100
  local interval = args.interval or 1.5
  local fireTime = args.fireTime or 0.15
  local distance = world.magnitude(mcontroller.position(), world.entityPosition(args.entity))

  if distance <= burstRange then
    self.primaryFire = true
    return true
  end

  local now = world.time()
  local prefix = "atExtBurstFire-" .. nodeId
  local fireUntil = board:getNumber(prefix .. "-until") or 0
  local nextFire = board:getNumber(prefix .. "-next") or 0

  if now < fireUntil then
    self.primaryFire = true
    return true
  end

  if now >= nextFire then
    board:setNumber(prefix .. "-until", now + fireTime)
    board:setNumber(prefix .. "-next", now + interval)
    self.primaryFire = true
    return true
  end

  return false
end

function atExtAdvanceWhileFiring(args, board, nodeId)
  if args.entity == nil or not world.entityExists(args.entity) then
    return false
  end

  if not entity.entityInSight(args.entity) then
    return false
  end

  if status.resourceLocked("energy") then
    return false
  end

  if atExtMovementBlockedByCrouch(board) then
    return false
  end

  local targetPosition = world.entityPosition(args.entity)
  local selfPosition = mcontroller.position()
  local distance = world.magnitude(selfPosition, targetPosition)
  local stopRange = args.stopRange or 55
  local maxRange = args.maxRange or 120

  if distance <= stopRange or distance > maxRange then
    return false
  end

  local now = world.time()
  local prefix = "atExtAdvanceWhileFiring-" .. nodeId
  local nextAttempt = board:getNumber(prefix .. "-next") or 0

  if now < nextAttempt then
    return false
  end

  local chance = args.chance or 0.35
  local retryInterval = args.retryInterval or 1
  local cooldown = args.cooldown or 5

  if math.random() >= chance then
    board:setNumber(prefix .. "-next", now + retryInterval)
    return false
  end

  board:setNumber(prefix .. "-next", now + cooldown)

  local timer = args.duration or 1
  while timer > 0 do
    if args.entity == nil or not world.entityExists(args.entity) or status.resourceLocked("energy") or not entity.entityInSight(args.entity) or atExtMovementBlockedByCrouch(board) then
      self.primaryFire = false
      npc.endPrimaryFire()
      break
    end

    targetPosition = world.entityPosition(args.entity)
    selfPosition = mcontroller.position()
    distance = world.magnitude(selfPosition, targetPosition)

    if distance <= stopRange or distance > maxRange then
      break
    end

    local toTarget = world.distance(targetPosition, selfPosition)
    local faceDirection = util.toDirection(toTarget[1])
    mcontroller.controlFace(faceDirection)
    mcontroller.controlMove(faceDirection, args.run)
    board:setPosition("aimPosition", targetPosition)
    npc.setAimPosition(targetPosition)

    timer = timer - script.updateDt()
    coroutine.yield()
  end

  return true
end

function atExtBackpedalFromTarget(args, board, nodeId)
  if args.entity == nil or not world.entityExists(args.entity) then
    return false
  end

  if atExtMovementBlockedByCrouch(board) then
    return false
  end

  local startRange = args.startRange or 70
  local stopRange = args.stopRange or 30
  local stuckTimeout = args.stuckTimeout or 3
  local retryDelay = args.retryDelay or 1
  local retryKey = "atExtBackpedalFromTarget-" .. tostring(nodeId or "default") .. "-retryAt"

  if world.time() < (board:getNumber(retryKey) or 0) then
    return false
  end

  local targetPosition = world.entityPosition(args.entity)
  local selfPosition = mcontroller.position()
  local distance = world.magnitude(selfPosition, targetPosition)

  if distance > startRange or distance <= stopRange then
    return false
  end

  if board then
    board:setNumber("atExtRetreatHold", 1)
  end

  local lastProgressPosition = selfPosition
  local stuckTimer = stuckTimeout
  while stuckTimer > 0 do
    if args.entity == nil or not world.entityExists(args.entity) or atExtMovementBlockedByCrouch(board) then
      return false
    end

    targetPosition = world.entityPosition(args.entity)
    selfPosition = mcontroller.position()
    distance = world.magnitude(selfPosition, targetPosition)

    if distance > startRange then
      return true
    end

    if world.magnitude(selfPosition, lastProgressPosition) > 0.1 then
      lastProgressPosition = selfPosition
      stuckTimer = stuckTimeout
    else
      stuckTimer = stuckTimer - script.updateDt()
    end

    local toTarget = world.distance(targetPosition, selfPosition)
    local faceDirection = util.toDirection(toTarget[1])
    mcontroller.controlFace(faceDirection)
    mcontroller.controlMove(-faceDirection, args.run)
    npc.setAimPosition(targetPosition)

    coroutine.yield()
  end

  board:setNumber(retryKey, world.time() + retryDelay)

  return true
end

function atExtHoldRetreatPosition(args, board)
  if args.entity == nil or not world.entityExists(args.entity) then
    return false
  end

  if (board:getNumber("atExtRetreatHold") or 0) <= 0 then
    return false
  end

  local startRange = args.startRange or 70
  local maxRange = args.maxRange or 120
  local targetPosition = world.entityPosition(args.entity)
  local selfPosition = mcontroller.position()
  local distance = world.magnitude(selfPosition, targetPosition)

  if distance <= startRange then
    return false
  end

  if distance > maxRange then
    board:setNumber("atExtRetreatHold", 0)
    return false
  end

  local toTarget = world.distance(targetPosition, selfPosition)
  mcontroller.controlFace(util.toDirection(toTarget[1]))
  npc.setAimPosition(targetPosition)

  return true
end
