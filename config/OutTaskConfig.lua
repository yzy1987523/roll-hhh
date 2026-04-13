--[[
OutTaskConfig.lua
局外任务配置表

字段说明：
- id: 任务ID
- name: 任务名称
- desc: 任务描述
- type: 任务类型（对应 StatisticsManager 统计字段）
    - mergeCount: 合成次数
    - mergeTaskCount: 合成任务完成次数
    - dinosaurCount: 拥有恐龙数量
    - landCount: 已解锁地块数量
    - feedCount: 喂食恐龙次数
    - hatchCount: 孵化恐龙次数
- target: 目标数量
- expReward: 完成奖励经验值
- unlockLevel: 解锁等级（玩家达到该等级后任务可接取）
]]

OutTaskConfig = {
    -- 等级1任务
    {
        id = 1,
        name = "合成新手",
        desc = "完成3次合成任务",
        type = "mergeTaskCount",
        target = 3,
        expReward = 100,
        unlockLevel = 1,
    },
    -- 等级2任务
    {
        id = 2,
        name = "继续合成",
        desc = "完成3次合成任务",
        type = "mergeTaskCount",
        target = 3,
        expReward = 50,
        unlockLevel = 2,
    },
    {
        id = 3,
        name = "初次孵化",
        desc = "成功孵化1只恐龙",
        type = "hatchCount",
        target = 1,
        expReward = 50,
        unlockLevel = 2,
    },
    -- 等级3任务
    {
        id = 4,
        name = "合成",
        desc = "完成5次合成任务",
        type = "mergeTaskCount",
        target = 5,
        expReward = 50,
        unlockLevel = 3,
    },
    {
        id = 5,
        name = "喂食",
        desc = "喂食恐龙1次",
        type = "feedCount",
        target = 1,
        expReward = 50,
        unlockLevel = 3,
    },
    -- 等级4任务
    {
        id = 6,
        name = "地块探索",
        desc = "解锁1个地块",
        type = "landCount",
        target = 1,
        expReward = 100,
        unlockLevel = 4,
    },
    -- 等级5任务
    {
        id = 7,
        name = "恐龙收藏家",
        desc = "拥有2只恐龙",
        type = "dinosaurCount",
        target = 3,
        expReward = 80,
        unlockLevel = 5,
    },
    
    -- 等级6任务
    {
        id = 6,
        name = "合成专家",
        desc = "完成10次合成任务",
        type = "mergeTaskCount",
        target = 10,
        expReward = 100,
        unlockLevel = 6,
    },
    -- 等级7任务
    {
        id = 7,
        name = "孵化大师",
        desc = "成功孵化5只恐龙",
        type = "hatchCount",
        target = 5,
        expReward = 100,
        unlockLevel = 7,
    },
    {
        id = 8,
        name = "恐龙饲养员",
        desc = "喂食恐龙10次",
        type = "feedCount",
        target = 10,
        expReward = 70,
        unlockLevel = 7,
    },
    
    -- 等级4任务
    {
        id = 9,
        name = "土地开发者",
        desc = "解锁15个地块",
        type = "landCount",
        target = 15,
        expReward = 100,
        unlockLevel = 7,
    },
    {
        id = 10,
        name = "恐龙园主",
        desc = "拥有5只恐龙",
        type = "dinosaurCount",
        target = 5,
        expReward = 120,
        unlockLevel = 7,
    },
    
    -- 等级5任务
    {
        id = 11,
        name = "合成大师",
        desc = "完成200次合成任务",
        type = "mergeTaskCount",
        target = 200,
        expReward = 100,
        unlockLevel = 7,
    },
    {
        id = 12,
        name = "孵化专家",
        desc = "成功孵化10只恐龙",
        type = "hatchCount",
        target = 10,
        expReward = 150,
        unlockLevel = 7,
    },
    {
        id = 13,
        name = "勤奋饲养",
        desc = "喂食恐龙30次",
        type = "feedCount",
        target = 30,
        expReward = 120,
        unlockLevel = 7,
    },
    
    -- 等级6任务
    {
        id = 14,
        name = "土地大亨",
        desc = "解锁25个地块",
        type = "landCount",
        target = 25,
        expReward = 150,
        unlockLevel = 7,
    },
    {
        id = 15,
        name = "恐龙大亨",
        desc = "拥有8只恐龙",
        type = "dinosaurCount",
        target = 8,
        expReward = 180,
        unlockLevel = 7,
    },
    
    -- 等级7任务
    {
        id = 16,
        name = "合成宗师",
        desc = "完成500次合成任务",
        type = "mergeTaskCount",
        target = 500,
        expReward = 150,
        unlockLevel = 7,
    },
    {
        id = 17,
        name = "孵化宗师",
        desc = "成功孵化15只恐龙",
        type = "hatchCount",
        target = 15,
        expReward = 200,
        unlockLevel = 7,
    },
    {
        id = 18,
        name = "专业饲养",
        desc = "喂食恐龙50次",
        type = "feedCount",
        target = 50,
        expReward = 160,
        unlockLevel = 7,
    },
    
    -- 等级8任务
    {
        id = 19,
        name = "土地霸主",
        desc = "解锁40个地块",
        type = "landCount",
        target = 40,
        expReward = 200,
        unlockLevel = 8,
    },
    {
        id = 20,
        name = "恐龙帝国",
        desc = "拥有12只恐龙",
        type = "dinosaurCount",
        target = 12,
        expReward = 250,
        unlockLevel = 8,
    },
    
    -- 等级9任务
    {
        id = 21,
        name = "合成传奇",
        desc = "完成1000次合成任务",
        type = "mergeTaskCount",
        target = 1000,
        expReward = 200,
        unlockLevel = 9,
    },
    {
        id = 22,
        name = "孵化传奇",
        desc = "成功孵化25只恐龙",
        type = "hatchCount",
        target = 25,
        expReward = 300,
        unlockLevel = 9,
    },
    {
        id = 23,
        name = "饲养传奇",
        desc = "喂食恐龙100次",
        type = "feedCount",
        target = 100,
        expReward = 220,
        unlockLevel = 9,
    },
    
    -- 等级10任务
    {
        id = 24,
        name = "土地王者",
        desc = "解锁全部地块",
        type = "landCount",
        target = 63,
        expReward = 300,
        unlockLevel = 10,
    },
    {
        id = 25,
        name = "恐龙王者",
        desc = "拥有20只恐龙",
        type = "dinosaurCount",
        target = 20,
        expReward = 500,
        unlockLevel = 10,
    },
}

--[[
    根据ID获取任务配置
    @param taskId number 任务ID
    @return table | nil
]]
function OutTaskConfig:GetById(taskId)
    for _, task in ipairs(self) do
        if task.id == taskId then
            return task
        end
    end
    return nil
end

--[[
    获取指定等级解锁的所有任务
    @param level number 等级
    @return table 任务配置列表
]]
function OutTaskConfig:GetByUnlockLevel(level)
    local tasks = {}
    for _, task in ipairs(self) do
        if task.unlockLevel == level then
            table.insert(tasks, task)
        end
    end
    return tasks
end

--[[
    获取所有任务配置
    @return table 任务配置列表
]]
function OutTaskConfig:GetAll()
    return self
end
