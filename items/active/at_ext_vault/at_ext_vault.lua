function init()
  script.setUpdateDelta(0)
  self.storageItem = "arcana_currency_credit" 
end

function activate(fireMode, shiftHeld)
  if fireMode == "primary" or fireMode == "alt" then
    animator.playSound("activate")
    activeItem.interact("ScriptPane", "/interface/scripted/at_ext_vault/at_ext_vault_interface.config")
  end
end