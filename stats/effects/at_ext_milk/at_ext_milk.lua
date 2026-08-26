function init()
  effect.addStatModifierGroup({
    { stat = "maxHealth", amount = config.getParameter("maxHealth", 10) }
  })
end

function update(dt)
end
