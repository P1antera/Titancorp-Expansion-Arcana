require "/scripts/util.lua"

local function atExtCanCrouch()
  return status.resourcePercentage("energy") > 0 and not status.resourceLocked("energy")
end

local function atExtMovementOverridesCrouch(board)
  local target = board:getEntity("target")
  return target ~= nil
      and world.entityExists(target)
      and not entity.entityInSight(target)
end

function atExtCrouchOnHit(args, board)
  return atExtTryCrouch(args, board)
end

function atExtTryCrouch(args, board)
  if not atExtCanCrouch() or atExtMovementOverridesCrouch(board) then
    board:setNumber("atExtCrouchTimer", 0)
    return false
  end

  local chance = args.chance or 0.5
  local duration = args.duration or 0.6

  if math.random() < chance then
    board:setNumber("atExtCrouchTimer", duration)
    return true
  end

  return false
end

function atExtCombatCrouchTick(args, board, nodeId)
  if not atExtCanCrouch() or atExtMovementOverridesCrouch(board) then
    board:setNumber("atExtCrouchTimer", 0)
    return true
  end

  local interval = args.interval or 2
  local key = "atExtCombatCrouchNext-" .. nodeId
  local now = world.time()
  local nextTime = board:getNumber(key) or 0

  if now >= nextTime then
    board:setNumber(key, now + interval)
    atExtTryCrouch(args, board)
  end

  return true
end

function atExtMaintainCrouch(args, board)
  local timer = board:getNumber("atExtCrouchTimer") or 0

  if timer > 0 and (not atExtCanCrouch() or atExtMovementOverridesCrouch(board)) then
    board:setNumber("atExtCrouchTimer", 0)
    return false
  end

  if timer > 0 then
    mcontroller.controlCrouch()
    board:setNumber("atExtCrouchTimer", timer - script.updateDt())
    return true
  end

  return false
end

function atExtMovementAllowed(args, board)
  local timer = board:getNumber("atExtCrouchTimer") or 0
  return timer <= 0 and not mcontroller.crouching()
end

function atExtMaintainMovementAllowed(args, board)
  while atExtMovementAllowed(args, board) do
    coroutine.yield()
  end

  return false
end
