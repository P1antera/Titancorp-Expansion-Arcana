function buildGatherItemCondition(config)
  local gatherItemCondition = {
    description = config.description or root.assetJson("/quests/quests.config:objectiveDescriptions.gatherItem"),
    itemName = config.itemName,
    count = config.count or 1,
    consume = config.consume or false
  }

  function gatherItemCondition:conditionMet()
    if root.itemType(self.itemName) == "currency" then
      local currency = root.itemConfig(self.itemName).config.currency
      return player.currency(currency) >= self.count
    else
      return player.hasItem({ name = self.itemName, count = self.count })
    end
  end

  function gatherItemCondition:onQuestComplete()
    if self.consume then
      if root.itemType(self.itemName) == "currency" then
        local currency = root.itemConfig(self.itemName).config.currency
        player.consumeCurrency(currency, self.count)
      else
        player.consumeItem({ name = self.itemName, count = self.count })
      end
    end
  end

  function gatherItemCondition:objectiveText()
    local objective = self.description
    objective = objective:gsub("<itemName>", root.itemConfig(self.itemName).config.shortdescription or self.itemName)
    objective = objective:gsub("<required>", self.count)
    local count
    if root.itemType(self.itemName) == "currency" then
      local currency = root.itemConfig(self.itemName).config.currency
      count = player.currency(currency) or 0
    else
      count = player.hasCountOfItem(self.itemName) or 0
    end
    objective = objective:gsub("<current>", count)
    return objective
  end

  return gatherItemCondition
end