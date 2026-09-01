require "/scripts/util.lua"

function init()
  local configPath = config.getParameter("configPath", "/objects/workshop/at_ext_growth/config.config")
  self.config = root.assetJson(configPath)
  self.recipes = self.config.recipes
  self.descriptionLabel = "lblText"
  self.rateLabel = "lbltxt"
  self.inputWidget = "scrollArea.inputList"
  self.progressWidget = "progress"
  self.entity = pane.containerEntityId()

  populateFields()
  populateList()
end

function update(dt)
  if not self.promise then
    self.promise = world.sendEntityMessage(self.entity, "getProgress")
  end

  if self.promise:succeeded() and self.promise:finished() then
    widget.setProgress(self.progressWidget, self.promise:result())
    self.promise = nil
  end
end

function tablelength(table)
  local count = 0
  for _ in pairs(table) do count = count + 1 end
  return count
end

function populateFields()
  widget.setText(self.rateLabel, string.format("^yellow;Growth time: %ss", tostring(self.config.craftingTime or 1)))
  widget.setText(self.descriptionLabel, self.config.description or "Autofilled")
end

function populateList()
  widget.clearListItems(self.inputWidget)

  for _, recipe in pairs(self.recipes) do
    local entry = widget.addListItem(self.inputWidget)
    local inputList = string.format("%s.%s.input", self.inputWidget, entry)
    local outputConfig = root.itemConfig(recipe.output)
    local outputImage = util.absolutePath(outputConfig.directory, outputConfig.config.inventoryIcon)
    local outputText = string.format("^white;%s %s^reset;", recipe.output.count, outputConfig.config.shortdescription)

    widget.setText(string.format("%s.%s.text", self.inputWidget, entry), outputText)
    widget.setImage(string.format("%s.%s.item", self.inputWidget, entry), outputImage)

    for index = 1, tablelength(recipe.input) do
      local inputEntry = widget.addListItem(inputList)
      local input = recipe.input[index]
      local inputConfig = root.itemConfig(input)
      local inputImage = util.absolutePath(inputConfig.directory, inputConfig.config.inventoryIcon)
      local inputText = string.format("^white;%s %s^reset;", input.count, inputConfig.config.shortdescription)

      widget.setText(string.format("%s.%s.input.%s.text", self.inputWidget, entry, inputEntry), inputText)
      widget.setImage(string.format("%s.%s.input.%s.item", self.inputWidget, entry, inputEntry), inputImage)
    end
  end
end
