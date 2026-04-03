# 战斗界面调整计划

## 任务概述
调整战斗界面，使其更接近备战界面的风格，同时优化敌人显示区域。

## 资源信息
- **背景图**: `res://art/sprites/UI/panels/bg_1.png`
- **敌人精灵**: `res://art/sprites/UI/items/enemy/normal/` 和 `elite/`
- **敌人配置**: `configs/enemy_definitions.json` (ID 1-14普通, 15-18精英, 19-20 BOSS)

## 任务列表

### Task 1: 隐藏战斗日志
- 隐藏 `LogScroll` 节点
- 移除日志占用的空间

### Task 2: 添加背景图
- 添加 `Sprite2D` 显示 `bg_1.png`
- 设置在 `BgColor` 上层

### Task 3: 重构敌人显示区域
- 创建新的水平布局：
  - 左侧: 敌人精灵图 (居左对齐)
  - 右侧: 敌人信息面板 (血条、攻防、特技名和解释)
- 敌人精灵路径格式: `res://art/sprites/UI/items/enemy/{category}/enemy_{id:03d}.png`

### Task 4: 更新棋盘格样式
- 参考 `game_board.gd` 的格子样式
- 使用纹理背景 `cell_0.png`
- 设置灰度颜色 (0.5/0.8) 和透明度 (0.9/0.7)

### Task 5: 调整整体布局
- 移除原来的 `BattleInfoBar` 布局
- 敌人区域放在上方
- 棋盘格偏下，让出敌人区域

### Task 6: 保留玩家信息
- 简化显示或移到底部

## 详细实现步骤

### Step 1: 场景结构修改
```diff
MainLayout (VBoxContainer)
├── ControlBar (保持)
+ ├── BgSprite (新增背景图)
+ ├── EnemyArea (新增敌人区域)
│   ├── EnemySprite
│   └── EnemyInfoPanel
- ├── BattleInfoBar (删除或重构)
├── BoardCenter (保持，调整位置)
- ├── LogScroll (隐藏)
└── BottomPanel (保持)
```

### Step 2: 脚本修改要点
1. 添加敌人精灵节点引用
2. 添加 `_update_enemy_sprite()` 函数
3. 加载敌人图片: `enemy_{id:03d}.png`
4. 显示特技信息（从 `enemy_definitions.json` 获取）

### Step 3: 棋盘格样式
```gdscript
# 参考 game_board.gd
const CELL_BG_TEXTURE := preload("res://art/sprites/UI/items/smallItem/cell_0.png")
bg.modulate = Color(0.5, 0.5, 0.5, 0.9) if is_even else Color(0.8, 0.8, 0.8, 0.7)
```

## 预估工作量
- 场景修改: ~45分钟
- 脚本修改: ~60分钟
- 测试调整: ~20分钟
- 总计: 约2小时
