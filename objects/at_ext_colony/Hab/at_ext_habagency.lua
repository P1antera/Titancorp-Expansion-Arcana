function init()
  self.chatOptions = config.getParameter("chatOptions", {})
  self.chatTimer = 0
  self.flag = true
end

function update(dt)
  self.chatTimer = math.max(0, self.chatTimer - dt)
  if self.chatTimer == 0 then
    local players = world.entityQuery(object.position(), config.getParameter("chatRadius"), {
      includedTypes = {"player"},
      boundMode = "CollisionArea"
    })

    if #players > 0 and #self.chatOptions > 0 then
      if self.flag then
        object.say(self.chatOptions[1])
        self.flag = false
        self.chatTimer = config.getParameter("chatCooldown")
      else
        object.say(self.chatOptions[2])
        self.flag = true    
        self.chatTimer = config.getParameter("chatCooldown")  
      end
    end
  end

end

