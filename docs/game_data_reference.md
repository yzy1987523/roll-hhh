# 游戏数据参考

## 敌人 (Enemies)

| ID | 名称     | 类别 | 描述                                     | 图片路径                                           |
| -- | -------- | ---- | ---------------------------------------- | -------------------------------------------------- |
| 1  | 史莱姆   | 普通 | 一种凝胶状生物，受到攻击时会分裂。       | `res://art/sprites/UI/items/enemy/enemy_001.png` |
| 2  | 哥布林   | 普通 | 使用简陋武器的小型绿皮生物。             | `res://art/sprites/UI/items/enemy/enemy_002.png` |
| 3  | 野狼     | 普通 | 成群狩猎的野兽。                         | `res://art/sprites/UI/items/enemy/enemy_003.png` |
| 4  | 骷髅     | 普通 | 不知疲倦、感受不到疼痛的亡灵战士。       | `res://art/sprites/UI/items/enemy/enemy_004.png` |
| 5  | 兽人     | 普通 | 拥有巨大力量的绿皮野兽。                 | `res://art/sprites/UI/items/enemy/enemy_005.png` |
| 6  | 暗法师   | 普通 | 引导暗能量的咒术师。                     | `res://art/sprites/UI/items/enemy/enemy_006.png` |
| 7  | 巨魔     | 普通 | 能够自我恢复的生物。                     | `res://art/sprites/UI/items/enemy/enemy_007.png` |
| 8  | 鹰身女妖 | 普通 | 从空中发起攻击的翼魔。                   | `res://art/sprites/UI/items/enemy/enemy_008.png` |
| 9  | 石魔像   | 普通 | 由石头构成的构装体，移动缓慢但极其耐用。 | `res://art/sprites/UI/items/enemy/enemy_009.png` |
| 10 | 吸血蝙蝠 | 普通 | 通过咬噬吸取血液的飞行生物。             | `res://art/sprites/UI/items/enemy/enemy_010.png` |
| 11 | 毒蝎     | 普通 | 拥有致命毒刺的大型蝎子。                 | `res://art/sprites/UI/items/enemy/enemy_011.png` |
| 12 | 小恶魔   | 普通 | 成群攻击的调皮小恶魔。                   | `res://art/sprites/UI/items/enemy/enemy_012.png` |
| 13 | 食人魔   | 普通 | 用拳头粉碎敌人的大型蠢笨生物。           | `res://art/sprites/UI/items/enemy/enemy_013.png` |
| 14 | 幽灵战士 | 普通 | 能够穿透攻击的灵魂战士。                 | `res://art/sprites/UI/items/enemy/enemy_014.png` |
| 15 | 黑暗骑士 | 精英 | 被黑暗力量腐化的骑士，手持诅咒之剑。     | `res://art/sprites/UI/items/enemy/enemy_015.png` |
| 16 | 火焰法师 | 精英 | 掌握火焰魔法的法师，能够焚毁整个战场。   | `res://art/sprites/UI/items/enemy/enemy_016.png` |
| 17 | 死亡使者 | 精英 | 驱使亡灵作战的亡灵法师。                 | `res://art/sprites/UI/items/enemy/enemy_017.png` |
| 18 | 风暴巨人 | 精英 | 被雷电之力加持的巨人。                   | `res://art/sprites/UI/items/enemy/enemy_018.png` |
| 19 | 龙之领主 | BOSS | 吐息火焰与毁灭的龙族之王。               | `res://art/sprites/UI/items/enemy/enemy_019.png` |
| 20 | 恶魔之王 | BOSS | 统治地狱的最高恶魔领主。                 | `res://art/sprites/UI/items/enemy/enemy_020.png` |

---

## 道具 (Items)

> ⚠️ **图片状态说明**：
>
> - ID 1-22：配置文件中定义了sprite名称(如 `element00_001`)，但对应图片文件**缺失**
> - ID 23-42：有实际图片文件(`item_023.png` ~ `item_042.png`)，但无本地化名称

