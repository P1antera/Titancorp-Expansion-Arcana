require "/scripts/util.lua"

function atExtMeleeComboFire(args, board, nodeId)
  local taps = args.taps or 3
  local pressTime = args.pressTime or 0.08
  local releaseTime = args.releaseTime or 0.12

  for i = 1, taps do
    local timer = pressTime
    while timer > 0 do
      self.primaryFire = true
      timer = timer - script.updateDt()
      coroutine.yield()
    end

    self.primaryFire = false
    npc.endPrimaryFire()

    timer = releaseTime
    while timer > 0 do
      timer = timer - script.updateDt()
      coroutine.yield()
    end
  end

  return true
end
