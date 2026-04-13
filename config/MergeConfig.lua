--[[
MergeConfig.lua
合成系统配置表
定义格子矩阵、解锁规则、状态枚举，以及物品/合成的快速查表
]]

MergeConfig = MergeConfig or {}

-- ==================== 基础配置 ====================

MergeConfig.Grid = {
    rows     = 7,
    cols     = 9,
    cellSize = 124,
    spacing  = 0,
    margin   = 0,   -- 格子区域外边距
}

-- 获取格子区域总尺寸（不含边距）
function MergeConfig:GetGridPixelSize()
    local w = self.Grid.cols * self.Grid.cellSize + (self.Grid.cols - 1) * self.Grid.spacing
    local h = self.Grid.rows * self.Grid.cellSize + (self.Grid.rows - 1) * self.Grid.spacing
    return w, h
end

-- 获取 Panel 所需尺寸（含边距）
function MergeConfig:GetPanelSize()
    local gridW, gridH = self:GetGridPixelSize()
    return gridW + 2 * self.Grid.margin, gridH + 2 * self.Grid.margin
end

-- ==================== 初始解锁格子 ====================

MergeConfig.initialUnlockedGrids = {
    { row = 1, col = 1 },
    { row = 1, col = 2 },
    { row = 1, col = 3 },
    { row = 1, col = 4 },
}

-- ==================== 格子状态枚举 ====================

MergeConfig.GridState = {
    LOCKED   = 1,   -- 锁定（未解锁）
    DUSTY    = 2,   -- 尘土覆盖（可清理解锁）
    OCCUPIED = 3,   -- 已被物品占用
    EMPTY    = 4,   -- 空置
}

-- ==================== 物品类型枚举 ====================
-- 与 ItemConfig.lua 中的 type 字段保持一致

MergeConfig.ItemType = {
    COMPOSITE      = "composite",      -- 可合成物品
    PRODUCTION     = "production",     -- 生成器（有库存限制）
    MAX_PRODUCTION = "maxproduction",  -- 满载生成器
    EGG            = "egg",            -- 孵化蛋
    COIN           = "coin",           -- 金币（不可拖拽/合成）
}

-- ==================== 内部缓存（私有）====================

local _itemMap   = nil   -- itemId → ItemConfig 行，O(1) 查找
local _mergeMap  = nil   -- itemId → next_composite itemId，O(1) 合成结果

-- ==================== 缓存构建 ====================

--[[
    构建 itemId → config 的哈希表
    需要在 ItemConfig 加载完毕后调用一次（GameManager:OnInit 里）
    之后每次增删 ItemConfig 时也需要重新调用
]]
function MergeConfig:BuildItemMap()
    _itemMap  = {}
    _mergeMap = {}

    if not ItemConfig then
        print("[MergeConfig] 警告：ItemConfig 未加载，itemMap 为空")
        return
    end

    for _, cfg in ipairs(ItemConfig) do
        -- id → 完整配置
        _itemMap[cfg.id] = cfg

        -- id → 合成后 id（仅有 next_composite 时写入）
        if cfg.next_composite and cfg.next_composite ~= 0 then
            _mergeMap[cfg.id] = cfg.next_composite
        end
    end

    local itemCount  = 0
    local mergeCount = 0
    for _ in pairs(_itemMap)  do itemCount  = itemCount  + 1 end
    for _ in pairs(_mergeMap) do mergeCount = mergeCount + 1 end

    print(string.format("[MergeConfig] itemMap 构建完成：%d 个物品，%d 条合成链",
        itemCount, mergeCount))
end

-- ==================== 查表接口 ====================

--[[
    通过 itemId 获取物品配置，O(1)
    @param itemId number
    @return table|nil  ItemConfig 中对应的行，找不到返回 nil
]]
function MergeConfig:GetItemConfig(itemId)
    if not _itemMap then
        self:BuildItemMap()
    end
    return _itemMap[itemId]
end

--[[
    获取合成结果的 itemId，O(1)
    @param itemId number  源物品 id
    @return number|nil    合成后的 itemId，不可合成返回 nil
]]
function MergeConfig:GetMergeResult(itemId)
    if not _mergeMap then
        self:BuildItemMap()
    end
    return _mergeMap[itemId]
