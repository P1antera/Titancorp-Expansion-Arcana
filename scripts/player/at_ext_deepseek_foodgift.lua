local cooldownProperty = "at_ext_deepseekFoodGiftNextAt"
local claimProperty = "at_ext_deepseekFoodGiftClaim"

function init()
  self.foodGift = root.assetJson("/monsters/at_ext_deepseek/foodgift.config")
  message.setHandler("at_ext_deepseek.foodGift", function(_, _, sourceId, requestId)
    if type(requestId) ~= "string" or world.monsterType(sourceId) ~= "at_ext_deepseek" then
      return false
    end
    local sourcePosition = world.entityPosition(sourceId)
    local playerPosition = mcontroller.position()
    if not sourcePosition or world.magnitude(playerPosition, sourcePosition) > self.foodGift.range then
      return false
    end
    local sourceMouth = world.entityMouthPosition(sourceId) or sourcePosition
    local playerMouth = world.entityMouthPosition(player.id()) or playerPosition
    if world.lineTileCollision(sourceMouth, playerMouth, {"Null", "Block", "Dynamic", "Slippery"}) then
      return false
    end

    -- Real time and a player property survive instance recreation and save/reload.
    local now = os.time()
    if now < player.getProperty(cooldownProperty, 0) then
      return false
    end
    -- Reserve before replying so another monster cannot grant a second gift.
    player.setProperty(claimProperty, {
      requestId = requestId,
      previousNextAt = player.getProperty(cooldownProperty, 0),
      nextAt = now + self.foodGift.cooldown
    })
    player.setProperty(cooldownProperty, now + self.foodGift.cooldown)
    return true
  end)
  message.setHandler("at_ext_deepseek.cancelFoodGift", function(_, _, requestId)
    local claim = player.getProperty(claimProperty)
    if claim and claim.requestId == requestId
        and player.getProperty(cooldownProperty, 0) == claim.nextAt then
      player.setProperty(cooldownProperty, claim.previousNextAt)
      player.setProperty(claimProperty, nil)
    end
  end)
end