| ID | 名称       | 价格 | 描述                    | 精灵名        | 图片状态           |
| -- | ---------- | ---- | ----------------------- | ------------- | ------------------ |
| 1  | 小血瓶     | 10   | 指定角色回复5血量       | element00_001 | ❌ 缺失            |
| 2  | 中血瓶     | 18   | 指定角色回复10血量      | element00_002 | ❌ 缺失            |
| 3  | 大血瓶     | 30   | 指定角色回复20血量      | element00_003 | ❌ 缺失            |
| 4  | 能量药水   | 20   | 立即恢复10能量          | element00_004 | ❌ 缺失            |
| 5  | 能量饮料   | 35   | 立即恢复20能量          | element00_005 | ❌ 缺失            |
| 6  | 角色礼包   | 50   | 随机生成2-3级角色×3    | element04_001 | ❌ 缺失            |
| 7  | 战士召唤符 | 30   | 生成1个3级战士          | element04_002 | ❌ 缺失            |
| 8  | 法师召唤符 | 30   | 生成1个3级法师          | element03_001 | ❌ 缺失            |
| 9  | 牧师召唤符 | 30   | 生成1个3级牧师          | element04_003 | ❌ 缺失            |
| 10 | 经验药水   | 30   | 随机1个角色升1级        | element05_001 | ❌ 缺失            |
| 11 | 高级经验书 | 45   | 指定角色升1级           | element05_002 | ❌ 缺失            |
| 12 | 直升卷轴   | 80   | 随机1个角色直升3级      | element05_003 | ❌ 缺失            |
| 13 | 临时护盾   | 20   | 指定角色获得5点临时护盾 | element02_001 | ❌ 缺失            |
| 14 | 攻击符印   | 20   | 指定角色攻击+2(本回合)  | element01_001 | ❌ 缺失            |
| 15 | 防御符印   | 20   | 指定角色防御+2(本回合)  | element02_002 | ❌ 缺失            |
| 16 | 无敌药水   | 40   | 指定角色本回合免疫伤害  | element02_003 | ❌ 缺失            |
| 17 | 献祭卷轴   | 40   | 本回合献祭返还翻倍      | element09_001 | ❌ 缺失            |
| 18 | 双重献祭符 | 80   | 本回合献祭返还×3       | element09_002 | ❌ 缺失            |
| 19 | 刷新令牌   | 20   | 商店商品刷新1次         | element08_001 | ❌ 缺失            |
| 20 | 商店折扣券 | 25   | 下次购买-30%            | element08_002 | ❌ 缺失            |
| 21 | 命运骰子   | 30   | 随机强化或弱化1个角色   | element03_001 | ❌ 缺失            |
| 22 | 时光沙漏   | 50   | 重置当前回合能量为满    | element00_006 | ❌ 缺失            |
| 23 | -          | 35   | 移除角色负面状态        | element5_010  | ✅`item_023.png` |
| 24 | -          | 35   | 移除全体负面状态        | element05_019 | ✅`item_024.png` |
| 25 | -          | 60   | 驱散敌人1个增益         | element05_020 | ✅`item_025.png` |
| 26 | -          | 80   | 驱散敌人2个增益         | element05_021 | ✅`item_026.png` |
| 27 | -          | 45   | 变形敌人1回合           | element06_001 | ✅`item_027.png` |
| 28 | -          | 100  | 沉默敌人                | element06_002 | ✅`item_028.png` |
| 29 | -          | 60   | 混乱敌人                | element06_003 | ✅`item_029.png` |
| 30 | -          | 150  | 变形敌人2回合           | element06_004 | ✅`item_030.png` |
| 31 | -          | 40   | 从敌人窃取5金币         | element06_016 | ✅`item_031.png` |
| 32 | -          | 70   | 从敌人窃取道具          | element06_017 | ✅`item_032.png` |
| 33 | -          | 50   | 转移负面状态给敌人      | element06_018 | ✅`item_033.png` |
| 34 | -          | 90   | 缴械敌人                | element06_019 | ✅`item_034.png` |
| 35 | -          | 200  | 复活角色(50%血量)       | element06_028 | ✅`item_035.png` |
| 36 | -          | 300  | 复活角色(满血)          | element06_029 | ✅`item_036.png` |
| 37 | -          | 55   | 重置角色技能冷却        | element06_030 | ✅`item_037.png` |
| 38 | -          | 75   | 清除角色负面效果        | element06_031 | ✅`item_038.png` |
| 39 | -          | 45   | 镜像伤害1回合           | element06_037 | ✅`item_039.png` |
| 40 | -          | 65   | 闪避下一次攻击          | element06_038 | ✅`item_040.png` |
| 41 | -          | 85   | 反击(150%伤害)          | element06_039 | ✅`item_041.png` |
| 42 | -          | 120  | 相位转移                | element06_040 | ✅`item_042.png` |

