require "/scripts/util.lua"

---@class DroneConfig -- 参数与默认参数
local DroneConfig = {
    abilityScript = "/droneAbility/fire/fire.lua", --技能主脚本位置
    abilityClass = "Fire",                         --技能类型
    controlType = "wasd",                          --控制方式 参见 ---@enum ControlType
    abilityConfig = {},                            --技能配置
    moveSound = "",
    activeSound = "activate",                      --启动声音
    deactivateSound = "deactivate",                -- 关闭声音
    changeToHoverSound = "changeToHover",          --切换悬停声音
    changeToControlled = "changeToControlled",     -- 切换控制声音
    moveConfig = {                                 --移动设置
        --通用
        controlForce = 125,                        --控制力
        speed = 30,                                -- 速度
        --跟随鼠标设置
        minTriggerDistance = 2,                    -- 开始移动时鼠标最小距离
        maxSpeedDistance = 14                      -- 最大速度时的鼠标距离
    }
}


---@enum ControlType
local ControlType = {
    ---wasd控制
    wasd = 0,
    ---跟随鼠标移动
    followMouse = 1
}

local oldInit = init

function init()
    if oldInit then
        oldInit()
    end
    ---@type DroneConfig
    self.droneConfig = loadConfig()

    require(self.droneConfig.abilityScript)
    self.ability = _ENV[self.droneConfig.abilityClass]

    self.moveSound = self.droneConfig.moveSound
    self.moveConfig = self.droneConfig.moveConfig
    message.setHandler("targetPosition",
        function(_, _, pos, id)
            self.targetPosition = pos
        end)


    message.setHandler("argsData",
        function(_, _, argsData)
            ---@type Args
            self.playerControlArgs = argsData
        end)

    message.setHandler("changeHover",
        function(_, _, isHover)
            self.isHover = isHover
            if isHover == "hover" then
                if self.droneConfig.changeToHoverSound ~= "" then
                    animator.playSound(self.droneConfig.changeToHoverSound)
                end
            else
                if self.droneConfig.changeToControlled ~= "" then
                    animator.playSound(self.droneConfig.changeToControlled)
                end
            end
        end)

    message.setHandler("rightClick",
        function(_, _, targetPosition)
            rightClick(targetPosition)
        end)

    message.setHandler("deactivate",
        function(_, _)
            animator.playSound(self.droneConfig.deactivateSound)
            world.sendEntityMessage(entity.id(), "despawn")
        end)

    self.ability:init(self)
    script.setUpdateDelta(1)

    animator.playSound(self.droneConfig.activeSound)
end

local oldUpdate = update

function update(dt)
    if oldUpdate then
        oldUpdate(dt)
    end

    if self.droneConfig.controlTypeIndex == ControlType.followMouse and self.targetPosition then
        local differenceVector = vec2.sub(self.targetPosition, mcontroller.position())
        local magDiff = vec2.mag(differenceVector)
        local velMag = self.moveConfig.speed
        local minTriggerDistance = self.moveConfig.minTriggerDistance
        local maxSpeedDistance = self.moveConfig.maxSpeedDistance
        local controlForce = self.moveConfig.controlForce

        if self.isHover == "hover" then
            velMag = 0; controlForce = 125;

            if differenceVector[1] > 0 then
                mcontroller.controlFace(1)
            elseif differenceVector[1] < 0 then
                mcontroller.controlFace(-1)
            end
        end



        local speedMult = (math.min(magDiff, maxSpeedDistance) - minTriggerDistance) /
            (maxSpeedDistance - minTriggerDistance)
        velMag = velMag * speedMult

        local targetVel = { velMag * differenceVector[1] / magDiff, velMag * differenceVector[2] / magDiff }

        if not vec2.eq(targetVel, { 0, 0 }) then
            playMoveSound()
        end


        if magDiff > minTriggerDistance then
            local platformCollision = world.collisionBlocksAlongLine(mcontroller.position(),
                vec2.add(mcontroller.position(), { 0, -1 }), { "Platform" })
            -- sb.logInfo(sb.print(platformCollision))
            if platformCollision[1] ~= nill then
                mcontroller.setXVelocity(targetVel[1])
                mcontroller.setYPosition(vec2.add(mcontroller.position(), { 0, targetVel[2] / 60 })[2])
            else
                mcontroller.controlApproachVelocity(targetVel, controlForce)
            end

            if targetVel[1] > 0 then
                mcontroller.controlFace(1)
            elseif targetVel[1] < 0 then
                mcontroller.controlFace(-1)
            end
        else
            mcontroller.controlApproachVelocity({ 0, 0 }, controlForce)
        end
    elseif self.droneConfig.controlTypeIndex == ControlType.wasd and self.playerControlArgs then
        local controlForce = self.moveConfig.controlForce
        local speed = self.moveConfig.speed
        local targetVel = { 0, 0 }
        local differenceVector = vec2.sub(self.targetPosition, mcontroller.position())
        if self.isHover ~= "hover" then
            if self.playerControlArgs.up then
                targetVel[2] = targetVel[2] + speed
            end
            if self.playerControlArgs.down then
                targetVel[2] = targetVel[2] - speed
            end
            if self.playerControlArgs.left then
                targetVel[1] = targetVel[1] - speed
            end
            if self.playerControlArgs.right then
                targetVel[1] = targetVel[1] + speed
            end
        end

        if not vec2.eq(targetVel, { 0, 0 }) then
            playMoveSound()
        end

        if differenceVector[1] > 0 then
            mcontroller.controlFace(1)
        elseif differenceVector[1] < 0 then
            mcontroller.controlFace(-1)
        end

        local platformCollision = world.collisionBlocksAlongLine(mcontroller.position(),
            vec2.add(mcontroller.position(), { 0, -1 }), { "Platform" })
        -- sb.logInfo(sb.print(platformCollision))
        if platformCollision[1] ~= nill then
            mcontroller.setXVelocity(targetVel[1])
            mcontroller.setYPosition(vec2.add(mcontroller.position(), { 0, targetVel[2] / 60 })[2])
        else
            mcontroller.controlApproachVelocity(targetVel, controlForce)
        end
    end
    self.ability:update(dt, self)
end

local oldUninit = uninit
function uninit()
    if oldUninit then
        oldUninit()
    end

    if self.ability.uninit then
        self.ability:uninit()
    end
end

function rightClick(targetPosition)
    if self.ability.rightClick then
        self.ability:rightClick(targetPosition, self)
    end
end

function loadConfig()
    ---@type DroneConfig
    local rawConfig = config.getParameter("droneConfig", DroneConfig)
    local defaultConfig = copy(DroneConfig)
    ---@type DroneConfig
    ---合并默认值
    local config = util.mergeTable(defaultConfig, rawConfig)
    ---转换
    config.controlTypeIndex = ControlType[config.controlType]

    return config
end

function playMoveSound()
    if self.moveSound ~= "" then
        animator.playSound(self.moveSound)
    end
end
