function init()
  
 

end

function update(dt)


   md()


end


function md()

  if status.resource("health") <= status.resourceMax("health") * 0.5   then
     status.addEphemeralEffect("at_ext_teabag2md")
   else
     status.removeEphemeralEffect("at_ext_teabag2md")

   end

end

