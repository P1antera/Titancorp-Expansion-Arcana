local function randomSteamDelay()
  return 1.2 + math.random() * 1.6
end

function init()
  self.steamEmitter = config.getParameter("steamEmitter", "steam")
  self.steamTimer = math.random() * 2.0
  animator.setParticleEmitterActive(self.steamEmitter, false)
end

function update(dt)
  self.steamTimer = self.steamTimer - dt
  if self.steamTimer <= 0 then
    animator.burstParticleEmitter(self.steamEmitter)
    self.steamTimer = randomSteamDelay()
  end
end
