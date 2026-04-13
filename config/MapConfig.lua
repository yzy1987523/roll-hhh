--[[

]]--

-- ==================== 格子状态枚举 ====================
-- 与 MergeConfig.GridState 保持一致
local GridState = {
    LOCKED   = 1,   -- 锁定（未解锁）
    DUSTY    = 2,   -- 半锁定（可清理解锁）
    OCCUPIED = 3,   -- 已被物品占用
    EMPTY    = 4,   -- 空置（已解锁）
}

MapConfig =
{
--        1列，      2列，     3列，      4列，     5列，     6列，     7列，      8列，     9列，
    { { id=01070104, state=GridState.LOCKED }, { id=01070102, state=GridState.LOCKED }, { id=01070101, state=GridState.LOCKED }, { id=01030104, state=GridState.LOCKED }, { id=01030103, state=GridState.LOCKED }, { id=01060102, state=GridState.LOCKED }, { id=01060201, state=GridState.LOCKED }, { id=01060202, state=GridState.LOCKED }, { id=01060103, state=GridState.LOCKED } },  --第1行

    { { id=01070104, state=GridState.LOCKED }, { id=01070101, state=GridState.LOCKED }, { id=01030105, state=GridState.LOCKED }, { id=01030202, state=GridState.LOCKED }, { id=01030102, state=GridState.LOCKED }, { id=01030101, state=GridState.LOCKED }, { id=01060102, state=GridState.LOCKED }, { id=01060101, state=GridState.LOCKED }, { id=01060202, state=GridState.LOCKED } },  --第2行

    { { id=01070103, state=GridState.LOCKED }, { id=01010104, state=GridState.LOCKED }, { id=01010107, state=GridState.LOCKED }, { id=01010105, state=GridState.LOCKED }, { id=01012101, state=GridState.OCCUPIED }, { id=01030201, state=GridState.LOCKED }, { id=01050202, state=GridState.LOCKED }, { id=01050201, state=GridState.LOCKED }, { id=01050104, state=GridState.LOCKED } },  --第3行（5列可操作）

    { { id=01070106, state=GridState.LOCKED }, { id=01010105, state=GridState.LOCKED }, { id=01010103, state=GridState.LOCKED }, { id=01010102, state=GridState.LOCKED }, { id=01012101, state=GridState.OCCUPIED }, { id=01010101, state=GridState.LOCKED }, { id=01050101, state=GridState.LOCKED }, { id=01050102, state=GridState.LOCKED }, { id=01050103, state=GridState.LOCKED } },  --第4行（5列可操作）

    { { id=01070107, state=GridState.LOCKED }, { id=01010102, state=GridState.LOCKED }, { id=01010202, state=GridState.LOCKED }, { id=01010201, state=GridState.LOCKED }, { id=01012102, state=GridState.DUSTY   }, { id=01012103, state=GridState.LOCKED }, { id=01040105, state=GridState.LOCKED }, { id=01040103, state=GridState.LOCKED }, { id=01040107, state=GridState.LOCKED } },  --第5行（5列蒙尘）

    { { id=01020102, state=GridState.LOCKED }, { id=01020202, state=GridState.LOCKED }, { id=01020102, state=GridState.LOCKED }, { id=01012201, state=GridState.LOCKED }, { id=01020103, state=GridState.LOCKED }, { id=01020104, state=GridState.LOCKED }, { id=01040101, state=GridState.LOCKED }, { id=01040102, state=GridState.LOCKED }, { id=01040106, state=GridState.LOCKED } },  --第6行

    { { id=01020102, state=GridState.LOCKED }, { id=01020201, state=GridState.LOCKED }, { id=01020101, state=GridState.LOCKED }, { id=01012202, state=GridState.LOCKED }, { id=01012203, state=GridState.LOCKED }, { id=01020105, state=GridState.LOCKED }, { id=01040105, state=GridState.LOCKED }, { id=01040103, state=GridState.LOCKED }, { id=01040103, state=GridState.LOCKED } },  --第7行

}
