function init() activeItem.setHoldingItem(false)
end
function uninit()
end


function update(dt)
  if item.count() == 1 then
    item.consume(1)
  end  
end