end

--[[
    判断两个物品是否可以合成
    规则：同 id、同 level、有 next_composite、type 不是 coin
    @param itemA table  GridItem 对象
    @param itemB table  GridItem 对象
    @return boolean
]]
--[[
    判断两个物品是否可以合成（含格子状态检查）
    - itemA（拖拽方）：cellState=LOCKED(1) 或 DUSTY(2) → 不可发起合成
    - itemB（目标方）：cellState=LOCKED(1) → 不可作为合成目标
                       cellState=DUSTY(2)  → 可作为合成目标（被相同物品合并消除）
]]
function MergeConfig:CanMerge(itemA, itemB)
    if not itemA or not itemB then return false end
    if itemA.type == self.ItemType.COIN or itemB.type == self.ItemType.COIN then
        return false
    end

    -- 格子状态检查（cellState 字段由 GridManager:SetItem 写入）
    local stateA = itemA.cellState or 4
    local stateB = itemB.cellState or 4
    -- 拖拽方 LOCKED(1) 或 DUSTY(2) 不可发起
    if stateA == 1 or stateA == 2 then return false end
    -- 目标方 LOCKED(1) 不可被合成
    if stateB == 1 then return false end

    if itemA.id ~= itemB.id then return false end
    if itemA.level ~= itemB.level then return false end
    if not self:GetMergeResult(itemA.id) then return false end
    return true
end

-- ==================== 坐标辅助 ====================

--[[
    行列 → 格子索引（1-based）
    row=1, col=1 → index=1
    row=1, col=9 → index=9
    row=7, col=9 → index=63
]]
function MergeConfig:GetGridIndex(row, col)
    return (row - 1) * self.Grid.cols + col
end

--[[
    格子索引 → 行列
    index=1  → row=1, col=1
    index=9  → row=1, col=9
    index=10 → row=2, col=1
]]
function MergeConfig:GetRowCol(index)
    local row = math.ceil(index / self.Grid.cols)
    local col = index - (row - 1) * self.Grid.cols
    return row, col
end

--[[
    行列 → UI 坐标（格子左上角，相对于棋盘格原点）
]]
function MergeConfig:GetGridPosition(row, col)
    local step = self.Grid.cellSize + self.Grid.spacing
    local x    = (col - 1) * step
    local y    = -(row - 1) * step
    return x, y
end

--[[
    检查行列是否在有效范围内
]]
function MergeConfig:IsValidGrid(row, col)
    return row >= 1 and row <= self.Grid.rows
       and col >= 1 and col <= self.Grid.cols
end

--[[
    获取总格子数
]]
function MergeConfig:GetTotalGrids()
    return self.Grid.rows * self.Grid.cols
end

--[[
    获取某格子周围可解锁的邻格坐标列表（8方向）
    @param centerRow number
    @param centerCol number
    @return table  { {row, col}, ... }
]]
function MergeConfig:GetUnlockPositions(centerRow, centerCol)
    local positions = {}
    local dirs = {
        { -1,  0 }, {  1,  0 }, {  0, -1 }, {  0,  1 },
        { -1, -1 }, { -1,  1 }, {  1, -1 }, {  1,  1 },
    }
    for _, d in ipairs(dirs) do
        local r = centerRow + d[1]
        local c = centerCol + d[2]
        if self:IsValidGrid(r, c) then
            table.insert(positions, { row = r, col = c })
        end
    end
    return positions
end

--[[
    根据等级获取随机物品ID（排除coin类型）
    @param level number 物品等级
    @return number|nil 物品ID，找不到返回nil
]]
function MergeConfig:GetRandomItemByLevel(level)
    if not ItemConfig then return nil end

    local itemsOfLevel = {}
    for _, cfg in ipairs(ItemConfig) do
        if cfg.level == level and cfg.type ~= "coin" then
            table.insert(itemsOfLevel, cfg.id)
        end
    end

    if #itemsOfLevel == 0 then return nil end
    local idx = UnityEngine.Random.Range(1, #itemsOfLevel + 1)
    return itemsOfLevel[idx]
end

return MergeConfig
