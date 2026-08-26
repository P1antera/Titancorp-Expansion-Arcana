function init()
  math.randomseed(os.time())
end

function update(dt)
  if object.getInputNodeLevel(0)  then
      radiosend()
	end
end

function radiosend()
  local players = world.playerQuery(object.position(), config.getParameter("range"), {})
	local radioMessages = config.getParameter("radioMessages")

  local randomIndex = math.random(1, #radioMessages)
  local selectedMessage = radioMessages[randomIndex]
	for i = 1 , #players do
    world.sendEntityMessage(players[i], "queueRadioMessage", selectedMessage)
    world.breakObject(entity.id(), true)
  end
end
