require "/scripts/stagehandutil.lua"

function init()
  self.tracks = config.getParameter("tracks", {})
  self.fadeInTime = config.getParameter("fadeInTime", 2.0)
  self.startDelay = config.getParameter("startDelay", 2.0)
  self.retryInterval = config.getParameter("retryInterval", 2.0)
  self.maxPlayAttempts = config.getParameter("maxPlayAttempts", 2)
  self.teleportDistance = config.getParameter("teleportDistance", 120)
  self.teleportTimeWindow = config.getParameter("teleportTimeWindow", 3.0)
  self.propertyPrefix = config.getParameter("propertyPrefix", "at_ext_playAltMusic")
  self.rng = sb.makeRandomSource()
end

function update(dt)
  local playerStates = world.getProperty(playerStatesProperty(), {})
  local now = world.time()

  for _, playerId in pairs(broadcastAreaQuery({ includedTypes = {"player"} })) do
    local playerKey = getPlayerKey(playerId)
    local position = world.entityPosition(playerId)
    local playerState = playerStates[playerKey]

    if not playerState or not playerState.track then
      playerStates[playerKey] = newPlayerState(position, currentTrack(), now)
    elseif playerTeleported(playerState, position, now) then
      queuePlay(playerState, now)
      updatePlayerState(playerState, position, now)
    else
      updatePlayerState(playerState, position, now)
    end

    tryPlayMusic(playerId, playerStates[playerKey], now)
  end

  world.setProperty(playerStatesProperty(), playerStates)
end

function newPlayerState(position, track, now)
  return {
    position = position,
    track = track,
    lastSeen = now,
    nextPlayTime = now + self.startDelay,
    playAttempts = 0
  }
end

function updatePlayerState(playerState, position, now)
  playerState.position = position
  playerState.lastSeen = now
end

function queuePlay(playerState, now)
  playerState.nextPlayTime = now + self.startDelay
  playerState.playAttempts = 0
end

function currentTrack()
  local track = world.getProperty(trackProperty())
  if not track then
    track = selectTrack()
    world.setProperty(trackProperty(), track)
  end

  return track
end

function selectTrack()
  if #self.tracks == 0 then
    return nil
  end

  return self.tracks[self.rng:randInt(1, #self.tracks)]
end

function playerTeleported(playerState, newPosition, now)
  if not playerState.position or not newPosition or not playerState.lastSeen then
    return false
  end

  local recentlySeen = now - playerState.lastSeen <= self.teleportTimeWindow
  return recentlySeen and positionDistance(playerState.position, newPosition) >= self.teleportDistance
end

function positionDistance(a, b)
  local dx = b[1] - a[1]
  local dy = b[2] - a[2]
  return math.sqrt(dx * dx + dy * dy)
end

function getPlayerKey(playerId)
  return world.entityUniqueId(playerId) or tostring(playerId)
end

function trackProperty()
  return self.propertyPrefix .. ".track"
end

function playerStatesProperty()
  return self.propertyPrefix .. ".players"
end

function playMusic(playerId, track)
  if track then
    world.sendEntityMessage(playerId, "playAltMusic", {track}, self.fadeInTime)
  end
end

function tryPlayMusic(playerId, playerState, now)
  if not playerState.track or not playerState.nextPlayTime then
    return
  end

  if now >= playerState.nextPlayTime and (playerState.playAttempts or 0) < self.maxPlayAttempts then
    playMusic(playerId, playerState.track)
    playerState.playAttempts = (playerState.playAttempts or 0) + 1
    playerState.nextPlayTime = now + self.retryInterval
  end
end
