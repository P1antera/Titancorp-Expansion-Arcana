require "/scripts/util.lua"

local function atExtMedicalInventory()
  if storage.atExtMedicalInventoryInitialized then
    return storage.atExtMedicalInventory
  end

  storage.atExtMedicalInventoryInitialized = true
  storage.atExtMedicalInventory = {}

  for _, item in ipairs(config.getParameter("atExtMedicalItems", {})) do
    if type(item) == "string" then
      table.insert(storage.atExtMedicalInventory, {item = item, count = 1})
    elseif type(item) == "table" and item.item then
      table.insert(storage.atExtMedicalInventory, {
        item = item.item,
        count = item.count or 1
      })
    end
  end

  return storage.atExtMedicalInventory
end

local function atExtItemConfig(itemName)
  local ok, itemConfig = pcall(root.itemConfig, itemName)
  if ok and itemConfig then
    return itemConfig.config or {}
  end

  return nil
end

local function atExtActiveEffectNames()
  local effects = {}

  for _, effect in ipairs(status.activeUniqueStatusEffectSummary() or {}) do
    if effect[1] and effect[1] ~= "" then
      effects[effect[1]] = true
    end
  end

  return effects
end

local function atExtHasBlockingEffect(itemConfig)
  local activeEffects = atExtActiveEffectNames()

  for _, effectName in ipairs(itemConfig.blockingEffects or {}) do
    if activeEffects[effectName] then
      return true
    end
  end

  return false
end

local function atExtItemDescriptor(itemName)
  return {
    name = itemName,
    parameters = {
      level = npc.level()
    }
  }
end

local function atExtVisualItemName(item)
  if item.visualItem then
    return item.visualItem
  end

  if item.item:sub(1, 11) == "at_ext_npc_" then
    return item.item
  end

  local visualItem = "at_ext_npc_" .. item.item
  local ok = pcall(root.itemConfig, visualItem)
  if ok then
    return visualItem
  end

  return item.item
end

local function atExtApplyConsumableEffects(itemConfig)
  local effectGroup = itemConfig.effects and itemConfig.effects[1]
  if not effectGroup then return false end

  for _, effect in ipairs(effectGroup) do
    if type(effect) == "string" then
      status.addEphemeralEffect(effect)
    elseif type(effect) == "table" and effect.effect then
      status.addEphemeralEffect(effect.effect, effect.duration)
    end
  end

  return true
end

local function atExtUseMedicalItemVisually(item, itemConfig, useTime)
  local oldPrimary = self.primary

  setNpcItemSlot("primary", atExtItemDescriptor(atExtVisualItemName(item)))
  self.primaryFire = false
  npc.endPrimaryFire()

  local elapsed = 0
  local dt = script.updateDt()

  while elapsed < useTime do
    self.primaryFire = true
    dt = coroutine.yield()
    elapsed = elapsed + (dt or script.updateDt())
  end

  self.primaryFire = false
  npc.endPrimaryFire()
  setNpcItemSlot("primary", oldPrimary)

  if not atExtHasBlockingEffect(itemConfig) then
    atExtApplyConsumableEffects(itemConfig)
  end
end

function atExtUseMedicalItem(args, board, nodeId)
  local healthThreshold = args.healthThreshold or 0.5
  if status.resourcePercentage("health") > healthThreshold then
    return true
  end

  local now = world.time()
  local cooldownKey = "atExtMedicalCooldown-" .. nodeId
  if now < (board:getNumber(cooldownKey) or 0) then
    return true
  end

  local requiredCategory = args.category or "medicine"
  local inventory = atExtMedicalInventory()

  for _, item in ipairs(inventory) do
    if item.count and item.count > 0 then
      local itemConfig = atExtItemConfig(item.item)

      if itemConfig and itemConfig.category == requiredCategory and not atExtHasBlockingEffect(itemConfig) then
        item.count = item.count - 1
        board:setNumber(cooldownKey, now + (args.cooldown or 10))
        atExtUseMedicalItemVisually(item, itemConfig, args.visualUseTime or 0.6)
        return true
      end
    end
  end

  return true
end
