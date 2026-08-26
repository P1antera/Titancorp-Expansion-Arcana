require "/scripts/util.lua"
Fire = { --这是技能类型
    ---@class FireAbilityConfig
    abilityConfig = {
        projectileType = "dragonfirelarge",
        fireType = "single",     --开火类型
        projectileCount = 1,     --每次开火射出的弹射物数量
        -------------以下俩配置只在fireType = burst时生效
        burstCount = 1,          --爆发射击数
        burstTime = 1,           --射完爆发射击数所需的总时间
        -------------
        inaccuracy = 0,          --散射偏移量
        projectileParam = {},    --弹射物配置
        muzzleOffset = { 0, 0 }, --炮口位置(黄色debug点)
        animationConfig = {
            fireSound = "",      --开火声音
            windupAnimation = {  -- 准备动画
                stateType = "",
                state = "",
                time = 0,
            },
            fireAnimation = { --开火动画
                stateType = "",
                state = "",
                time = 0,
            },
            winddownAnimation = { -- 结束动画
                stateType = "",
                state = "",
                time = 0,
            },
            turretGroup = "",         --炮台转换组(transformationGroups)
            rotationCenter = { 0, 0 } --炮台旋转中心 炮口的旋转中心由这个参数决定(红色debug点)
        }
    }
}

---@enum FireType
local FireType = {
    single = 0, --单发射击
    burst = 1   -- 爆发射击
}

---@enum Stage
local Stage = {
    windup = 0,
    fire = 1,
    winddown = 2,
    idle = 3
}

function Fire:init(drone)
    ---@type FireAbilityConfig
    self.abilityConfig = util.mergeTable(self.abilityConfig, drone.droneConfig.abilityConfig)
    self.abilityConfig.fireTypeIndex = FireType[self.abilityConfig.fireType]
    self.inaccuracy = self.abilityConfig.inaccuracy

    self.stage = Stage.idle
    self.burstFire = false
    self.burstRemain = 0
    self.burstInterval = 0
    self.burstIntervalTime = 0

    self.fireSound = self.abilityConfig.animationConfig.fireSound
    self.fireAnimation = self.abilityConfig.animationConfig.fireAnimation
    self.windupAnimation = self.abilityConfig.animationConfig.windupAnimation
    self.winddownAnimation = self.abilityConfig.animationConfig.winddownAnimation
    self.muzzleOffset = self.abilityConfig.muzzleOffset

    self.animationConfig = self.abilityConfig.animationConfig
    self.projectileCount = self.abilityConfig.projectileCount

    self.windupTime = 0
    self.fireTime = 0
    self.winddownTime = 0

    self.windupAndFireTime = 0
    self.totalTime = 0
end

function Fire:update(dt, drone)
    local differenceVector = vec2.sub(drone.targetPosition, self:getWorldTurretRotationCenter())


    if self.burstFire then
        if self.burstIntervalTime == 0 and self.burstRemain > 0 then
            local projectileType = self.abilityConfig.projectileType
            local param = self.abilityConfig.projectileParam
            if self.fireSound ~= "" then
                animator.playSound(self.fireSound)
            end
            if self.fireAnimation.stateType ~= "" then
                animator.setAnimationState(self.fireAnimation.stateType, self.fireAnimation.state)
            end

            for i = 1, self.projectileCount do
                i = i + 1
                world.spawnProjectile(projectileType, self:getFirePosition(drone), entity.id(),
                    self:aimVector(differenceVector, self.inaccuracy), nil, param)
            end
            self.burstIntervalTime = self.burstInterval
            self.burstRemain = self.burstRemain - 1
        end

        self.burstIntervalTime = math.max(0, self.burstIntervalTime - dt)

        if self.burstRemain == 0 then
            self.burstFire = false
        end
    end

    if self.animationConfig.turretGroup ~= "" then
        differenceVector[1] = differenceVector[1] * mcontroller.facingDirection()
        animator.resetTransformationGroup(self.animationConfig.turretGroup)
        animator.rotateTransformationGroup(self.animationConfig.turretGroup, -vec2.angle(differenceVector),
            self.animationConfig.rotationCenter)
    end

    self:drawDebugPoint(drone)

    self.windupTime = math.max(0, self.windupTime - dt)
    self.fireTime = math.max(0, self.fireTime - dt)
    self.winddownTime = math.max(0, self.winddownTime - dt)

    if self.windupTime == 0 and self.stage == Stage.windup then
        self:fire(drone.targetPosition, drone)
        self.fireTime = self.abilityConfig.animationConfig.fireAnimation.time
        self.stage = Stage.fire
    end

    if self.fireTime == 0 and self.stage == Stage.fire then
        self.stage = Stage.winddown
        self.winddownTime = self.winddownAnimation.time
        if self.winddownAnimation.stateType ~= "" then
            animator.setAnimationState(self.winddownAnimation.stateType, self.winddownAnimation.state)
        end
    end

    if self.winddownTime == 0 and self.stage == Stage.winddown then
        self.stage = Stage.idle
    end
