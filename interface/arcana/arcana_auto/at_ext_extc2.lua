require "/scripts/util.lua"

function init()
  local configPath = "/objects/workshop/at_ext_extractor2/at_ext_extc2.config"

  self.recipes = root.assetJson(configPath).recipes

  self.list = "liquidPane.liquidArea.liquidList"

  self.tabs = "radioMain"
  populateList()


end

function update(dt)

end

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o) or "NIL"
   end
end







function populateList()
  widget.clearListItems(self.list)

  for _, recipe in pairs(self.recipes) do
    local item = widget.addListItem(self.list)
    local liquid = recipe.input
	local liquidImage = util.absolutePath(root.itemConfig(liquid).directory, root.itemConfig(liquid).config.inventoryIcon)
	widget.setImage(string.format("%s.%s.icon", self.list, item), liquidImage)
    widget.setText(string.format("%s.%s.name", self.list, item), root.itemConfig(liquid).config.shortdescription)
	widget.setText(string.format("%s.%s.description", self.list, item), root.itemConfig(liquid).config.description)
	
	for _, output in ipairs(recipe.output) do
	  local outputItem = widget.addListItem(string.format("%s.%s.outputList", self.list, item))
	  liquid = output.item
      liquidImage = util.absolutePath(root.itemConfig(liquid).directory, root.itemConfig(liquid).config.inventoryIcon)
	  widget.setImage(string.format("%s.%s.outputList.%s.icon", self.list, item, outputItem), liquidImage)
	end
  end
end