require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/vehicles/at_ext_ship_medium/at_ext_ship_medium.lua"

function init()
  initMediumShip()
end

function update(dt)
  local moveDir = {0, 0}
  if vehicle.controlHeld("seat", "right") then moveDir[1] = moveDir[1] + 1 end
  if vehicle.controlHeld("seat", "left") then moveDir[1] = moveDir[1] - 1 end
  if vehicle.controlHeld("seat", "up") then moveDir[2] = moveDir[2] + 1 end
  if vehicle.controlHeld("seat", "down") then moveDir[2] = moveDir[2] - 1 end
  updateMediumShip(dt, vehicle.entityLoungingIn("seat"), moveDir)
end
