function init() activeItem.setHoldingItem(false)
end
function uninit()
end
function activate()
  animator.playSound("activate")
  activeItem.interact("scriptPane", "/interface/scripted/at_ext/at_ext_manual_Cn.config")
end