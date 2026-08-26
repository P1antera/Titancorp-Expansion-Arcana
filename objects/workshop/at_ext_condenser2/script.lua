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
  self.isPowered = false
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

function automation()
 if self.isPowered == false then return end
  local powered = true
 local lastItem = world.containerItemAt(entity.id(), world.containerSize(entity.id()) - 1)
 
 
  local resource = nil

--Query the planet type
	  if self.resources ~= nil then
	  --arcane water
    if world.type() == "arcana_arcaneForest" or world.type() == "arcana_arcaneDesert" or world.type() == "arcana_arcaneTundra" or world.type() == "arcana_arcaneSea"
	then resource = self.resources.arcana_liquid_arcaneWater
      --illuminatedWater
	elseif world.type() == "arcana_illuminated" or world.type() == "arcana_ardentTaiga"
	then resource = self.resources.arcana_liquid_illuminatedWater
      --ruinousWater
	elseif world.type() == "arcana_desolate" or world.type() == "arcana_sanguine" or world.type() == "arcana_ferocious" or world.type() == "arcana_ruinous"
	  then resource = self.resources.arcana_liquid_ruinousWater
     --arcana_liquid_viridescentAcid
	 elseif world.type() == "arcana_viridescent" or world.type() == "arcana_automated"
	 then resource = self.resources.arcana_liquid_viridescentAcid
	 --arcana_liquid_neonWater
	  elseif world.type() == "arcana_superstormExpanse" or world.type() == "arcana_neonSea"
	 then resource = self.resources.arcana_liquid_neonWater
	 
	else resource = self.resources.water
    end
  else powered = false
  end
	
	
	
	
	
	
  if powered then
	if not lastItem or lastItem.name == resource.name then
	  world.containerPutItemsAt(entity.id(), resource, world.containerSize(entity.id()) - 1)
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
	  output(true)
	  self.cooldownTimer = self.craftingTime
    end
  end
end
