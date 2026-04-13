--[[
BuildConfig.lua
建造配置表

字段说明：
- furnitureId: 建造的家具ID
- starCost: 建造所需的星星数量
- expReward: 建造完成奖励的经验值
- itemReward: 建造完成奖励的物品ID列表（可选）
- unlockLevel: 解锁等级（玩家达到该等级后可建造）
- nextBuildId: 建造完成后解锁的下一个建造ID（-1表示无后续）
]]

BuildConfig = BuildConfig or {}

-- ==================== 建造配置数据 ====================

local _buildData = {
    { id = 1,  name = "建造化石架",     furnitureId = 03010101, starCost = 2,  expReward = 10,  itemReward = {},     unlockLevel = 1,  nextBuildId = 2  },
    { id = 2,  name = "建造工具台",     furnitureId = 03020101, starCost = 3,  expReward = 20,  itemReward = {},     unlockLevel = 1,  nextBuildId = 3  },
    { id = 3,  name = "建造设备柜",     furnitureId = 03030101, starCost = 4,  expReward = 30,  itemReward = {},     unlockLevel = 2,  nextBuildId = 4  },
    { id = 4,  name = "建造化石修复台", furnitureId = 03040101, starCost = 5,  expReward = 50,  itemReward = {02010104}, unlockLevel = 3, nextBuildId = 5  },
    { id = 5,  name = "建造高级化石架", furnitureId = 03010102, starCost = 6,  expReward = 80,  itemReward = {},     unlockLevel = 4,  nextBuildId = 6  },
    { id = 6,  name = "建造高级工具台", furnitureId = 03020102, starCost = 7,  expReward = 100, itemReward = {02020104}, unlockLevel = 5, nextBuildId = 7  },
    { id = 7,  name = "建造孵化器",     furnitureId = 03050101, starCost = 8,  expReward = 150, itemReward = {},     unlockLevel = 6,  nextBuildId = 8  },
    { id = 8,  name = "建造恐龙研究台", furnitureId = 03060101, starCost = 9,  expReward = 200, itemReward = {02030105}, unlockLevel = 7, nextBuildId = 9  },
    { id = 9,  name = "建造珍品展厅",   furnitureId = 03070101, starCost = 10, expReward = 300, itemReward = {},    unlockLevel = 8,  nextBuildId = 10 },
    { id = 10, name = "建造传说熔炉",   furnitureId = 03080101, starCost = 11, expReward = 500, itemReward = {01012501}, unlockLevel = 10, nextBuildId = -1 },
}

-- ==================== 查表接口 ====================

--[[
    获取指定ID的建造配置
    @param id number 建造ID
    @return table | nil
]]
function BuildConfig:Get(id)
    for _, config in ipairs(_buildData) do
        if config.id == id then
            return config
        end
    end
    return nil
end

--[[
    获取指定等级可解锁的建造ID列表
    @param level number 玩家等级
    @return table 建造ID列表
]]
function BuildConfig:GetUnlockedBuilds(level)
    local result = {}
    for _, config in ipairs(_buildData) do
        if config.unlockLevel <= level then
            table.insert(result, config.id)
        end
    end
    return result
end

--[[
    获取下一个可建造的ID（未完成的）
    @param completedIds table 已完成的建造ID列表
    @param playerLevel number 玩家等级
    @return number 下一个可建造的ID，0表示无可用建造
]]
function BuildConfig:GetNextBuildId(completedIds, playerLevel)
    local completedSet = {}
    for _, id in ipairs(completedIds or {}) do
        completedSet[id] = true
    end

    for _, config in ipairs(_buildData) do
        if config.unlockLevel <= playerLevel and not completedSet[config.id] then
            return config.id
        end
    end
    return 0
end

return BuildConfig
