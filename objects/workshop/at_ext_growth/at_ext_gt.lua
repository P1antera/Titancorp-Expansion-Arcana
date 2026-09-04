require "/scripts/automation/arcana_power.lua"

pInit = init
function init()
  if pInit then pInit() end
  local configPath = config.getParameter("configPath", "/objects/workshop/at_ext_growth/config.config")
  self.machineConfig = root.assetJson(configPath)
  self.consumptionTime = config.getParameter("consumptionTime", 1.0)
  self.consumptionTimer = storage.growthConsumptionTimer or self.consumptionTime
  self.craftingTime = self.machineConfig.craftingTime or 1
  self.cooldownTimer = storage.growthCooldownTimer or 0
  self.outputRate = self.machineConfig.outputRate or 1
  self.recipes = self.machineConfig.recipes or {}
  self.farmableOverrides = self.machineConfig.farmableOverrides or {}
  self.farmableResolverVersion = self.machineConfig.farmableResolverVersion or 1
  self.farmableSampleCount = self.machineConfig.farmableSampleCount or 32
  self.powerUseAmount = config.getParameter("powerUseAmount", 0)
  storage.farmableResolutionCache = storage.farmableResolutionCache or {}
  if storage.farmableResolverVersion ~= self.farmableResolverVersion then
    storage.farmableResolutionCache = {}
    storage.farmableResolverVersion = self.farmableResolverVersion
  end
  power.set(0)
  self.isPowered = false
  self.isWorking = storage.growthBatchActive == true and storage.growthPendingOutput ~= nil
  -- A restored batch always waits for its power connection to be checked before resuming.
  self.isPaused = self.isWorking and self.cooldownTimer > 0
  self.isOutputBlocked = false
  self.pendingOutput = self.isWorking and storage.growthPendingOutput or nil
  if not self.isWorking then
    self.cooldownTimer = 0
    self.consumptionTimer = self.consumptionTime
  end
  animator.setGlobalTag("directives", config.getParameter("directives", ""))
  animator.setAnimationState("switchState", self.isWorking and not self.isPaused and "on" or "off")

  message.setHandler("getProgress", function()
    if self.isWorking and self.craftingTime > 0 then
      return math.max(0, math.min(1, 1 - (self.cooldownTimer / self.craftingTime)))
    end
    return 0
  end)
end


function uninit()
  persistBatch()
end

function persistBatch()
  if self.isWorking and self.pendingOutput then
    storage.growthBatchActive = true
    storage.growthCooldownTimer = self.cooldownTimer
    storage.growthConsumptionTimer = self.consumptionTimer
    storage.growthPendingOutput = self.pendingOutput
  else
    storage.growthBatchActive = false
    storage.growthCooldownTimer = nil
    storage.growthConsumptionTimer = nil
    storage.growthPendingOutput = nil
  end
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

function itemConfigSafely(item)
  local success, itemConfig = pcall(root.itemConfig, item)
  if success and itemConfig and itemConfig.config then return itemConfig end
  return nil
end

function isFarmable(item)
  local itemConfig = itemConfigSafely(item)
  return itemConfig and itemConfig.config.objectType == "farmable"
end

function isValidItemName(itemName)
  return itemName and itemConfigSafely({name = itemName, count = 1}) ~= nil
end

function stableSeed(value)
  local hash = 0
  for index = 1, #value do
    hash = (hash * 31 + string.byte(value, index)) % 2147483647
  end
  return hash
end

function matureHarvestPool(seed)
  local itemConfig = itemConfigSafely(seed)
  if not itemConfig or itemConfig.config.objectType ~= "farmable" then return nil end

  for _, stage in ipairs(itemConfig.config.stages or {}) do
    if stage.harvestPool then return stage.harvestPool end
  end
  return nil
end

