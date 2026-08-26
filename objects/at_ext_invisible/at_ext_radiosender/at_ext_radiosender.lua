function init()
end

function update(dt)
  if object.getInputNodeLevel(0)  then
      radiosend()
	end
end

function radiosend()
  local players = world.playerQuery(object.position(), config.getParameter("range"), {})
	local radioMessage = config.getParameter("radioMessage")
	for i in ipairs(players) do
    world.sendEntityMessage(players[i], "queueRadioMessage", radioMessage)
  end
end
