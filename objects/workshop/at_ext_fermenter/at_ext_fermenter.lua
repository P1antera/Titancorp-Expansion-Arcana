require "/scripts/automation/arcana_power.lua"

local previousInit = init

function init()
  if previousInit then previousInit() end

  local configPath = config.getParameter("configPath", "/objects/workshop/at_ext_fermenter/config.config")
  self.machineConfig = root.assetJson(configPath)
  self.recipes = self.machineConfig.recipes or {}
  self.stageDurations = self.machineConfig.stageDurations or {60, 60, 120}
  self.totalDuration = self.stageDurations[1] + self.stageDurations[2] + self.stageDurations[3]
  self.powerUseAmount = config.getParameter("powerUseAmount", 20)
  self.consumptionTime = config.getParameter("consumptionTime", 1.0)
  self.outputCapacity = config.getParameter("outputCapacity", 100)

  storage.phase = storage.phase or "off"
  storage.remainingTime = storage.remainingTime or 0
  storage.consumptionTimer = storage.consumptionTimer or self.consumptionTime
  storage.pendingOutput = storage.pendingOutput or nil
  storage.paused = storage.paused or false
  storage.completedOutputs = storage.completedOutputs or {}
  storage.capacityBlocked = storage.capacityBlocked or false

  -- Migrate a batch that was finished under the previous single-output
  -- implementation into the new completed-product inventory.
  if storage.phase == "done" and storage.pendingOutput then
    addCompletedOutput(storage.pendingOutput)
    storage.pendingOutput = nil
    storage.remainingTime = 0
    storage.paused = false
    storage.phase = "off"
  end

  power.set(0)
  object.setInteractive(true)
  animator.setGlobalTag("directives", config.getParameter("directives", ""))
  updateVisuals()

  message.setHandler("getFermenterStatus", function()
    return {
      progress = currentProgress(),
      completed = completedOutputCount(),
      capacity = self.outputCapacity
    }
  end)

  message.setHandler("bottleCompletedOutputs", function()
    return bottleStoredOutputs()
  end)
end

function isBrewing()
  return storage.phase == "stage1" or storage.phase == "stage2" or storage.phase == "stage3"
end

function currentPhase()
  if storage.remainingTime > self.stageDurations[2] + self.stageDurations[3] then
    return "stage1"
  elseif storage.remainingTime > self.stageDurations[3] then
    return "stage2"
  end
  return "stage3"
end

function currentProgress()
  if storage.phase == "off" then return 0 end
  return math.max(0, math.min(1, 1 - (storage.remainingTime / self.totalDuration)))
end

