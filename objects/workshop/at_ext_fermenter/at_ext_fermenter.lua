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

  storage.phase = storage.phase or "off"
  storage.remainingTime = storage.remainingTime or 0
  storage.consumptionTimer = storage.consumptionTimer or self.consumptionTime
  storage.pendingOutput = storage.pendingOutput or nil
  storage.paused = storage.paused or false

  power.set(0)
  object.setInteractive(true)
  animator.setGlobalTag("directives", config.getParameter("directives", ""))
  updateVisuals()

  message.setHandler("getProgress", function()
    if storage.phase == "off" then return 0 end
    if storage.phase == "done" then return 1 end
    return math.max(0, math.min(1, 1 - (storage.remainingTime / self.totalDuration)))
  end)

  -- Container objects always open their pane on interaction.  The pane calls
  -- this handler when it opens so a completed batch can be collected instead.
  message.setHandler("collectOutputIfDone", function()
    if storage.phase ~= "done" then return false end
    collectOutput()
    return true
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

  for _, recipe in pairs(self.recipes) do
    if hasInputs(recipe) then
      power.remove(self.powerUseAmount)
      for _, input in ipairs(recipe.input or {}) do
        world.containerConsume(entity.id(), input)
      end

      storage.pendingOutput = recipe.output
      storage.remainingTime = self.totalDuration
      storage.consumptionTimer = self.consumptionTime
      storage.paused = false
      storage.phase = "stage1"
      updateVisuals()
      return
    end
  end
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
  storage.remainingTime = 0
  storage.paused = false
  storage.phase = "done"
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

function collectOutput()
  local output = storage.pendingOutput
  if output then
    world.spawnItem(output.name, object.position(), output.count or 1, output.parameters or {})
  end

  storage.pendingOutput = nil
  storage.remainingTime = 0
  storage.phase = "off"
  storage.paused = false
  storage.consumptionTimer = self.consumptionTime
  updateVisuals()
end

function update(dt)
  updateBrewing(dt)
  updateBrewingSound(dt)
  if storage.phase == "off" then
    tryStartBatch()
  end
end
