-- OpenStarbound administrator entry point:
-- /run player.setProperty("at_ext_mission_skip_request", true)
--
-- This is a generic player script so that player.* APIs are available. Status
-- effect scripts do not have access to that API on OpenStarbound.

local requestProperty = "at_ext_mission_skip_request"
local stateProperty = "at_ext_mission_skip_state"
local currentQuestProperty = "at_ext_mission_skip_current"

local missionSequence = {
  "at_ext_shippad",
  "at_ext_pre",
  "at_ext_d1",
  "at_ext_d2",
  "at_ext_d3",
  "at_ext_d4",
  "at_ext_d5",
  "at_ext_d6",
  "at_ext_d7",
  "at_ext_d9",
  "at_ext_d8",
  "at_ext_d10",
  "at_ext_d11"
}

local function notify(messageId)
  player.radioMessage(messageId)
end

local function clearCurrentQuestMarker(currentQuest)
  if currentQuest and player.getProperty(currentQuestProperty) == currentQuest then
    player.setProperty(currentQuestProperty, nil)
  end
end

local function stop(state, messageId)
  clearCurrentQuestMarker(state and state.current)
  player.setProperty(stateProperty, nil)
  if messageId then
    notify(messageId)
  end
end

local function startRequestedSkip()
  local existingState = player.getProperty(stateProperty)
  if existingState then
    -- A previous run is already in progress or waiting to resume.
    return
  end

  if not player.isAdmin() then
    notify("at_ext_mission_skip_admin_only")
    return
  end

  -- Only perform this guard for a new run. A resumed run can legitimately have
  -- its own current quest active while it waits for the wrapper to complete it.
  for _, questId in ipairs(missionSequence) do
    if player.hasActiveQuest(questId) then
      notify("at_ext_mission_skip_active_quest")
      return
    end
  end

  player.setProperty(stateProperty, {index = 1, waitTime = 0})
  notify("at_ext_mission_skip_started")
end

function init()
  script.setUpdateDelta(1)
end

function update(dt)
  if player.getProperty(requestProperty, false) then
    player.setProperty(requestProperty, nil)
    startRequestedSkip()
  end

  local state = player.getProperty(stateProperty)
  if not state then
    return
  end

  local questId = missionSequence[state.index]
  if not questId then
    clearCurrentQuestMarker(state.current)
    player.setProperty(stateProperty, nil)
    notify("at_ext_mission_skip_complete")
    return
  end

  if state.current then
    if player.hasCompletedQuest(state.current) then
      clearCurrentQuestMarker(state.current)
      state.index = state.index + 1
      state.current = nil
      state.waitTime = 0
      player.setProperty(stateProperty, state)
      return
    end

    state.waitTime = (state.waitTime or 0) + dt
    if state.waitTime >= 5 then
      stop(state, "at_ext_mission_skip_failed")
    else
      player.setProperty(stateProperty, state)
    end
    return
  end

  if player.hasCompletedQuest(questId) then
    state.index = state.index + 1
    player.setProperty(stateProperty, state)
    return
  end

  state.current = questId
  state.waitTime = 0
  player.setProperty(currentQuestProperty, questId)
  player.setProperty(stateProperty, state)
  player.startQuest(questId)
end
