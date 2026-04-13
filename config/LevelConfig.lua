--[[
LevelConfig.lua
等级配置表

字段说明：
- expRequired: 升级所需累计经验（当前等级需要达到的经验值）
- taskUnlock: 该等级解锁的任务ID列表
- rewards: 升级奖励（可选）
]]

LevelConfig = {    
    [2] = {
        expRequired = 100,
        taskUnlock = {4, 5},
        rewards = {
            coin = 0,
            items = {02010104},
        },
    },
    [3] = {
        expRequired = 100,
        taskUnlock = {6, 7, 8},
        rewards = {
            coin = 0,
            items = {01012201,02010105},
        },
    },
    [4] = {
        expRequired = 100,
        taskUnlock = {9, 10},
        rewards = {
            coin = 0,
            items = {02030104},
        },
    },
    [5] = {
        expRequired = 100,
        taskUnlock = {11, 12, 13},
        rewards = {
            coin = 0,
            items = {02040104},
        },
    },
    [6] = {
        expRequired = 100,
        taskUnlock = {14, 15},
        rewards = {
            coin = 1000,
            items = {02060104},
        },
    },
    [7] = {
        expRequired = 100,
        taskUnlock = {16, 17, 18},
        rewards = {
            coin = 1500,
            items = {01010104, 01010105},
        },
    },
    [8] = {
        expRequired = 100,
        taskUnlock = {19, 20},
        rewards = {
            coin = 2000,
            items = {01020104, 01020105},
        },
    },
    [9] = {
        expRequired = 100,
        taskUnlock = {21, 22, 23},
        rewards = {
            coin = 3000,
            items = {01010107, 01010108},
        },
    },
    [10] = {
        expRequired = 100,
        taskUnlock = {24, 25},
        rewards = {
            coin = 5000,
            items = {01020107, 01020108},
        },
    },
}

-- 最大等级
LevelConfig.MAX_LEVEL = 10

--[[
    获取指定等级的配置
    @param level number 等级
    @return table | nil
]]
function LevelConfig:Get(level)
    return self[level]
end

--[[
    获取升级所需经验
    @param level number 当前等级
    @return number 下一级所需累计经验，满级返回 -1
]]
function LevelConfig:GetExpRequired(level)
    if level >= self.MAX_LEVEL then
        return -1
    end
    local nextConfig = self[level + 1]
    return nextConfig and nextConfig.expRequired or -1
end

--[[
    获取指定等级解锁的任务ID列表
    @param level number 等级
    @return table 任务ID列表
]]
function LevelConfig:GetUnlockedTasks(level)
    local config = self[level]
    return config and config.taskUnlock or {}
end

--[[
    获取升级奖励
    @param level number 升级到的等级
    @return table | nil 奖励配置
]]
function LevelConfig:GetRewards(level)
    local config = self[level]
    return config and config.rewards or nil
end
