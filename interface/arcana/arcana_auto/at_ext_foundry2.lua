function init()
  local configPath = config.getParameter("configPath", "/objects/workshop/at_ext_foundry2/config.config")
  self.config = root.assetJson(configPath)
  self.recipes = self.config.recipes or {}
  self.rateLabel = "lblRate"
  self.descriptionLabel = "lblText"
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

function itemName(item)
  local success, itemConfig = pcall(root.itemConfig, item)
  if success and itemConfig and itemConfig.config then
    return itemConfig.config.shortdescription or item.name or "Unknown output"
  end

  return item.name or "Unknown output"
end

function setItemSlot(slot, item)
  -- An unresolved item must not prevent subsequent recipes from being listed.
  pcall(widget.setItemSlotItem, slot, item)
end

function populateFields()
  widget.setText(self.rateLabel, string.format("Rate: %s", tostring(self.config.craftingTime or 1)))
  widget.setText(self.descriptionLabel, self.config.description or "Autofilled")
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