---

## 遗物 (Relics)

> ⚠️ **图片状态说明**：
>
> - 部分遗物图片缺失（ID 1-3, 10-19, 21-26）
> - 实际存在图片：ID 4-9, 20, 27-45

| ID | 名称       | 可叠加 | 描述                       | 精灵名        | 图片状态            |
| -- | ---------- | ------ | -------------------------- | ------------- | ------------------- |
| 1  | 战士护符   | 否     | 战士血量+2                 | element01_002 | ❌ 缺失             |
| 2  | 战士长靴   | 否     | 战士攻击+1                 | element01_003 | ❌ 缺失             |
| 3  | 战士头盔   | 否     | 战士防御+1                 | element02_004 | ❌ 缺失             |
| 4  | 法师权杖   | 否     | 法师攻击+1                 | element03_002 | ✅`relic_004.png` |
| 5  | 法师披风   | 否     | 法师穿透+1                 | element03_003 | ✅`relic_005.png` |
| 6  | 法师戒指   | 否     | 法师血量+1                 | element03_010 | ✅`relic_006.png` |
| 7  | 牧师圣典   | 否     | 牧师每回合额外回复1血      | element04_004 | ✅`relic_007.png` |
| 8  | 牧师十字架 | 否     | 牧师回复范围+1格           | element04_017 | ✅`relic_008.png` |
| 9  | 牧师长袍   | 否     | 牧师血量+2                 | element04_018 | ✅`relic_009.png` |
| 10 | 战斗号角   | 否     | 我方全员攻击+1             | element01_004 | ❌ 缺失             |
| 11 | 铁壁护盾   | 否     | 我方全员防御+1             | element02_013 | ❌ 缺失             |
| 12 | 生命之泉   | 否     | 我方全员血量上限+2         | element00_007 | ❌ 缺失             |
| 13 | 守护天使   | 否     | 首次致命伤害保留1血        | element05_011 | ❌ 缺失             |
| 14 | 复仇之魂   | 否     | 击杀后再攻击一次           | element01_005 | ❌ 缺失             |
| 15 | 金币袋     | 否     | 战斗胜利金币+20%           | element09_003 | ❌ 缺失             |
| 16 | 商店折扣卷 | 否     | 商店商品价格-15%           | element08_003 | ❌ 缺失             |
| 17 | 转职令牌   | 否     | 生成角色时5%概率转职       | element06_001 | ❌ 缺失             |
| 18 | 经验药水   | 否     | 生成角色时10%概率直升2级   | element06_002 | ❌ 缺失             |
| 19 | 能量护腕   | 否     | 初始能量上限+3             | element00_008 | ❌ 缺失             |
| 20 | 稀有召唤符 | 否     | 生成时5%概率直接3级        | element04_019 | ✅`relic_020.png` |
| 21 | 献祭之书   | 否     | 献祭能量返还+20%           | element09_004 | ❌ 缺失             |
| 22 | 灵魂收割者 | 否     | 献祭时额外获得1金币        | element09_005 | ❌ 缺失             |
| 23 | 穿透之箭   | 否     | 所有攻击额外+1穿透         | element01_006 | ❌ 缺失             |
| 24 | 免控护符   | 否     | 免疫敌方特技效果           | element06_003 | ❌ 缺失             |
| 25 | 连击之心   | 否     | 15%概率发动连击            | element01_007 | ❌ 缺失             |
| 26 | 战绩徽章   | 是     | 无效果,可叠加              | element06_004 | ❌ 缺失             |
| 27 | 狂暴之怒   | 否     | 低血量时攻击+5             | element03_001 | ✅`relic_027.png` |
| 28 | 奥术精通   | 否     | 攻击伤害+2,技能消耗-1      | element03_011 | ✅`relic_028.png` |
| 29 | 神圣祝福   | 否     | 30%概率死亡时回复5血       | element03_012 | ✅`relic_029.png` |
| 30 | 时间扭曲   | 否     | 15%概率获得额外回合        | element03_019 | ✅`relic_030.png` |
| 31 | 剧毒大师   | 否     | 攻击附加2层剧毒            | element03_020 | ✅`relic_031.png` |
| 32 | 燃烧大师   | 否     | 攻击造成2点燃烧伤害(2回合) | element03_021 | ✅`relic_032.png` |
| 33 | BOSS杀手   | 否     | 对BOSS伤害+50%,吸血30%     | element04_001 | ✅`relic_033.png` |
| 34 | 精英猎人   | 否     | 对精英伤害+30%,无视1防御   | element04_002 | ✅`relic_034.png` |
| 35 | 起始奖励   | 是     | 开局+5金币,+2经验          | element04_003 | ✅`relic_035.png` |
| 36 | 淘金热     | 否     | 击杀获得+3金币             | element04_020 | ✅`relic_036.png` |
| 37 | 盾墙       | 否     | 每回合开始获得3点护盾      | element04_031 | ✅`relic_037.png` |
| 38 | 伤害反射   | 否     | 受击时反弹20%伤害          | element04_032 | ✅`relic_038.png` |
| 39 | 刀锋舞者   | 否     | 20%概率额外攻击一次        | element04_033 | ✅`relic_039.png` |
| 40 | 处决       | 否     | 对20%血量以下敌人伤害翻倍  | element04_034 | ✅`relic_040.png` |
| 41 | 幸运星     | 否     | 暴击率+10%                 | element04_049 | ✅`relic_041.png` |
| 42 | 快手       | 否     | 商店折扣10%                | element04_050 | ✅`relic_042.png` |
| 43 | 成长之魂   | 否     | 升级时属性+1               | element04_051 | ✅`relic_043.png` |
| 44 | 无尽饥饿   | 否     | 击杀回复2血                | element04_052 | ✅`relic_044.png` |
| 45 | BOSS同伴   | 否     | 战斗开始召唤BOSS助战       | element05_002 | ✅`relic_045.png` |

