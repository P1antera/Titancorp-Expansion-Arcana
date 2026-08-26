require "/scripts/vec2.lua"

function init()
  object.setInteractive(true)
end

function onInteraction()
  world.spawnVehicle("at_ext_car", vec2.add(object.position(),{2,2}))
  object.smash(true)
end