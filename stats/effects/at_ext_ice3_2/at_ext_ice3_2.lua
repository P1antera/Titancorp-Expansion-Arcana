function init()
  effect.addStatModifierGroup({
    { stat = "protection", amount = config.getParameter("protection", 5) },
    { stat = "maxHealth", amount = config.getParameter("maxHealth", 20) }
  })
end

function update(dt)
end
