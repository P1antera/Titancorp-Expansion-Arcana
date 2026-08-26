function init()
  local configPath = config.getParameter("configPath", "/objects/workshop/at_ext_trade/config.config")
  self.consumptionTime = config.getParameter("consumptionTime", 1.0)
  self.consumptionTimer = self.consumptionTime
  self.craftingTime = root.assetJson(configPath).craftingTime or 1
  self.cooldownTimer = self.craftingTime
  self.outputRate = root.assetJson(configPath).outputRate or 1
  self.recipes = root.assetJson(configPath).recipes or nil
  self.powerUseAmount = config.getParameter("powerUseAmount", 0)

  self.weaponPrices = {
    Common = {min = 5, max = 10},
    Uncommon = {min = 30, max = 60},
    Rare = {min = 80, max = 90},
    Legendary = {min = 100, max = 130},
    Essential = {min = 150, max = 200}
  }
  
  self.armorPrices = {
    Common = {min = 10, max = 30},
    Uncommon = {min = 50, max = 75},
    Rare = {min = 80, max = 100},
    Legendary = {min = 200, max = 300},
    Essential = {min = 400, max = 600}
  }

  animator.setGlobalTag("directives", config.getParameter("directives", ""))
end

function uninit()
end

function tablelength(table)
  local count = 0
  for _ in pairs(table) do count = count + 1 end
  return count
end

function output(state)
  local entityTable = object.getOutputNodeIds(0)
  local item = world.containerItemAt(entity.id(), world.containerSize(entity.id()) - 1)
  local adjustedRate = 0
  if object.isOutputNodeConnected(0) and tablelength(entityTable) >= 1 and item then
    adjustedRate = math.ceil(self.outputRate / tablelength(entityTable))
    for key, value in pairs(entityTable) do
      if world.containerSize(key) == nil then return end
      if world.containerItemsFitWhere(key, item)["leftover"] ~= 0 then return end
      local isAssembler = (world.containerSize(key) < 9)

      if isAssembler and world.containerItemsFitWhere(key, item)["slots"][1] == world.containerSize(key) - 1 then return end
      item = world.containerTakeNumItemsAt(entity.id(), world.containerSize(entity.id()) - 1, adjustedRate)
      world.containerAddItems(key, item)
    end
  end
end


function isWeapon(itemDescriptor)
  if not itemDescriptor then return false end
  
  local itemConfig = root.itemConfig(itemDescriptor)
  if not itemConfig or not itemConfig.config then return false end
  
  local tags = itemConfig.config.itemTags or {}
  for _, tag in ipairs(tags) do
    if tag == "weapon" or tag == "shield" or tag == "staff" then
      return true
    end
  end
  return false
end


function isArmor(itemDescriptor)
  if not itemDescriptor then return false end
  
  local itemConfig = root.itemConfig(itemDescriptor)
  if not itemConfig or not itemConfig.config then return false end
  
  local category = itemConfig.config.category or ""
  if category == "chestarmour" or category == "headarmour" or category == "legarmour" or category == "chestwear" or category == "legwear" or category == "headwear" then 
    return true
  end
  return false
end


function getItemPrice(itemDescriptor)
  if not itemDescriptor then return nil end
  
  local itemConfig = root.itemConfig(itemDescriptor)
  if not itemConfig or not itemConfig.config then return nil end
  
  local rarity = itemConfig.config.rarity or "Common"
  local priceConfig = nil
  
  if isWeapon(itemDescriptor) then
    priceConfig = self.weaponPrices[rarity]
  elseif isArmor(itemDescriptor) then
    priceConfig = self.armorPrices[rarity]
  end
  
  if priceConfig then
    local price = math.random(priceConfig.min, priceConfig.max)
    return {name = "arcana_currency_credit", count = price}
  end
  
  return nil
end


function isRecipeAvailable(recipe)
  for _, input in pairs(recipe.input) do
    if world.containerAvailable(entity.id(), input) < input.count then
      return false
    end
  end
  return true
end


function canAddCurrency(currencyCount)
  local lastSlot = world.containerSize(entity.id()) - 1
  local lastSlotItem = world.containerItemAt(entity.id(), lastSlot)
  

  if not lastSlotItem then
    return true
  end
  

  if lastSlotItem.name == "arcana_currency_credit" then
    if lastSlotItem.count + currencyCount <= 9999 then
      return true
    else
      return false
    end
  end
  

  return false
end

function automation()
  local lastSlot = world.containerSize(entity.id()) - 1
  

  for recipeName, recipe in pairs(self.recipes) do
    if isRecipeAvailable(recipe) then

      if canAddCurrency(recipe.output.count) then

        for _, input in pairs(recipe.input) do
          world.containerConsume(entity.id(), input)
        end
        

        world.containerPutItemsAt(entity.id(), recipe.output, lastSlot)
        --animator.setAnimationState("switchState", "on")
        return
      else
        -- 无法添加货币，暂停处理
        return
      end
    end
  end
  

  for i = 0, world.containerSize(entity.id()) - 1 do
    local item = world.containerItemAt(entity.id(), i)
    if item then
      local outputItem = getItemPrice(item)
      if outputItem then

        if canAddCurrency(outputItem.count) then

          world.containerConsumeAt(entity.id(), i, item.count)
          world.containerPutItemsAt(entity.id(), outputItem, lastSlot)
          --animator.setAnimationState("switchState", "on")
          return
        else
          -- 无法添加货币，暂停处理
          return
        end
      end
    end
  end
  

  --animator.setAnimationState("switchState", "off")
end

function update(dt)
  if self.consumptionTimer > 0 then
    self.consumptionTimer = math.max(0, self.consumptionTimer - dt)
    if self.consumptionTimer == 0 then
      self.consumptionTimer = self.consumptionTime
    end
  end
  if self.cooldownTimer > 0 then
    self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
    if self.cooldownTimer == 0 then
      automation()
      output(true)
      self.cooldownTimer = self.craftingTime
    end
  end
end