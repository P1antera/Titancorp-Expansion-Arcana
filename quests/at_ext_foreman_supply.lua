local propertyKey = "at_ext_foremanSupplyOrder"

function init()
  self.state = player.getProperty(propertyKey) or {}
  self.remainingCooldown = (self.state.cooldownExpiresAt or 0) - os.time()
  local texts = config.getParameter("texts")
  if self.remainingCooldown > 0 then
    quest.setTitle(texts.title)
    quest.setText(sb.replaceTags(texts.cooldown, { seconds = math.ceil(self.remainingCooldown) }))
    quest.setFailureText(sb.replaceTags(texts.cooldown, { seconds = math.ceil(self.remainingCooldown) }))
    quest.fail()
    return
  end

  self.order = self.state.order
  if not self.order then
    local orders = config.getParameter("orders")
    self.order = orders[math.random(#orders)]
    self.state.order = self.order
    player.setProperty(propertyKey, self.state)
  else
 
    for _, order in ipairs(config.getParameter("orders")) do
      if order.itemName == self.order.itemName then
        self.order.materialName = order.materialName
        self.order.reward = order.reward
        self.state.order = self.order
        player.setProperty(propertyKey, self.state)
        break
      end
    end
  end

  self.item = { name = self.order.itemName, count = 80 }
  quest.setTitle(texts.title)
  quest.setText(sb.replaceTags(texts.text, { materialName = self.order.materialName }))
  quest.setCompletionText(sb.replaceTags(texts.completion, { reward = self.order.reward }))
end

function update()
  if not self.order then return end
  local current = player.hasCountOfItem(self.item.name) or 0
  local texts = config.getParameter("texts")
  quest.setObjectiveList({{sb.replaceTags(texts.objective, { current = math.min(current, self.item.count), required = self.item.count, materialName = self.order.materialName }), current >= self.item.count}})
  if current >= self.item.count then
    quest.setCanTurnIn(true)
    quest.setObjectiveList({{texts.turnIn, false}})
  else
    quest.setCanTurnIn(false)
  end
end

function questComplete()
  if not self.order or not player.consumeItem(self.item) then return end
  player.giveItem({ name = "arcana_currency_credit", count = self.order.reward })
  player.setProperty(propertyKey, { cooldownExpiresAt = os.time() + config.getParameter("cooldownSeconds", 600) })
end