function valuesEqual(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end

  for key, value in pairs(a) do
    if not valuesEqual(value, b[key]) then return false end
  end
  for key in pairs(b) do
    if a[key] == nil then return false end
  end
  return true
end

function completedOutputCount()
  local total = 0
  for _, output in ipairs(storage.completedOutputs or {}) do
    total = total + (output.count or 0)
  end
  return total
end

function canStoreOutput(output)
  return output and completedOutputCount() + (output.count or 1) <= self.outputCapacity
end

function addCompletedOutput(output)
  if not output then return end

  local count = output.count or 1
  local parameters = output.parameters or {}
  for _, stored in ipairs(storage.completedOutputs) do
    if stored.name == output.name and valuesEqual(stored.parameters or {}, parameters) then
      stored.count = (stored.count or 0) + count
      return
    end
  end

  table.insert(storage.completedOutputs, {
    name = output.name,
    count = count,
    parameters = parameters
  })
end

function bottleStoredOutputs()
  local bottledCount = completedOutputCount()
  if bottledCount <= 0 then return 0 end

  for _, output in ipairs(storage.completedOutputs) do
    world.spawnItem(output.name, object.position(), output.count or 1, output.parameters or {})
  end
  storage.completedOutputs = {}
  storage.capacityBlocked = false
  updateVisuals()
  return bottledCount
end

function canUsePower()
  return object.isInputNodeConnected(0) and power.get() >= self.powerUseAmount
end

function restartBrewingSound()
  -- Starbound can discard a distant looping sound without notifying the
  -- object.  Replacing it periodically lets the loop recover when a player
  -- returns, while ensuring only one instance exists at a time.
  animator.stopAllSounds("brewloop")
  animator.playSound("brewloop", -1)
  animator.setSoundVolume("brewloop", 4.0)
  self.isPlayingBrewingSound = true
  self.brewingSoundRestartTimer = 8.0
end

function updateVisuals()
  local visualState = storage.phase
  if storage.phase == "off" and storage.capacityBlocked then visualState = "done" end
  if storage.paused and isBrewing() then visualState = "off" end
  animator.setAnimationState("brewState", visualState)
  animator.setParticleEmitterActive("bubbles", isBrewing() and not storage.paused)

  local shouldPlayBrewingSound = isBrewing() and not storage.paused
  if shouldPlayBrewingSound and not self.isPlayingBrewingSound then
    restartBrewingSound()
  elseif not shouldPlayBrewingSound and self.isPlayingBrewingSound then
    animator.stopAllSounds("brewloop")
    self.isPlayingBrewingSound = false
    self.brewingSoundRestartTimer = nil
  end
end

function updateBrewingSound(dt)
  if not (isBrewing() and not storage.paused) then return end

  self.brewingSoundRestartTimer = (self.brewingSoundRestartTimer or 0) - dt
  if self.brewingSoundRestartTimer <= 0 then
    restartBrewingSound()
  end
end

function hasInputs(recipe)
  for _, input in ipairs(recipe.input or {}) do
    -- containerAvailable receives a descriptor that already includes count.
    -- It reports how many complete descriptors are available, so testing it
    -- against input.count would require count batches (e.g. 16 wheat).
    if world.containerAvailable(entity.id(), input) <= 0 then
      return false
    end
  end
  return true
end

function tryStartBatch()
  if storage.phase ~= "off" or not canUsePower() then return end

  storage.capacityBlocked = false
  for _, recipe in pairs(self.recipes) do
    if hasInputs(recipe) and canStoreOutput(recipe.output) then
      power.remove(self.powerUseAmount)
      for _, input in ipairs(recipe.input or {}) do
        world.containerConsume(entity.id(), input)
      end

      storage.pendingOutput = recipe.output
      storage.remainingTime = self.totalDuration
      storage.consumptionTimer = self.consumptionTime
      storage.paused = false
      storage.capacityBlocked = false
      storage.phase = "stage1"
      updateVisuals()
      return
    elseif hasInputs(recipe) then
      storage.capacityBlocked = true
    end
  end

  if storage.capacityBlocked then updateVisuals() end
end

function pauseBatch()
  if not storage.paused then
    storage.paused = true
    updateVisuals()
  end
end

function resumeBatch()
  if power.get() >= self.powerUseAmount then
    power.remove(self.powerUseAmount)
    storage.consumptionTimer = self.consumptionTime
    storage.paused = false
    updateVisuals()
  end
end

function finishBatch()
  addCompletedOutput(storage.pendingOutput)
  storage.pendingOutput = nil
  storage.remainingTime = 0
  storage.paused = false
  storage.capacityBlocked = false
  storage.phase = "off"
  updateVisuals()
end

function updateBrewing(dt)
  if not isBrewing() then return end

  -- A severed cable pauses immediately.  Do not use the transient power
  -- buffer value here: Arcana refills it in discrete network ticks.
  if not object.isInputNodeConnected(0) then
    pauseBatch()
    return
  end

  if storage.paused then
    resumeBatch()
    return
  end

  storage.consumptionTimer = math.max(0, storage.consumptionTimer - dt)
  if storage.consumptionTimer <= 0 then
    -- Check and pay power only once per consumption interval, matching the
    -- hydroponic tray's behaviour.  This prevents a full machine from
    -- flickering between its work frame and off while the network refills.
    if power.get() < self.powerUseAmount then
      pauseBatch()
      return
    end
    power.remove(self.powerUseAmount)
    storage.consumptionTimer = self.consumptionTime
  end

  storage.remainingTime = math.max(0, storage.remainingTime - dt)
  if storage.remainingTime == 0 then
    finishBatch()
    return
  end

  local phase = currentPhase()
  if phase ~= storage.phase then
    storage.phase = phase
    updateVisuals()
  end
end

function update(dt)
  updateBrewing(dt)
  updateBrewingSound(dt)
  if storage.phase == "off" then
    tryStartBatch()
  end
end
