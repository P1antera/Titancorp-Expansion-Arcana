function init()
  script.setUpdateDelta(5)
 

end

function update(dt)
  if status.resource("health") < status.resourceMax("health") * 0.4  then
    status.modifyResource("health", 0.05 * status.resourceMax("health") * dt)
  end

end


