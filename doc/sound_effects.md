# 音效需求文档

## 概述

本文档列出游戏所有需要音效的地方，按场景和功能分类。

---

## 一、备战阶段 (GameBoard)

### 1.1 角色操作

| 音效名称 | 触发时机 | 说明 |
|---------|---------|------|
| `sfx_spawn.wav` | 点击生成战士/法师/牧师按钮 | 生成新角色 |
| `sfx_select.wav` | 点击选中角色 | 选中棋盘上的角色 |
| `sfx_drag_start.wav` | 开始拖拽角色 | 按下鼠标拖拽 |
| `sfx_drag_drop.wav` | 放下角色 | 释放鼠标放置 |
| `sfx_swap.wav` | 两个角色交换位置 | 不同角色交换 |
| `sfx_merge.wav` | 合成成功 | 同职业同等级角色合成 |
| `sfx_sacrifice.wav` | 献祭角色 | 右键献祭或点击献祭按钮 |
| `sfx_move.wav` | 角色移动到空格子 | 移动到空位置 |

### 1.2 界面交互

| 音效名称 | 触发时机 | 说明 |
|---------|---------|------|
| `sfx_button_click.wav` | 点击任何按钮 | 通用按钮点击 |
| `sfx_panel_open.wav` | 打开面板 | 打开宿舍/商店/遗物面板 |
| `sfx_panel_close.wav` | 关闭面板 | 关闭面板 |
| `sfx_item_use.wav` | 使用道具 | 在角色身上使用道具 |
| `sfx_item_equip.wav` | 装备遗物 | 获得新遗物 |

### 1.3 商店相关

| 音效名称 | 触发时机 | 说明 |
|---------|---------|------|
| `sfx_shop_buy.wav` | 购买成功 | 购买道具或遗物 |
| `sfx_shop_refund.wav` | 退款 | 金币不足或取消购买 |
| `sfx_gold_change.wav` | 金币变化 | 获得或消耗金币 |

### 1.4 宿舍相关

| 音效名称 | 触发时机 | 说明 |
|---------|---------|------|
| `sfx_dorm_store.wav` | 存入宿舍 | 角色存入宿舍 |
| `sfx_dorm_take.wav` | 取出宿舍 | 角色从宿舍取出 |

---

## 二、战斗阶段 (BattleScene)

### 2.1 战斗动作

| 音效名称 | 触发时机 | 说明 |
|---------|---------|------|
| `sfx_attack_fire.wav` | 发射攻击子弹 | 角色发起攻击 |
| `sfx_bullet_hit.wav` | 子弹命中目标 | 子弹击中敌人或角色 |
| `sfx_character_hurt.wav` | 角色受伤 | 角色受到伤害 |
| `sfx_character_death.wav` | 角色死亡 | 角色血量归零 |
| `sfx_heal.wav` | 治疗生效 | 治疗子弹命中 |
| `sfx_bless.wav` | 祝福生效 | 祝福子弹命中 |
| `sfx_enemy_attack.wav` | 敌人攻击 | 敌人发射子弹 |
| `sfx_enemy_hit.wav` | 敌人受伤 | 敌人受到伤害 |

### 2.2 战斗结果

| 音效名称 | 触发时机 | 说明 |
|---------|---------|------|
| `sfx_battle_start.wav` | 战斗开始 | 进入战斗 |
| `sfx_victory.wav` | 战斗胜利 | 击败敌人 |
| `sfx_defeat.wav` | 战斗失败 | 我方全灭 |
| `sfx_level_up.wav` | 角色升级 | 战斗中获得经验 |

### 2.3 战斗界面

| 音效名称 | 触发时机 | 说明 |
|---------|---------|------|
| `sfx_turn_change.wav` | 回合切换 | 攻击/受击回合变化 |
| `sfx_buff_apply.wav` | Buff应用 | 获得增益或减益 |

---

## 三、其他场景

### 3.1 主菜单

| 音效名称 | 触发时机 | 说明 |
|---------|---------|------|
| `sfx_menu_start.wav` | 开始游戏 | 点击开始游戏 |
| `sfx_menu_select.wav` | 菜单选择 | 切换选项 |

### 3.2 结算界面

| 音效名称 | 触发时机 | 说明 |
|---------|---------|------|
| `sfx_chest_open.wav` | 打开宝箱 | 战斗奖励结算 |
| `sfx_relic_get.wav` | 获得遗物 | 获得新遗物 |

---

## 四、音效规格建议

### 文件格式
- 格式: `Ogg Vorbis (.ogg)` 或 `WAV (.wav)`
- 采样率: 44100Hz
- 位深度: 16-bit
- 声道: 单声道或立体声

### 时长建议
- 短音效 (按钮点击): 50-200ms
- 中等音效 (攻击命中): 200-500ms
- 长音效 (胜利/失败): 1-3s

### 命名规范
```
sfx_[场景]_[动作].ogg
例如:
  sfx_gameboard_spawn.wav
  sfx_battle_attack_fire.wav
  sfx_ui_button_click.wav
```

### 存放位置
```
res://art/audio/
├── sfx/
│   ├── ui/
│   │   └── sfx_button_click.ogg
│   ├── gameboard/
│   │   ├── sfx_spawn.ogg
│   │   ├── sfx_merge.ogg
│   │   └── sfx_sacrifice.ogg
│   └── battle/
│       ├── sfx_attack_fire.ogg
│       ├── sfx_bullet_hit.ogg
│       └── sfx_victory.ogg
├── bgm/
│   ├── menu_theme.ogg
│   ├── battle_theme.ogg
│   └── victory_theme.ogg
└── ambient/
    └── battle_ambient.ogg
```

---

## 五、优先级建议

### 高优先级 (核心体验)
1. `sfx_button_click` - 按钮反馈
2. `sfx_merge` - 合成反馈
3. `sfx_attack_fire` - 攻击反馈
4. `sfx_bullet_hit` - 命中反馈
5. `sfx_victory` - 胜利反馈

### 中优先级 (增强体验)
6. `sfx_sacrifice` - 献祭反馈
7. `sfx_spawn` - 生成反馈
8. `sfx_character_hurt` - 受伤反馈
9. `sfx_heal` - 治疗反馈
10. `sfx_shop_buy` - 购买反馈

### 低优先级 (可选)
11. `sfx_drag_start` / `sfx_drag_drop`
12. `sfx_swap`
13. `sfx_level_up`
14. `sfx_defeat`
15. `sfx_panel_open` / `sfx_panel_close`
