-- Wrapper around the vanilla generic quest script. The original behavior is kept
-- unless the administrator-only mission skipper marked this exact quest.
require "/quests/scripts/main.lua"

local originalInit = init
local originalUpdate = update

function init()
  if player.getProperty("at_ext_mission_skip_current") == config.getParameter("atExtSkipId") then
    quest.complete()
    self.atExtSkipped = true
    return
  end

  originalInit()
end

function update(dt)
  if not self.atExtSkipped then
    originalUpdate(dt)
  end
end
