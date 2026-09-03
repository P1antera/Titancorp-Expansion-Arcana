function init()
  local configPath = config.getParameter("configPath", "/objects/workshop/at_ext_fermenter/config.config")
  self.machineConfig = root.assetJson(configPath)
  self.recipes = self.machineConfig.recipes or {}
  self.descriptionLabel = "lblText"
  self.inputWidget = "scrollArea.inputList"
  self.progressWidget = "progress"
  self.completedWidget = "completedText"
  self.completedFormat = config.getParameter("completedFormat", "Brewed: %d/%d")
  self.entity = pane.containerEntityId()

  populateFields()
  populateList()
end

function update(dt)
  if self.bottlePromise then
    if self.bottlePromise:finished() then
      self.bottlePromise = nil
    end
    return
  end

  if not self.statusPromise then
    self.statusPromise = world.sendEntityMessage(self.entity, "getFermenterStatus")
  end

  if self.statusPromise:finished() then
    if self.statusPromise:succeeded() then
      local status = self.statusPromise:result()
      widget.setProgress(self.progressWidget, status.progress or 0)
      widget.setText(self.completedWidget, string.format(
        self.completedFormat,
        status.completed or 0,
        status.capacity or 100
      ))
    end
    self.statusPromise = nil
  end
end

function bottleCompletedOutputs()
  if not self.bottlePromise then
    self.bottlePromise = world.sendEntityMessage(self.entity, "bottleCompletedOutputs")
  end
end

function itemName(item)
  local success, itemConfig = pcall(root.itemConfig, item)
  if success and itemConfig and itemConfig.config then
    return itemConfig.config.shortdescription or item.name or "Unknown output"
  end
  return item.name or "Unknown output"
end

function setItemSlot(slot, item)
  -- Invalid third-party item descriptors must not stop later recipes from rendering.
  pcall(widget.setItemSlotItem, slot, item)
end

function populateFields()
  widget.setText(self.descriptionLabel, self.machineConfig.description or "Fermentation recipes")
end

function populateList()
  widget.clearListItems(self.inputWidget)

  for _, recipe in pairs(self.recipes) do
    local entry = widget.addListItem(self.inputWidget)
    local inputList = string.format("%s.%s.input", self.inputWidget, entry)
    local output = recipe.output or {}

    widget.setText(string.format("%s.%s.text", self.inputWidget, entry), itemName(output))
    setItemSlot(string.format("%s.%s.outitem", self.inputWidget, entry), output)

    for _, input in ipairs(recipe.input or {}) do
      local inputEntry = widget.addListItem(inputList)
      setItemSlot(string.format("%s.%s.input.%s.initem", self.inputWidget, entry, inputEntry), input)
    end
  end
end