---

## Sprite加载代码汇总

### 1. SpriteLoader（通用加载器）

**文件**: `scripts/sprite_loader.gd`

```gdscript
const BASE_PATH := "res://art/sprites/game_items/"  # ⚠️ 目录不存在！

# 方法：
static func get_item_sprite(item_id: int) -> Texture2D
static func get_relic_sprite(relic_id: int) -> Texture2D
```

**问题**: BASE_PATH 指向的目录不存在，导致道具/遗物图片加载失败

---

### 2. 角色精灵加载

**文件**: `scripts/data_models.gd` (Character类)

```gdscript
# 格式: char_{JJ}{LL}{AA}.png
# JJ=职业代码(01-09), LL=等级(01-13), AA=动画(01-02)
func get_sprite_path(anim_id: int = 1, _frame: int = 1) -> String
func get_sprite_folder() -> String  # 返回 "char_{JJ}"
```

**文件**: `scripts/game_board.gd`, `scripts/battle_scene.gd`

```gdscript
var sprite_path: String = "res://art/sprites/chars/" + sprite_folder + "/" + sprite_name + ".png"
# 实际路径: res://art/sprites/chars/char_01/char_010101.png
```

---

### 3. 敌人精灵加载

**文件**: `scripts/battle_scene.gd` (第900-957行)

```gdscript
# 格式: res://art/sprites/UI/items/enemy/{category}/enemy_{id:03d}.png
# category: normal, elite, boss
var sprite_path: String = "res://art/sprites/UI/items/enemy/%s/enemy_%03d.png" % [category, enemy_id]
```

---

### 4. 道具/遗物精灵加载（商店/战斗场景）

**文件**: `scripts/shop_scene.gd` (第224-252行)

```gdscript
# 可用图片ID列表（硬编码）
var available_item_ids := [13, 15, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42]
var available_relic_ids := [4, 5, 6, 7, 8, 9, 20, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45]

# 遗物映射: item.id % available_relic_ids.size()
# 道具映射: item.id % available_item_ids.size()
var img_id: int = available_relic_ids[item.id % available_relic_ids.size()]
var path := "res://art/sprites/UI/items/relic/relic_%03d.png" % img_id

# 加载失败时的fallback
if tex:
    return tex
return _create_color_texture(Color(0.4, 0.3, 0.5))  # 遗物：紫色
return _create_color_texture(Color(0.3, 0.4, 0.6))  # 道具：蓝色
```

