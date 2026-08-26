require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.colorCache = {}
end

function update()
  localAnimator.clearDrawables()

  local pingLocation = animationConfig.animationParameter("pingLocation")
  if pingLocation then
	self.ownerId = animationConfig.animationParameter("ownerId")
	
    if not self.pingLocation or not vec2.eq(pingLocation, self.pingLocation) then
      self.pingLocation = pingLocation
      self.colorCache = {}
    end
    local detectConfig = animationConfig.animationParameter("pingDetectConfig")
    local outerRadius = math.ceil(animationConfig.animationParameter("pingOuterRadius"))
    local innerRadius = math.floor(animationConfig.animationParameter("pingInnerRadius"))
    local fadeDistance = outerRadius - innerRadius

    local searchRange = math.min(detectConfig.maxRange, outerRadius)
    local srsq = searchRange ^ 2
    local irsq = innerRadius ^ 2
    local new, cached = 0, 0
    for x = -searchRange, searchRange do
      for y = -searchRange, searchRange do
        local distSquared = x ^ 2 + y ^ 2
        if distSquared <= srsq and distSquared >= irsq then
          local position = {x + pingLocation[1], y + pingLocation[2]}

          local cacheKey = position[1]..","..position[2]
          if not self.colorCache[cacheKey] then
            new = new + 1
            if detectConfig.type == "cave" or detectConfig.type == "entity" then
              if world.pointTileCollision(position) then
                self.colorCache[cacheKey] = detectConfig.colors.solid
              else
                self.colorCache[cacheKey] = detectConfig.colors.empty
              end
			  
			  if detectConfig.type == "entity" then
				local entity = findEntity(position)
				if entity == "neutral" then
					self.colorCache[cacheKey] = detectConfig.colors.neutral
				elseif entity then
					self.colorCache[cacheKey] = detectConfig.colors.hostile
				end
			  end
            elseif detectConfig.type == "ore" then
              local oreMod
              if world.pointTileCollision(position) then
                oreMod = world.mod(position, "foreground")
              else
                oreMod = world.mod(position, "background")
              end

              if detectConfig.colors[oreMod] then
                self.colorCache[cacheKey] = detectConfig.colors[oreMod]
              else
                self.colorCache[cacheKey] = detectConfig.colors.none
              end
            end
          else
            cached = cached + 1
          end

          local color = copy(self.colorCache[cacheKey])

          local dist = math.sqrt(distSquared)
          local fadeFactor = 2 * math.min(dist - innerRadius, math.min(outerRadius - dist, searchRange - dist)) / fadeDistance
          color[4] = color[4] * fadeFactor

          local variant = math.random(1, detectConfig.variants)
          localAnimator.addDrawable({
              image = detectConfig.image:gsub("<variant>", variant),
              fullbright = true,
              position = position,
              centered = false,
              color = color
            }, "overlay")
        end
      end
    end
  else
    self.pingLocation = nil
  end
end

function findEntity(pos) -- looks for possibly hostile entities
	local monsterId = animationConfig.animationParameter("monsterId")
	local queryParameters = {
		withoutEntityId = monsterId,
		includedTypes = {"creature"},
		order = "nearest"
	}
	if not monsterId then
		queryParameters = {
			includedTypes = {"creature"},
			order = "nearest"
		}
	end
	
	local candidates = world.entityQuery(pos, 1, queryParameters)
	for _, candidate in ipairs(candidates) do
		if world.entityCanDamage(self.ownerId, candidate) then
			if world.entityAggressive(candidate) then
				return true
			else
				return "neutral"
			end
		end
	end
	return false
end