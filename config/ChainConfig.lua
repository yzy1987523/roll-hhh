--[[
ChainConfig.lua
合成链配置表

此配置表手动维护，记录每个合成链的信息
每个合成链包含：
- chainId: 合成链ID（使用链条首个物品的ID）
- name: 合成链名称（种类名称，如"化石"、"龙蛋碎片"）
- items: 合成链中的所有物品ID（从1级到N级）
- producers: 能生产此链条第1级物品的生产源ID列表

使用方式：
- 通过 chainId 查找合成链信息
- 获取合成链的所有物品
- 获取能生产此链条的生产源

编辑规则：
1. chainId 使用链条第1级物品的ID
2. name 是物品名称去掉数字后缀（如"化石1" → "化石"）
3. items 按等级顺序排列（1级、2级、3级...）
4. producers 列出所有能产出第1级物品的生产源ID
]]

ChainConfig = {
    -- 化石合成链
    {
        chainId = 01010101,
        name = "化石",
        items = {01010101, 01010102, 01010103, 01010104, 01010105, 01010106, 01010107, 01010108, 08010109},
        producers = {02010104},
    },

    -- 龙蛋碎片合成链
    {
        chainId = 01010201,
        name = "龙蛋碎片",
        items = {01010201, 01010202, 09010203, 08010204},
        producers = {02010104},
    },

    -- 宝箱合成链
    {
        chainId = 01020101,
        name = "宝箱",
        items = {01020101, 01020102, 01020103, 01020104, 01020105, 01020106, 01020107, 01020108, 08020109},
        producers = {02020104},
    },

    -- 龙蛋合成链
    {
        chainId = 01020201,
        name = "龙蛋",
        items = {01020201, 01020202, 01020203, 01020204, 01020205, 01020206, 01020207, 01020208, 01020209},
        producers = {02020104},
    },

    -- 肉块合成链
    {
        chainId = 01030101,
        name = "肉块",
        items = {01030101, 01030102, 01030103, 01030104, 01030105, 01030106, 01030107, 01030108, 08030109},
        producers = {02030104},
    },

    -- 恐龙蛋合成链
    {
        chainId = 01030201,
        name = "恐龙蛋",
        items = {01030201, 01030202, 09030203, 09030204, 08030205},
        producers = {02030104},
    },

    -- 探测器合成链
    {
        chainId = 01040101,
        name = "探测器",
        items = {01040101, 01040102, 01040103, 01040104, 01040105, 01040106, 01040107, 01040108, 08040109},
        producers = {02040104},
    },

    -- 龙蛋壳合成链
    {
        chainId = 01040201,
        name = "龙蛋壳",
        items = {01040201, 01040202, 01040203, 01040204, 01040205, 01040206, 01040207, 01040208, 08040209},
        producers = {02040104},
    },

    -- 水生生物合成链
    {
        chainId = 01050101,
        name = "水生生物",
        items = {01050101, 01050102, 01050103, 01050104, 01050105, 01050106, 01050107, 01050108, 08050109},
        producers = {02050104},
    },
    
    -- 水龙蛋合成链
    {
        chainId = 01050201,
        name = "水龙蛋",
        items = {01050201, 01050202, 09050203, 09050204, 09050205, 08050206},
        producers = {02050104},
    },

    -- 宝石合成链
    {
        chainId = 01060101,
        name = "宝石",
        items = {01060101, 01060102, 01060103, 01060104, 01060105, 01060106, 01060107, 01060108, 08060109},
        producers = {02060104},
    },

    -- 恐龙骨架合成链
    {
        chainId = 01060201,
        name = "恐龙骨架",
        items = {01060201, 01060202, 01060203, 01060204, 01060205, 01060206, 01060207, 01060208, 08060209},
        producers = {02060104},
    },

    -- 琥珀合成链
    {
        chainId = 01070101,
        name = "琥珀",
        items = {01070101, 01070102, 01070103, 01070104, 01070105, 01070106, 01070107, 01070108, 08070109},
        producers = {02070104},
    },

    -- 恐龙DNA合成链
    {
        chainId = 01070201,
        name = "恐龙DNA",
        items = {01070201, 01070202, 09070203, 09070204, 09070205, 09070206, 08070207},
        producers = {02070104},
    },

    -- 无底洞生产源链（包含1-3级composite + 4-8级production）
    {
        chainId = 01012101,
        name = "无底洞",
        items = {01012101, 01012102, 01012103, 02010104, 02010105, 02010106, 02010107, 08010108},
        producers = {},
    },
    
    -- 宝箱生产源链
    {
        chainId = 02020101,
        name = "宝箱",
        items = {01012201, 01012202, 01012203, 02020104, 02020105, 02020106, 02020107, 08020108},
        producers = {},
    },
    
    -- 肉块洞生产源链
    {
        chainId = 02030101,
        name = "肉块洞",
        items = {01012301, 01012302, 01012303, 02030104, 02030105, 02030106, 02030107, 08030108},
        producers = {},
    },
    
    -- 探测器生产源链
    {
        chainId = 02040101,
        name = "探测器",
        items = {01012401, 01012402, 01012403, 02040104, 02040105, 02040106, 02040107, 08040108},
        producers = {},
    },
    
    -- 水坑生产源链
    {
        chainId = 02050101,
        name = "水坑",
        items = {01012501, 01012502, 01012503, 02050104, 02050105, 02050106, 02050107, 08050108},
        producers = {},
    },
    
    -- 宝石箱生产源链
    {
        chainId = 02060101,
        name = "宝石箱",
        items = {01012601, 01012602, 01012603, 02060104, 02060105, 02060106, 02060107, 08060108},
        producers = {},
    },
    
    -- 琥珀生产源链
    {
        chainId = 02070101,
        name = "琥珀",
        items = {01012701, 01012702, 01012703, 02070104, 02070105, 02070106, 02070107, 08070108},
        producers = {},
    },
}

