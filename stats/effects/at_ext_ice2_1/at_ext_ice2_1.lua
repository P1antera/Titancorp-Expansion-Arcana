function init()
  effect.addStatModifierGroup({
    { stat = "powerMultiplier", effectiveMultiplier = config.getParameter("powerMultiplier", 1.1) }
  })
end

function update(dt)
end

function uninit()
  local nextEffect = config.getParameter("nextEffect")
  if nextEffect then
    status.addEphemeralEffect(nextEffect, config.getParameter("nextDuration", 180))
  end
end
