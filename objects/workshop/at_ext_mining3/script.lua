--http://lua-users.org/wiki/SimpleRound
require "/scripts/automation/arcana_power.lua"

pInit = init
function init()
  if pInit then pInit() end
  self.consumptionTime = config.getParameter("consumptionTime", 1)
  self.consumptionTimer = self.consumptionTime
  self.craftingTime = config.getParameter("craftingTime", 1.0)
  self.cooldownTimer = self.craftingTime
  self.outputRate = config.getParameter("outputRate", 10)
  self.resources = config.getParameter("resources", nil)
  self.powerUseAmount = config.getParameter("powerUseAmount", 0)
  power.set(config.getParameter("maxPower", 10))
  animator.setGlobalTag("directives", config.getParameter("directives", ""))
  
  self.isPowered = true
  message.setHandler("getProgress", function()
    local progress = power.round((1 - (self.cooldownTimer / self.craftingTime)), 1)
	--if self.isPowered == true then sb.logInfo("Powered On: " .. tostring(progress)) else sb.logInfo("Powered Off: " .. tostring(progress)) end
    if self.isPowered == true then return progress else return 0 end
  end)
end

function uninit()

end

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function tablelength(table)
  local count = 0
  for _ in pairs(table) do count = count + 1 end
  return count
end

function output(state)
  local entityTable = object.getOutputNodeIds(0)
  local itemTable = world.containerItems(entity.id())
  local invertedItemTable = {}
  local adjustedRate = 0
  
  for k, v in pairs(itemTable) do 
  if object.isOutputNodeConnected(0) and tablelength(entityTable) >= 1 and tablelength(itemTable) > 0 then
    adjustedRate = math.ceil(self.outputRate / tablelength(entityTable))
    local item = world.containerItemAt(entity.id(), k - 1)
	for key, value in pairs(entityTable) do
	  if world.containerSize(key) == nil then return end
	  if world.containerItemsFitWhere(key, item)["leftover"] ~= 0 then return end
	  local isAssembler = (world.containerSize(key) < 9)

	  if isAssembler and world.containerItemsFitWhere(key, item)["slots"][1] == world.containerSize(key) - 1 then return end
	  item = world.containerTakeNumItemsAt(entity.id(), k - 1, adjustedRate)
	  world.containerAddItems(key, item)
	end
  end
  return
  end
end


function automation()
  
  if self.isPowered == false then return end
  local powered = true
  local commonf = false
  local newf = false
  local superstormcommonf = false
  local lastItem = world.containerItemAt(entity.id(), world.containerSize(entity.id()) - 1)
  
   local resource = nil
   local resource2 = nil
   local resource3 = nil
  
--Query the planet type
	  if self.resources ~= nil then
	  
	  --arcane
    if world.type() == "arcana_arcaneForest" or world.type() == "arcana_arcaneDesert" 
	then resource = self.resources.arcane	
	elseif world.type() == "arcana_arcaneSea"
	then resource = self.resources.arcane2
	elseif world.type() == "arcana_arcaneTundra"
	then resource = self.resources.arcane3
	
      --illuminated	  
	elseif world.type() == "arcana_illuminated"
	then resource = self.resources.illuminated
	elseif world.type() == "arcana_desolate"
	then resource = self.resources.illuminated2
	elseif world.type() == "arcana_evoaquatic"
	then resource = self.resources.illuminated3
	elseif world.type() == "arcana_animus"
	then resource = self.resources.illuminated4

    --superstorm
	elseif world.type() == "arcana_superstormExpanse" or world.type() == "arcana_neonSea"
	then 
	superstormcommonf = true
	resource = self.resources.superstorm
	resource2 = self.resources.superstormcommon
	elseif world.type() == "arcana_stahlernBadlands"
	then 
	superstormcommonf = true
	resource2 = self.resources.superstormcommon
	resource = self.resources.superstorm3
	elseif world.type() == "arcana_timeless" or world.type() == "arcana_automated"
	then 
	superstormcommonf = true
	resource2 = self.resources.superstormcommon
	resource = self.resources.superstorm2
	elseif world.type() == "arcana_viridescent"
	then 
	superstormcommonf = true
	resource2 = self.resources.superstormcommon	
	resource = self.resources.superstorm4
	
	--vanilla
	elseif world.type() == "forest" or world.type() == "desert" 
	then resource = self.resources.tungstenore
	elseif world.type() == "moon"
	then resource = self.resources.moon
	elseif world.type() == "savannah" or world.type() == "alien" or world.type() == "snow"
	then resource = self.resources.titaniumore
	elseif world.type() == "toxic" or world.type() == "alien" or world.type() == "jungle"
	then resource = self.resources.durasteelbar
	elseif world.type() == "arctic" or world.type() == "tundra" or world.type() == "midnight"
	then 
	newf = true
	resource = self.resources.aegisaltore
	resource2 = self.resources.feroziumore
	resource3 = self.resources.violiumore
	elseif world.type() == "volcanic" or world.type() == "scorchedcity" or world.type() == "magma"
	then resource = self.resources.solariumore
	

	 
	else 
	resource = self.resources.common
	resource2 = self.resources.common2
	resource3 = self.resources.common3
	commonf = true
    end
  else powered = false
  end



if  newf then
    if powered and world.terrestrial() then
	
	 animator.setAnimationState("switchState", "on")
	  world.containerAddItems(entity.id(), resource)
	  world.containerAddItems(entity.id(), resource2)
	  world.containerAddItems(entity.id(), resource3)
      return
	else
	animator.setAnimationState("switchState", "off")
	  return
  end
  
end





--For Arcana planets
if  commonf then
    if powered and world.terrestrial() then
	
	 animator.setAnimationState("switchState", "on")
	  world.containerAddItems(entity.id(), resource)
	  world.containerAddItems(entity.id(), resource2)
	  world.containerAddItems(entity.id(), resource3)
      return
	else
	animator.setAnimationState("switchState", "off")
	  return
  end
  
end

--For superstorm
if  superstormcommonf then
    if powered and world.terrestrial() then
	
	 animator.setAnimationState("switchState", "on")
	  world.containerAddItems(entity.id(), resource)
	  world.containerAddItems(entity.id(), resource2)
      return
	else
	animator.setAnimationState("switchState", "off")
	  return
  end
  
end







	
  if powered then
	if not lastItem or lastItem.name == resource.name then
	
	  world.containerAddItems(entity.id(), resource)
	
	else
	  animator.setAnimationState("switchState", "off")
	  return
	end
	  
	animator.setAnimationState("switchState", "on")
  else
    animator.setAnimationState("switchState", "off")
  end
  
end

function powerCheck()
  if power.get() >= self.powerUseAmount then 
    power.remove(self.powerUseAmount)
    self.isPowered = true
  else
    animator.setAnimationState("switchState", "off")
    self.isPowered = false
	return
  end
end

function update(dt)
  output(true)
  if self.consumptionTimer > 0 then
    self.consumptionTimer = math.max(0, self.consumptionTimer - dt)
    if self.consumptionTimer == 0 then
      powerCheck()
	  self.consumptionTimer = self.consumptionTime
    end
  end
  if self.cooldownTimer > 0 then
    self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
    if self.cooldownTimer == 0 then
      automation()
	  
	  self.cooldownTimer = self.craftingTime
    end
  end
end