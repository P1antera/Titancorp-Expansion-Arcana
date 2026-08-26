require "/scripts/util.lua"
-- by Plantera  定时抽奖机脚本

function init()
  object.setInteractive(true)
  local playerId = entity.id()
  self.playerUUID = world.entityUniqueId(playerId) or "global"
  self.cooldown = config.getParameter("rotationTime")  
 

    self.lastInteractionTime = world.getProperty("supply_cooldown:"..self.playerUUID) or 0
  self.state = "idle"
  self.saveTimer = 0


end



function onInteraction(args)
  local sourceId = args.sourceId
  local playerUUID = world.entityUniqueId(sourceId) or "unknown"
  local playerCooldown = world.getProperty("supply_cooldown:"..playerUUID) or 0

  local currentTime = os.time()
  

  if currentTime - playerCooldown  < self.cooldown then
    local remaining = self.cooldown - (currentTime - playerCooldown)
    local hours = math.floor(remaining / 3600)
    local minutes = math.floor((remaining % 3600) / 60)
    local seconds = math.floor(remaining % 60)
    

    object.say(string.format("^red;Supply not ready^reset;\nAvailable in^green; %d hours %d minutes\n%dseconds^reset;", hours, minutes, seconds))
   animator.playSound("supplydenied")
   animator.setAnimationState("terminalState", "notready")    
    --self.state = "notready"
    return nil
  end
  

  world.setProperty("supply_cooldown:"..playerUUID, currentTime)
  

  local inventoryPool = config.getParameter("inventoryPool")
  

  math.randomseed(util.seedTime())
  local selectedItems = selectRandomItems(inventoryPool, 2)
  

  spawnItems(selectedItems, object.position())
  object.say(string.format("^green;Supplies are being distributed...^reset;"))
   animator.playSound("supplygranted")
   animator.setAnimationState("terminalState", "releasing")   
 -- self.state = "releasing"
  return nil
end

function update(dt)

end


function selectRandomItems(pool, count)
  local selected = {}
  local tempPool = deepCopy(pool)  
  

  shuffle(tempPool)
  

  for i = 1, math.min(count, #tempPool) do
    table.insert(selected, tempPool[i])
  end
  
  return selected
end


function spawnItems(items, position)
  for _, item in ipairs(items) do
    if type(item) == "table" then

      world.spawnItem(item.name, position, item.count or 1, item.parameters or {})
    else

      world.spawnItem(item, position, 1)
    end
  end
end


function shuffle(list)
  for i = #list, 2, -1 do
    local j = math.random(i)
    list[i], list[j] = list[j], list[i]
  end
end

function deepCopy(original)
  if type(original) ~= "table" then
    return original
  end
  
  local copy = {}
  for k, v in pairs(original) do
    if type(v) == "table" then
      copy[k] = deepCopy(v)  
    else
      copy[k] = v
    end
  end
  return copy
end



