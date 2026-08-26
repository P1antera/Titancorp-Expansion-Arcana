function init()
  self.targetzone = config.getParameter("targetzone")
end

function update(dt)
  if object.getInputNodeLevel(0)  then
      activate()
	end
end

function activate()
  world.setTileProtection(self.targetzone, false)
end
