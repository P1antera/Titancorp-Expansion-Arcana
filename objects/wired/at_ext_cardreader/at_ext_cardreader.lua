function init()
  self.requiredItem = config.getParameter("requiredItem")
  self.consumeItem = config.getParameter("consumeItem", false)
  -- 初始化
  if storage.locked == nil then
    storage.locked = true
    output(false)
  else
    output(not storage.locked)
  end

  object.setInteractive(true)
end


function onInteraction(args)
  local playerId = args.sourceId
  
  if storage.locked then
 local hasItem = world.entityHasCountOfItem(playerId, self.requiredItem) > 0

    if hasItem  then
      unlockAccess(playerId)
    else
      accessDenied()
    end
  else
    -- 已解锁状态再次交互的反馈
    animator.playSound("unlock")
  end
end

-- 解锁
function unlockAccess(playerId)

  storage.locked = false 
  -- 输出信号
  output(true)
  animator.playSound("unlock")
  
  -- object.setInteractive(false)
end

-- 拒绝
function accessDenied()
  animator.playSound("denied")
  -- animator.setAnimationState("indicator", "denied")
end


function output(unlocked)
  if unlocked then
    object.setAllOutputNodes(true)
    animator.setAnimationState("switchState", "on")
  else
    object.setAllOutputNodes(false)
    animator.setAnimationState("switchState", "off")
  end
end

function update(dt)

end

-- 重置函数
function resetLock()
  storage.locked = true
  output(false)
  object.setInteractive(true)
end