end

function Fire:uninit()

end

function Fire:rightClick(targetPosition, drone)
    if self.stage == Stage.idle then
        self.windupTime = self.windupAnimation.time
        self.stage = Stage.windup
        if self.windupAnimation.stateType ~= "" then
            animator.setAnimationState(self.windupAnimation.stateType, self.windupAnimation.state)
        end
    end

    if self.stage == Stage.winddown then
        self:fire(drone.targetPosition, drone)
        self.fireTime = self.abilityConfig.animationConfig.fireAnimation.time
        self.stage = Stage.fire
    end
end

function Fire:fire(targetPosition, drone)
    local differenceVector = vec2.sub(targetPosition, self:getWorldTurretRotationCenter())

    ---@type FireAbilityConfig
    local abilityConfig = self.abilityConfig

    local projectileType = abilityConfig.projectileType
    local fireTypeIndex = abilityConfig.fireTypeIndex
    local param = abilityConfig.projectileParam
    local burstTime = abilityConfig.burstTime
    local burstCount = abilityConfig.burstCount

    if fireTypeIndex == FireType.single then
        if self.fireSound ~= "" then
            animator.playSound(self.fireSound)
        end
        if self.fireAnimation.stateType ~= "" then
            animator.setAnimationState(self.fireAnimation.stateType, self.fireAnimation.state)
        end
        for i = 1, self.projectileCount do
            world.spawnProjectile(projectileType, self:getFirePosition(drone), entity.id(),
                self:aimVector(differenceVector, self.inaccuracy), nil, param)
        end
    elseif fireTypeIndex == FireType.burst then
        self.burstFire = true
        self.burstRemain = burstCount
        self.burstInterval = burstTime / burstCount
    end
end

function Fire:aimVector(targetPosition, inaccuracy)
    local aimVector = vec2.rotate({ 1, 0 }, vec2.angle(targetPosition) + sb.nrand(inaccuracy, 0))
    return aimVector
end

function Fire:getFirePosition(drone)
    local differenceVector = vec2.sub(drone.targetPosition, self:getWorldTurretRotationCenter())
    local rotateAngle = vec2.angle(differenceVector);
    rotateAngle = rotateAngle * mcontroller.facingDirection()
    local muzzleVec2 = vec2.rotate(self.muzzleOffset, rotateAngle)

    muzzleVec2[2] = muzzleVec2[2] * mcontroller.facingDirection()

    local firePosition = vec2.add(self:getWorldTurretRotationCenter(), muzzleVec2)
    return firePosition
end

function Fire:getWorldTurretRotationCenter()
    local rotationCenter = copy(self.abilityConfig.animationConfig.rotationCenter)
    rotationCenter[1] = rotationCenter[1] * mcontroller.facingDirection()
    local rotateCenter = vec2.add(mcontroller.position(), rotationCenter)
    return rotateCenter
end

function Fire:drawDebugPoint(drone)
    world.debugPoint(self:getWorldTurretRotationCenter(), { 255, 0, 0, 255 })
    world.debugPoint(self:getFirePosition(drone), { 255, 255, 0, 255 })
end
