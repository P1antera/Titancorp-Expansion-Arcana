require "/scripts/automation/arcana_power.lua"

pInit = init
function init()
  if pInit then pInit() end
  local configPath = config.getParameter("configPath", "/objects/workshop/at_ext_growth/config.config")
  self.consumptionTime = config.getParameter("consumptionTime", 1.0)
  self.consumptionTimer = self.consumptionTime
  self.craftingTime = root.assetJson(configPath).craftingTime or 1
  self.cooldownTimer = 0
  self.outputRate = root.assetJson(configPath).outputRate or 1
  self.recipes = root.assetJson(configPath).recipes or nil
  self.powerUseAmount = config.getParameter("powerUseAmount", 0)
  power.set(0)
  self.isPowered = false
  self.isWorking = false
  self.isPaused = false
  self.isOutputBlocked = false
  self.pendingOutput = nil
  animator.setGlobalTag("directives", config.getParameter("directives", ""))

  message.setHandler("getProgress", function()
    if self.isWorking and self.craftingTime > 0 then
      return math.max(0, math.min(1, 1 - (self.cooldownTimer / self.craftingTime)))
    end
    return 0
  end)
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

function outputSlotCanFit(item)
  local outputSlot = world.containerSize(entity.id()) - 1
  local outputItem = world.containerItemAt(entity.id(), outputSlot)
  if not outputItem then return true end
  if outputItem.name ~= item.name then return false end

  local maxStack = root.itemConfig(outputItem).config.maxStack or 1000
  return outputItem.count + item.count <= maxStack
end

function automation()
  if self.isWorking then return end
  self.isOutputBlocked = false
  local craftable = true
  local lastItem = world.containerItemAt(entity.id(), world.containerSize(entity.id()) - 1)
  
  for i, recipe in pairs(self.recipes) do
  
    craftable = true
    for j, input in pairs(recipe.input) do
	  if lastItem then
	    if lastItem.name == input.name then craftable = false end
	  end
      if not (world.containerAvailable(entity.id(), input) > 0) then craftable = false end
    end
	
	if craftable then
	  if not lastItem or lastItem.name == recipe.output.name then
	    if not outputSlotCanFit(recipe.output) then
	      self.isOutputBlocked = true
	      animator.setAnimationState("switchState", "off")
	      return
	    end
	    if power.get() < self.powerUseAmount then
	      self.isPowered = false
	      animator.setAnimationState("switchState", "off")
	      return
	    end

	    power.remove(self.powerUseAmount)
	    for k, input in pairs(recipe.input) do
        world.containerConsume(entity.id(), input)
      end

	    self.isPowered = true
	    self.isWorking = true
	    self.isPaused = false
	    self.pendingOutput = recipe.output
	    self.cooldownTimer = self.craftingTime
	    animator.setAnimationState("switchState", "on")
	    return
	  else
	    animator.setAnimationState("switchState", "off")
	    return
	  end
	end
	
  end
  animator.setAnimationState("switchState", "off")
  
end

function powerCheck()
  if power.get() >= self.powerUseAmount then 
    if self.isWorking and self.cooldownTimer > 0 then
      power.remove(self.powerUseAmount)
    end
    self.isPowered = true
  else
    self.isPowered = false
    if self.isWorking and self.cooldownTimer > 0 then
      self.isPaused = true
    end
	animator.setAnimationState("switchState", "off")
  end
end

function update(dt)
  if self.isWorking then
    -- A disconnected power cable pauses the current batch immediately.
    if self.cooldownTimer > 0 and not object.isInputNodeConnected(0) then
      self.isPowered = false
      self.isPaused = true
      animator.setAnimationState("switchState", "off")
    elseif self.cooldownTimer > 0 and self.isPaused then
      -- Resume the existing batch only. Its ingredients were consumed when it started.
      if power.get() >= self.powerUseAmount then
        power.remove(self.powerUseAmount)
        self.isPowered = true
        self.isPaused = false
        self.consumptionTimer = self.consumptionTime
        animator.setAnimationState("switchState", "on")
      end
    elseif self.cooldownTimer > 0 then
      self.consumptionTimer = math.max(0, self.consumptionTimer - dt)
      if self.consumptionTimer == 0 then
        powerCheck()
	  self.consumptionTimer = self.consumptionTime
      end

      if not self.isPaused then
        self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
      end
    end

    if self.cooldownTimer == 0 then
      if outputSlotCanFit(self.pendingOutput) then
	    world.containerPutItemsAt(entity.id(), self.pendingOutput, world.containerSize(entity.id()) - 1)
	    self.pendingOutput = nil
	    self.isWorking = false
	    self.isOutputBlocked = false
	    output(true)
      else
	    self.isOutputBlocked = true
	    animator.setAnimationState("switchState", "off")
      end
    end
  end

  if not self.isWorking then
	automation()
  end
end
