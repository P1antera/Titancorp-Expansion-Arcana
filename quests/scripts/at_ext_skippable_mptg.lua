-- Wrapper around at_ext's multi-target instance quest script. See at_ext_skippable_main.lua.
require "/quests/scripts/at_ext_mptg.lua"

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
