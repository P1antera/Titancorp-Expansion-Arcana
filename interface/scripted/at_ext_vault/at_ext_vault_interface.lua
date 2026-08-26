require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"

local storageItem = "arcana_currency_credit" 
local playerAmount = 0
local vaultAmount = 0
local statusTimer = 0

function init()

  self.loadingElapsed = 0
  self.loadingDuration = config.getParameter("loadingDuration", 3.0)
  self.loadingFrames = config.getParameter("loadingFrames", 4)
  self.loadingBaseImage = config.getParameter("loadingBaseImage")
  widget.setVisible("imgLoadingOverlay", true)

  local itemEntityId = pane.sourceEntity()
  if itemEntityId then
    storageItem = "arcana_currency_credit"
  end
  

  updateAmounts()
  

  updateUI()
  
  widget.setText("amountInput", "")
end

function update(time)
  if self.loadingElapsed then
    self.loadingElapsed = self.loadingElapsed + time

    if self.loadingElapsed >= self.loadingDuration then
      self.loadingElapsed = nil
      widget.setVisible("imgLoadingOverlay", false)
    else
      local frameDuration = self.loadingDuration / self.loadingFrames
      local frame = math.min(math.floor(self.loadingElapsed / frameDuration), self.loadingFrames - 1)
      widget.setImage("imgLoadingOverlay", self.loadingBaseImage .. ":" .. frame)
    end
  end

  updateAmounts()
  updateUI()
  if statusTimer > 0 then
    statusTimer = statusTimer - time
    if statusTimer <= 0 then
      widget.setText("statusLabel", "")
    end
  end
end


function updateAmounts()

  playerAmount = player.hasCountOfItem({name = storageItem}, true) or 0
  vaultAmount = player.getProperty("storagevault_"..storageItem, 0)
end


function updateUI()
  widget.setText("playerAmount", "Inventory: "..playerAmount)
  widget.setText("vaultAmount", "Bank: "..vaultAmount)
  

  --widget.setImage("itemIcon", "/items/generic/crafting/"..storageItem..".png")
  

  local itemNameMap = {
    money = "信用点"
  }
  widget.setText("itemLabel", "^green;Credit^reset;")
end


function onDeposit()
  local amount = tonumber(widget.getText("amountInput")) or 0
  
  if amount <= 0 then
    showStatus("Not Valid Amount")
    return
  end
  
  if amount > playerAmount then
    showStatus("Insufficient Balance")
    return
  end
  


  player.consumeItem({name = storageItem, count = amount}, true, true)
  

  vaultAmount = vaultAmount + amount
  

  player.setProperty("storagevault_"..storageItem, vaultAmount)
  

  playerAmount = playerAmount - amount
  
  showStatus("Deposit Successful: "..amount)
  updateUI()

end


function onWithdraw()
  local amount = tonumber(widget.getText("amountInput")) or 0
  
  if amount <= 0 then
    showStatus("Not Valid Amount")
    return
  end
  
  if amount > vaultAmount then
    showStatus("Insufficient Balance")
    return
  end

  local MAX_STACK = 9999
  local remaining = amount
  while remaining > 0 do  
    local giveAmount = math.min(remaining, MAX_STACK)
    player.giveItem({name = storageItem, count = giveAmount})
    remaining = remaining - giveAmount
  end  

  vaultAmount = vaultAmount - amount
  

  player.setProperty("storagevault_"..storageItem, vaultAmount)

  playerAmount = playerAmount + amount

  showStatus("Withdrawal Successful: "..amount)
  updateUI()
end


function onClose()
  pane.dismiss()
end


function showStatus(message)
  widget.setText("statusLabel", message)
  statusTimer = 3.0  
end
