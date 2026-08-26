require "/scripts/util.lua"

function init()
  object.setInteractive(true)
  self.tag = "weapon"
  self.tag2 = "reagent"
  

  self.lastRefreshTime = storage.lastRefreshTime or 0
  self.storedRecipes = storage.storedRecipes or {}
  

  local currentTime = os.time()
  local refreshInterval = 10800
  
  if currentTime - self.lastRefreshTime >= refreshInterval or #self.storedRecipes == 0 then

    self.lastRefreshTime = currentTime
    local costPool = config.getParameter("costPool", {})
    local inventoryPool = config.getParameter("inventoryPool", {})
    local specialPool = config.getParameter("specialPool", {})
    self.storedRecipes = generateRecipes(costPool, inventoryPool, specialPool)
    

    storage.lastRefreshTime = self.lastRefreshTime
    storage.storedRecipes = self.storedRecipes
  end
end

function onInteraction(args)
  local interactData = config.getParameter("interactData")
  

  local currentTime = os.time()
  local refreshInterval = 10800 
  
  if currentTime - self.lastRefreshTime >= refreshInterval or #self.storedRecipes == 0 then

    self.lastRefreshTime = currentTime
    local costPool = config.getParameter("costPool", {})
    local inventoryPool = config.getParameter("inventoryPool", {})
    local specialPool = config.getParameter("specialPool", {})
    self.storedRecipes = generateRecipes(costPool, inventoryPool, specialPool)
    

    storage.lastRefreshTime = self.lastRefreshTime
    storage.storedRecipes = self.storedRecipes
  end
  

  interactData.recipes = jarray()
  for _, recipe in ipairs(self.storedRecipes) do
    table.insert(interactData.recipes, recipe)
  end

  return { "OpenCraftingInterface", interactData }
end

function generateRecipes(costPool, inventoryPool, specialPool)
  local recipes = {}

  local shuffleSeed = math.floor(self.lastRefreshTime / 10800)
  math.randomseed(shuffleSeed)
  

  local combinedPool = {}
  for _, item in ipairs(inventoryPool) do
    table.insert(combinedPool, {item = item, type = "normal"})
  end
  

  for _, item in ipairs(costPool) do
    table.insert(combinedPool, {item = item, type = "special"})
  end
  

  shuffle(combinedPool)
  

  for i = 1, config.getParameter("selectCount", 1) do
    if not combinedPool[i] then break end


    local itemSeed = shuffleSeed + i
    math.randomseed(itemSeed)
    
    local itemName = combinedPool[i].item
    local itemType = combinedPool[i].type
    
    local itemConfig = root.itemConfig(itemName)
    local isWeapon = false
    local isReagent = false
    local isSpecial = (itemType == "special")
    
    if itemConfig and itemConfig.config then
      local tags = itemConfig.config.itemTags or {}
      for _, tag in ipairs(tags) do
        if tag == self.tag then
          isWeapon = true
          break
        elseif tag == self.tag2 then
          isReagent = true
          break
        end
      end
    end  

    local outputCount
    if isWeapon then
      outputCount = 1 
    elseif isReagent then
      outputCount = math.random(2, 4) 
    else
      outputCount = math.random(5, 10) 
    end
    
    local recipe = {
      input = {},
      output = {item = itemName, count = outputCount},
      groups = {"all"}
    }
    
    if isSpecial then
      -- 特殊交易
      recipe.output.count = math.random(25, 35) 
      
      if #specialPool > 0 then
        local costItem = specialPool[math.random(1, #specialPool)] 
        local costCount = math.random(4, 6) 
        table.insert(recipe.input, {item = costItem, count = costCount})
      end
    else
      -- 普通交易
      if #costPool > 0 then
        local costItems = {}
        local costCount = 0
        
        if isWeapon then

          local selectedItems = {}
          for j = 1, 3 do
            local costItem
            repeat
              costItem = costPool[math.random(1, #costPool)]
            until not selectedItems[costItem] 
            
            selectedItems[costItem] = true
            costCount = math.random(10, 20) 
            table.insert(costItems, {item = costItem, count = costCount})
          end
        elseif isReagent then

          local selectedItems = {}
          for j = 1, 3 do
            local costItem
            repeat
              costItem = costPool[math.random(1, #costPool)]
            until not selectedItems[costItem] 
            
            selectedItems[costItem] = true
            costCount = math.random(10, 20) 
            table.insert(costItems, {item = costItem, count = costCount})
          end
        else

          local costItem = costPool[math.random(1, #costPool)]
          costCount = math.random(20, 30) 
          table.insert(costItems, {item = costItem, count = costCount})
        end
        
        for _, cost in ipairs(costItems) do
          table.insert(recipe.input, cost)
        end
      end
    end
    
    table.insert(recipes, recipe)
  end
  

  math.randomseed(util.seedTime())
  
  return recipes
end

function shuffle(list)

  for i = 1, #list do
    local swapIndex = math.random(1, #list)
    list[i], list[swapIndex] = list[swapIndex], list[i]
  end
end