**文件**: `scripts/battle_scene.gd` (第223-231行)

```gdscript
# 可用道具图片ID列表（硬编码）
var available_item_images := [13, 15, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42]

# 映射方式: item.id - 1 作为数组索引 ⚠️ 可能越界！
var img_id: int = available_item_images[item.id - 1]
var path := "res://art/sprites/UI/items/item/item_%03d.png" % img_id

# 加载失败时返回null，调用处隐藏图标
if ResourceLoader.exists(path):
    return load(path) as Texture2D
return null

# 使用时：
icon.texture = tex
icon.visible = (tex != null)  # 无图片则隐藏
```

var path := "res://art/sprites/UI/items/relic/relic_%03d.png" % img_id

# 道具: res://art/sprites/UI/items/item/item_.png

var path := "res://art/sprites/UI/items/item/item_%03d.png" % img_id

```

**文件**: `scripts/battle_scene.gd` (第227-230行)
```gdscript
# 道具: res://art/sprites/UI/items/item/item_{id:03d}.png
var path := "res://art/sprites/UI/items/item/item_%03d.png" % img_id
```

---

### 5. 子弹精灵加载

**文件**: `scripts/battle_bullet.gd` (第70-97行)

```gdscript
const BULLET_SPRITE_BASE_PATH: String = "res://art/sprites/UI/items/bullet/"
# 格式: bullet_{job}_{tier}.png
# job: 1=战士, 2=法师, 3=牧师, 4=敌人
var sprite_path: String = BULLET_SPRITE_BASE_PATH + "bullet_%d_%d.png" % [sprite_job, tier]
```

---

### 6. 图鉴角色精灵加载

**文件**: `scripts/encyclopedia_scene.gd` (第166-181行)

```gdscript
# 格式: res://art/sprites/chars/char_{char_type}/char_{char_type}{level:02d}01.png
var path := "res://art/sprites/chars/char_%02d/char_%02d%02d01.png" % [char_type, char_type, level]
```

---

### 7. UI元素精灵加载

**文件**: `scripts/battle_scene.gd`, `scripts/popup_system.gd`

```gdscript
# 预加载常量:
const CELL_BG_TEXTURE := preload("res://art/sprites/UI/items/smallItem/cell_0.png")
const CLOSE_TEXTURE := preload("res://art/sprites/UI/items/smallItem/close.png")
const POP_TEXTURE := preload("res://art/sprites/UI/items/smallItem/cell_0.png")
const CHECK_TEXTURE := preload("res://art/sprites/UI/items/smallItem/check.png")

# 图标:
load("res://art/sprites/UI/items/smallItem/attack.png")
load("res://art/sprites/UI/items/smallItem/defend.png")
preload("res://art/sprites/UI/items/smallItem/pause.png")
preload("res://art/sprites/UI/items/smallItem/play.png")
```

---

## 图片路径映射表

| 类型   | 基础路径                                  | 文件名格式                          | 示例                        |
| ------ | ----------------------------------------- | ----------------------------------- | --------------------------- |
| 角色   | `res://art/sprites/chars/`              | `char_{JJ}/char_{JJ}{LL}{AA}.png` | `char_01/char_010101.png` |
| 敌人   | `res://art/sprites/UI/items/enemy/`     | `{category}/enemy_{id:03d}.png`   | `normal/enemy_001.png`    |
| 道具   | `res://art/sprites/UI/items/item/`      | `item_{id:03d}.png`               | `item_023.png`            |
| 遗物   | `res://art/sprites/UI/items/relic/`     | `relic_{id:03d}.png`              | `relic_004.png`           |
| 子弹   | `res://art/sprites/UI/items/bullet/`    | `bullet_{job}_{tier}.png`         | `bullet_1_1.png`          |
| UI元素 | `res://art/sprites/UI/items/smallItem/` | `{name}.png`                      | `pause.png`               |

---

## 配置文件

- `configs/enemy_definitions.json` - 敌人定义
- `configs/mechanics.json` - 道具/遗物数据（含sprite字段）
- `configs/items.json` - 道具数据
- `configs/relics.json` - 遗物数据
- `configs/localization.json` - 本地化文本
- `configs/item_sprites.json` - 精灵映射

---

*生成时间: 2026-04-05*