-- ==================== 私有缓存 ====================

local _itemToChainMap = nil   -- itemId → chainId 映射
local _chainMap = nil          -- chainId → chain 配置映射

-- ==================== 缓存构建 ====================

--[[
    构建物品ID到合成链ID的映射缓存
    在 GameManager 初始化时调用一次
]]
function ChainConfig.BuildCache()
    if _itemToChainMap then return end  -- 已构建则跳过
    
    _itemToChainMap = {}
    _chainMap = {}
    
    for _, chain in ipairs(ChainConfig) do
        -- 构建 chainId → chain 映射
        if chain.chainId then
            _chainMap[chain.chainId] = chain
        end
        
        -- 构建 itemId → chainId 映射
        for _, itemId in ipairs(chain.items or {}) do
            _itemToChainMap[itemId] = chain.chainId
        end
    end
    
    local itemCount = 0
    for _ in pairs(_itemToChainMap) do itemCount = itemCount + 1 end
    local chainCount = 0
    for _ in pairs(_chainMap) do chainCount = chainCount + 1 end
    
    print(string.format("[ChainConfig] 缓存构建完成: %d 个物品, %d 条合成链", itemCount, chainCount))
end

-- ==================== 查询接口 ====================

--[[
    根据物品ID获取所属的合成链配置（使用缓存 O(1)）
    @param itemId number 物品ID
    @return table | nil 合成链配置 { chainId, name, items, producers }
]]
function ChainConfig.GetChain(itemId)
    if not itemId then 
        print("[ChainConfig] GetChain: itemId 为 nil")
        return nil 
    end
    
    -- 确保缓存已构建
    if not _itemToChainMap then
        ChainConfig.BuildCache()
    end
    
    -- [调试] 打印查找信息
    local chainId = _itemToChainMap[itemId]
    print(string.format("[ChainConfig] GetChain: itemId=%d, chainId=%s", 
        itemId, chainId or "nil"))
    
    -- 通过映射快速查找
    if chainId then
        local chain = _chainMap[chainId]
        if chain then
            print(string.format("[ChainConfig] 找到链: chainId=%d name='%s' producers=%d个",
                chain.chainId, chain.name, chain.producers and #chain.producers or 0))
        end
        return chain
    end
    
    print("[ChainConfig] GetChain: 未找到对应链")
    return nil
end

--[[
    根据物品ID获取合成链ID
    @param itemId number 物品ID
    @return number | nil 合成链ID
]]
function ChainConfig.GetChainId(itemId)
    if not itemId then return nil end
    
    if not _itemToChainMap then
        ChainConfig.BuildCache()
    end
    
    return _itemToChainMap[itemId]
end

--[[
    根据物品ID获取生产源列表
    @param itemId number 物品ID
    @return table 生产源ID列表
]]
function ChainConfig.GetProducers(itemId)
    print(string.format("[ChainConfig] GetProducers: itemId=%d", itemId or 0))
    local chain = ChainConfig.GetChain(itemId)
    if chain and chain.producers then
        print(string.format("[ChainConfig] GetProducers: 找到 %d 个生产源", #chain.producers))
        return chain.producers
    end
    print("[ChainConfig] GetProducers: 未找到生产源")
    return {}
end

--[[
    根据chainId获取合成链配置（使用缓存 O(1)）
    @param chainId number 合成链ID
    @return table | nil 合成链配置
]]
function ChainConfig.GetChainById(chainId)
    if not chainId then return nil end
    
    if not _chainMap then
        ChainConfig.BuildCache()
    end
    
    return _chainMap[chainId]
end

return ChainConfig
