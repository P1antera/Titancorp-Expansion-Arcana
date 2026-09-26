require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/vehicles/at_ext_ship_c3/at_ext_ship_c3.lua"

function init()
  initShip()
  self.lastAltFire = false
end

function update(dt)
  local moveDir = {0, 0}
  if vehicle.controlHeld("seat", "right") then
    moveDir[1] = moveDir[1] + 1
    animator.setAnimationState("thrust", "on")
  end
  if vehicle.controlHeld("seat", "left") then
    moveDir[1] = moveDir[1] - 1
    animator.setAnimationState("thrust", "on")
  end
  if vehicle.controlHeld("seat", "up") then
    moveDir[2] = moveDir[2] + 1
    animator.setAnimationState("bottomthrust", "on")
  end
  if vehicle.controlHeld("seat", "down") then
    moveDir[2] = moveDir[2] - 1
    animator.setAnimationState("bottomthrust", "on")
  end

  if vehicle.controlHeld("seat", "primaryFire") then
    startFiring()
  else
    stopFiring()
  end

  local altFire = vehicle.controlHeld("seat", "altFire")
  if altFire and not self.lastAltFire then
    triggerMissileBurst()
  end
  self.lastAltFire = altFire

  updateShip(dt, vehicle.entityLoungingIn("seat"), moveDir)
end
