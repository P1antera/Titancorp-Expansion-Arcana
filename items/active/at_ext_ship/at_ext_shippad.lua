function init() activeItem.setHoldingItem(false)
end
function uninit()
end
function activate()
  animator.playSound("activate")
  activeItem.interact("scriptPane", "/interface/scripted/at_ext_shippad/at_ext_shippd.config")
end