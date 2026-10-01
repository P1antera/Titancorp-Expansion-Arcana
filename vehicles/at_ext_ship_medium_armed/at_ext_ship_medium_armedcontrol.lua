require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/vehicles/at_ext_ship_medium_armed/at_ext_ship_medium_armed.lua"

function init()
  initMediumShip()
  self.lastAltFire = false
  self.lastSpecial1 = false
end

function update(dt)
  local moveDir = {0, 0}
  if vehicle.controlHeld("seat", "right") then moveDir[1] = moveDir[1] + 1 end
  if vehicle.controlHeld("seat", "left") then moveDir[1] = moveDir[1] - 1 end
  if vehicle.controlHeld("seat", "up") then moveDir[2] = moveDir[2] + 1 end
  if vehicle.controlHeld("seat", "down") then moveDir[2] = moveDir[2] - 1 end
  local driver = vehicle.entityLoungingIn("seat")

  if driver and vehicle.controlHeld("seat", "primaryFire") then
    startCannonFire()
  else
    stopCannonFire()
  end

  local altFire = driver and vehicle.controlHeld("seat", "altFire")
  if altFire and not self.lastAltFire then
    triggerMissileBurst()
  end
  self.lastAltFire = altFire

  local special1 = driver and vehicle.controlHeld("seat", "special1")
  if special1 and not self.lastSpecial1 then
    dropBomb()
  end
  self.lastSpecial1 = special1

  updateMediumShip(dt, driver, moveDir)
end
