function update()
  localAnimator.clearDrawables()

  teleportUnviable, teleportViable, teleportCooldown = 1, 2, 3

  local teleportState = animationConfig.animationParameter("teleportState")

  if (teleportState == teleportCooldown) then
    return {}
  else
    local teleportPreviewImage = animationConfig.animationParameter("teleportPreviewImage")
	if animationConfig.animationParameter("crouching") then
		teleportPreviewImage = animationConfig.animationParameter("teleportCrouchingPreviewImage")
	end
	
    local spawnPosition = activeItemAnimation.ownerAimPosition()

    local highlightColor = teleportState == teleportViable and {50, 200, 200, 96} or {255, 150, 150, 128}

	if teleportState == teleportViable or teleportState == teleportUnviable then
    localAnimator.addDrawable({
      image = teleportPreviewImage,
      position = spawnPosition,
      color = highlightColor,
      fullbright = true
    })
	
	localAnimator.addDrawable({
      image = animationConfig.animationParameter("teleportLimitOutlineImage"),
      position = activeItemAnimation.ownerPosition(),
      color = highlightColor,
      fullbright = true
    })
	end
  end
end
