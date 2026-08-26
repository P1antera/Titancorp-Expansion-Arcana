require "/scripts/util.lua"
require "/scripts/vec2.lua"
---@class ControllerConfig
local controllerConfig = {
    --控制无人机时本体是否可移动
    canMoveWhenControl = false,
    --右键冷却时间
    rightClickCooldown = 1,
    --无人机的怪物类型
    droneType = "",
    --无人机配置
    droneParam = {
        droneConfig = {

        }
    }
}

---@class Args
local Args = {
    up = false,
    down = false,
    left = false,
    right = false
}


function loadConfig()
    return util.mergeTable(controllerConfig, config.getParameter("controllerConfig"))
end

local oldInit = init
function init()
    if oldInit then
        oldInit()
    end
    self.boundingBox = config.getParameter("boundingBox")
    ---@type ControllerConfig
    self.controllerConfig = loadConfig()
    self.rightClickCooldownTime = 0

    self.findReconDroneTicks = 0
    self.cameraLocked = false
    script.setUpdateDelta(1)
end

local oldUpdate = update
function update(dt, fireMode, shiftHeld, args)
    if oldUpdate then
        oldUpdate(dt, fireMode, shiftHeld, args)
    end
    ---@type Args
    local args = args
    if not monsterExists() then
        self.aimAngle, self.facingDirection = activeItem.aimAngleAndDirection(0, activeItem.ownerAimPosition())
        activeItem.setFacingDirection(self.facingDirection)

        activeItem.setArmAngle(self.aimAngle)
    end

    if monsterExists() then
        world.sendEntityMessage(storage.monsterId, "targetPosition", activeItem.ownerAimPosition(),
            activeItem.ownerEntityId())

        world.sendEntityMessage(storage.monsterId, "argsData", args)

        -- incase drone doesn't successfully set its owner proper
        if world.entityName(storage.monsterId) == "" then
            world.sendEntityMessage(storage.monsterId, "setOwner", activeItem.ownerEntityId())
        end

        if not self.cameraLocked then
            activeItem.setCameraFocusEntity(storage.monsterId)
            self.cameraLocked = true
        end


        if fireMode == "alt" and ready() and monsterExists() then
            local monsterPosition = vec2.add(world.entityPosition(storage.monsterId), { -0.5, -0.25 })
            self.rightClickCooldownTime = self.controllerConfig.rightClickCooldown
            world.sendEntityMessage(storage.monsterId, "rightClick", activeItem.ownerAimPosition())
        end


        activeItem.setScriptedAnimationParameter("monsterId", storage.monsterId)
    else
        activeItem.setScriptedAnimationParameter("monsterId", nil)
    end

    if self.findReconDroneTicks > 0 then
        -- findSpawnedReconDrone()
        self.findReconDroneTicks = self.findReconDroneTicks - 1
    end



    if shiftHeld and not self.shiftWasHeld and monsterExists() then
        animator.playSound("changeToHover")
        world.sendEntityMessage(storage.monsterId, "changeHover", "hover")
    elseif not shiftHeld and self.shiftWasHeld and monsterExists() then
        world.sendEntityMessage(storage.monsterId, "changeHover", "controlled")
        animator.playSound("changeToControlled")
    end

    self.primaryHeld = fireMode == "primary"
    self.shiftWasHeld = shiftHeld

    self.rightClickCooldownTime = math.max(0, self.rightClickCooldownTime - dt)

    if not self.controllerConfig.canMoveWhenControl and monsterExists() then
        mcontroller.controlModifiers({
            movementSuppressed = true
        })
    end
end

local oldUninit = uninit
function uninit()
    if oldUninit then
        oldUninit()
    end
    if storage.monsterId then world.sendEntityMessage(storage.monsterId, "deactivate") end
    storage.monsterId = nil

    self.cameraLocked = false
    activeItem.setCameraFocusEntity()
end

function activate(fireMode, shiftHeld)
    --local validSpawn = (world.magnitude(mcontroller.position(), activeItem.ownerAimPosition()) <= 10 and placementValid())
    if fireMode == "primary" and not self.primaryHeld and placementValid2() and (storage.monsterId == nil or not world.entityExists(storage.monsterId)) then
        animator.playSound("activate")

        local damageTeam = world.entityDamageTeam(activeItem.ownerEntityId())

        local param = util.mergeTable({
            spawnerId = activeItem.ownerEntityId(),
            level = 1,
            damageTeam = damageTeam.team,
            damageTeamType = damageTeam.type,
            aggressive = true
        }, self.controllerConfig.droneParam)

        if self.controllerConfig.droneType ~= "" then
            storage.monsterId = world.spawnMonster(self.controllerConfig.droneType,
                vec2.add(mcontroller.position(), { 0, 2 }), param)
        end

        self.cameraLocked = false

        self.findReconDroneTicks = 45
    elseif fireMode == "primary" and not self.primaryHeld and monsterExists() then
        animator.playSound("deactivate")
        world.sendEntityMessage(storage.monsterId, "deactivate")
        storage.monsterId = nil
    end
end

function monsterExists()
    return (storage.monsterId and world.entityExists(storage.monsterId))
end

function ready()
    return self.rightClickCooldownTime == 0
end

function placementValid()
    local aimPosition = activeItem.ownerAimPosition()

    if world.lineTileCollision(mcontroller.position(), aimPosition) then
        return false
    end

    local boundingBox = self.boundingBox

    local bounds = {
        boundingBox[1] + aimPosition[1],
        boundingBox[2] + aimPosition[2],
        boundingBox[3] + aimPosition[1],
        boundingBox[4] + aimPosition[2]
    }

    if world.rectTileCollision(bounds, { "Null", "Block", "Dynamic", "Slippery" }) then
        return false
    end

    return true
end

function placementValid2()
    local aimPosition = vec2.add(mcontroller.position(), { 0, 2 })

    if world.lineTileCollision(mcontroller.position(), aimPosition) then
        return false
    end

    local boundingBox = self.boundingBox

    local bounds = {
        boundingBox[1] + aimPosition[1],
        boundingBox[2] + aimPosition[2],
        boundingBox[3] + aimPosition[1],
        boundingBox[4] + aimPosition[2]
    }

    if world.rectTileCollision(bounds, { "Null", "Block", "Dynamic", "Slippery" }) then
        return false
    end

    return true
end
