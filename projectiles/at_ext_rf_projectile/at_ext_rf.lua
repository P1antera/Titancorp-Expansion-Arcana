require "/scripts/vec2.lua"
function init()
   SpawnOffset = config.getParameter("SpawnOffset", {0,0})
   caseType = config.getParameter("caseType", "at_ext_case")
   
end

function update(dt)
end


function uninit()
world.spawnProjectile(caseType, SpawnOffset)
end