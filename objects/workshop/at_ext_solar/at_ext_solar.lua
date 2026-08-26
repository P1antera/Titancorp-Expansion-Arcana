--https://stackoverflow.com/questions/9168058/how-to-dump-a-table-to-console
require "/scripts/automation/arcana_power.lua"

pInit = init

function init()
  if pInit then pInit() end
  self.maxPower = config.getParameter("maxPower", 10)
  self.isPowered = false
  self.isPlayingSound = false
  animator.setGlobalTag("directives", config.getParameter("directives", ""))
end


function uninit()

end



function daycheck()
local day = world.timeOfDay()
    
	if day <= 0.5 and world.underground(object.position()) == false then
	  self.isPowered = true   
	  return
	end
  
  self.isPowered = false
end

function update(dt)

	  daycheck()
	  if self.isPowered == true then
	    object.setOutputNodeLevel(0, true)
		animator.setAnimationState("switchState", "on")
		power.set(self.maxPower)
		  if self.isPlayingSound == false then
		     animator.playSound("onloop", -1)
		     self.isPlayingSound = true
		  end
	    
	  else
	    object.setOutputNodeLevel(0, false)
		animator.setAnimationState("switchState", "off")	
		animator.stopAllSounds("onloop")
		self.isPlayingSound = false
		power.set(0)
	  end 
    power.send(0, power.get())
	  
end

function tablelength(table)
  local count = 0
  for _ in pairs(table) do count = count + 1 end
  return count
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
      return tostring(o) or "NIL"
   end
end