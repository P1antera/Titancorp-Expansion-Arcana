require "/scripts/vec2.lua"

function init()
  vehicleType = config.getParameter("vehicleType")
  vehicleSpawnOffset = config.getParameter("vehicleSpawnOffset", {0,0})
end

function update(dt)
end

function uninit()
  local vehiclePosition = vec2.add(entity.position(), vehicleSpawnOffset)
  world.spawnVehicle(vehicleType, vehiclePosition)
end