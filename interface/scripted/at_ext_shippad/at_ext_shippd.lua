require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"

function init()
  self.loadingElapsed = 0
  self.loadingDuration = config.getParameter("loadingDuration", config.getParameter("minLoadTime", 0.5))
  self.loadingFrames = config.getParameter("loadingFrames", 4)
  self.loadingBaseImage = config.getParameter("loadingBaseImage")

  widget.setVisible("imgLoadingOverlay", true)
end

function update(dt)
  if self.loadingElapsed then
    self.loadingElapsed = self.loadingElapsed + dt

    if self.loadingElapsed >= self.loadingDuration then
      self.loadingElapsed = nil
      widget.setVisible("imgLoadingOverlay", false)
    else
      local frameDuration = self.loadingDuration / self.loadingFrames
      local frame = math.min(math.floor(self.loadingElapsed / frameDuration), self.loadingFrames - 1)
      widget.setImage("imgLoadingOverlay", self.loadingBaseImage .. ":" .. frame)
    end
  end
end

function teleport()
  self.destinationName = widget.getSelectedData("destinationTabs")
  if (self.destinationName) then
	player.warp(string.format("instanceWorld:%s", self.destinationName), "beam")
	pane.dismiss()
  end
end

function setDestinationImage()
  self.destinationName = widget.getSelectedData("destinationTabs")
  if (self.destinationName) then
   widget.setImage("destinationImage", string.format("/interface/scripted/at_ext_shippad/%s.png", self.destinationName))
  end
end