function resolveFarmableOutput(seed)
  local seedName = seed.name
  local override = self.farmableOverrides[seedName]
  if override == false then return nil end
  if override then
    if isValidItemName(override.output) then
      return {name = override.output, count = self.outputRate}
    end
    return nil
  end

  local cached = storage.farmableResolutionCache[seedName]
  if cached then
    if cached.valid and isValidItemName(cached.output) then
      return {name = cached.output, count = self.outputRate}
    end
    if cached.valid then storage.farmableResolutionCache[seedName] = {valid = false} end
    return nil
  end

  local harvestPool = matureHarvestPool(seed)
  if not harvestPool then
    storage.farmableResolutionCache[seedName] = {valid = false}
    return nil
  end

  local candidates = {}
  for sample = 1, self.farmableSampleCount do
    local success, treasure = pcall(root.createTreasure, harvestPool, 0, stableSeed(seedName .. ":" .. sample))
    if success and treasure then
      for _, item in ipairs(treasure) do
        if item and item.name and not isFarmable(item) then
          candidates[item.name] = (candidates[item.name] or 0) + 1
        end
      end
    end
  end

  local outputName = nil
  local outputFrequency = -1
  for name, frequency in pairs(candidates) do
    if frequency > outputFrequency or (frequency == outputFrequency and (not outputName or name < outputName)) then
      outputName = name
      outputFrequency = frequency
    end
  end

  if outputName and not isValidItemName(outputName) then outputName = nil end

  storage.farmableResolutionCache[seedName] = outputName and {valid = true, output = outputName} or {valid = false}
  if outputName then return {name = outputName, count = self.outputRate} end
  return nil
end

function inputSlotCount(itemName)
  local count = 0
  local outputSlot = world.containerSize(entity.id()) - 1
  for slot = 0, outputSlot - 1 do
    local item = world.containerItemAt(entity.id(), slot)
    if item and item.name == itemName then count = count + item.count end
  end
  return count
end

function consumeInputSlots(itemName, count)
  local remaining = count
  local outputSlot = world.containerSize(entity.id()) - 1
  for slot = 0, outputSlot - 1 do
    local item = world.containerItemAt(entity.id(), slot)
    if item and item.name == itemName and remaining > 0 then
      local taken = world.containerTakeNumItemsAt(entity.id(), slot, math.min(remaining, item.count))
      remaining = remaining - (taken and taken.count or 0)
    end
  end
  return remaining == 0
end

function tryStartRecipe(recipe)
  local lastItem = world.containerItemAt(entity.id(), world.containerSize(entity.id()) - 1)
  for _, input in pairs(recipe.input or {}) do
    if lastItem and lastItem.name == input.name then return false end
    if not (world.containerAvailable(entity.id(), input) > 0) then return false end
  end

  if lastItem and lastItem.name ~= recipe.output.name then return true end
  if not outputSlotCanFit(recipe.output) then
    self.isOutputBlocked = true
    animator.setAnimationState("switchState", "off")
    return true
  end
  if power.get() < self.powerUseAmount then
    self.isPowered = false
    animator.setAnimationState("switchState", "off")
    return true
  end

  power.remove(self.powerUseAmount)
  for _, input in pairs(recipe.input or {}) do
    world.containerConsume(entity.id(), input)
  end
  self.isPowered = true
  self.isWorking = true
  self.isPaused = false
  self.pendingOutput = recipe.output
  self.cooldownTimer = self.craftingTime
  self.consumptionTimer = self.consumptionTime
  animator.setAnimationState("switchState", "on")
  return true
end

function tryStartDynamicFarmable()
  local outputSlot = world.containerSize(entity.id()) - 1
  for slot = 0, outputSlot - 1 do
    local seed = world.containerItemAt(entity.id(), slot)
    if seed and isFarmable(seed) and inputSlotCount(seed.name) >= 4 and inputSlotCount("liquidwater") >= 2 then
      local outputItem = resolveFarmableOutput(seed)
      if outputItem then
        local lastItem = world.containerItemAt(entity.id(), outputSlot)
        if lastItem and lastItem.name ~= outputItem.name then return false end
        if not outputSlotCanFit(outputItem) then
          self.isOutputBlocked = true
          animator.setAnimationState("switchState", "off")
          return true
        end
        if power.get() < self.powerUseAmount then
          self.isPowered = false
          animator.setAnimationState("switchState", "off")
          return true
        end

        power.remove(self.powerUseAmount)
        if not consumeInputSlots(seed.name, 4) or not consumeInputSlots("liquidwater", 2) then return false end
        self.isPowered = true
        self.isWorking = true
        self.isPaused = false
        self.pendingOutput = outputItem
        self.cooldownTimer = self.craftingTime
        self.consumptionTimer = self.consumptionTime
        animator.setAnimationState("switchState", "on")
        return true
      end
    end
  end
  return false
end

function automation()
  if self.isWorking then return end
  self.isOutputBlocked = false

  for _, recipe in pairs(self.recipes) do
    if tryStartRecipe(recipe) then return end
  end
  if tryStartDynamicFarmable() then return end

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

  persistBatch()
end
