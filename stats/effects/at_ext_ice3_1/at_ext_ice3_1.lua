function init()
  effect.addStatModifierGroup({
    { stat = "protection", amount = config.getParameter("protection", 5) }
  })
end

function update(dt)
end
