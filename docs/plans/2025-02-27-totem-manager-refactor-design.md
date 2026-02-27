# TotemManager 重构设计文档

## 背景

当前系统使用特化的 SoulManager 处理狼图腾的魂魄机制，而牛图腾使用独立的 hit_count 变量。这种设计导致：
- 代码耦合度高，GameManager 中硬编码 SoulManager 节点获取
- 扩展困难，新图腾需要新增管理器或硬编码变量
- 遗物效果（灵魂捕手）与特定系统绑定

## 设计目标

1. **完全泛化**: 通过键值对结构接管所有图腾的专属状态
2. **零硬编码**: 解除 GameManager 与 SoulManager 的耦合
3. **未来可扩展**: 新图腾只需调用接口，无需修改 TotemManager
4. **高可读性**: 简洁清晰的接口设计

## 架构设计

### 1. TotemManager 核心结构

```gdscript
extends Node

signal totem_resource_changed(totem_id: String, current: int, max_value: int)

# 资源存储结构
# resources[totem_id] = {"current": int, "max": int, "default_max": int}
var resources: Dictionary = {}

const DEFAULT_MAX_VALUES = {
    "wolf": 500,
    "cow": 999999,  # 牛图腾无上限概念，使用极大值
}
```

### 2. 通用接口设计

| 方法 | 用途 | 自动初始化 |
|------|------|-----------|
| `add_resource(totem_id, amount)` | 增加当前资源 | 是 |
| `get_resource(totem_id)` | 获取当前值 | 是 |
| `get_max_resource(totem_id)` | 获取上限 | 是 |
| `modify_max_resource(totem_id, amount)` | 修改上限 | 是 |
| `clear_resource(totem_id)` | 清零当前值 | 是 |
| `set_default_max(totem_id, value)` | 设置默认上限 | 是 |

**自动初始化原则**: 当访问不存在的 totem_id 时，自动初始化该图腾的默认值，绝不抛出 Null 异常。

### 3. 图腾接入方式

#### 狼图腾 (MechanicWolfTotem)
```gdscript
func _on_enemy_died(enemy, killer):
    TotemManager.add_resource("wolf", 1)

func _on_unit_merged(unit_data):
    TotemManager.add_resource("wolf", 10)

func _on_totem_attack():
    var bonus = TotemManager.get_resource("wolf")
    deal_damage(enemy, base_damage + bonus)
```

#### 牛图腾 (MechanicCowTotem)
```gdscript
func on_core_damaged(amount):
    TotemManager.add_resource("cow", 1)

func _on_timer_timeout():
    var hit_count = TotemManager.get_resource("cow")
    if hit_count > 0:
        deal_global_damage(hit_count * 5.0)
        TotemManager.clear_resource("cow")
```

#### 未来图腾（蝙蝠/毒蛇）
```gdscript
# 无需修改 TotemManager，直接调用
TotemManager.add_resource("bat", 1)
TotemManager.modify_max_resource("viper", 1)
```

### 4. 遗物效果泛化

**灵魂捕手 [soul_catcher]** 效果变更:

原实现（硬编码）:
```gdscript
# GameManager._on_enemy_died
if "soul_catcher" in artifacts:
    var sm = get_node("/root/SoulManager")
    sm.add_souls(1, "soul_catcher")
```

新实现（泛化）:
```gdscript
# GameManager._on_enemy_died
if "soul_catcher" in artifacts:
    # 增加当前图腾的资源上限
    TotemManager.modify_max_resource(core_type, 1)
```

**语义变更**: 从"增加魂魄上限"泛化为"增加当前图腾的资源上限"。这意味着：
- 使用狼图腾时: 增加魂魄上限
- 使用牛图腾时: 增加受击计数上限（无实际效果，但保持一致性）
- 使用蝙蝠图腾时: 增加血池上限

### 5. 数据结构示例

```gdscript
# 游戏运行中的资源状态
resources = {
    "wolf": {
        "current": 150,    # 当前魂魄数
        "max": 550,        # 上限（500基础 + 50灵魂捕手加成）
        "default_max": 500
    },
    "cow": {
        "current": 3,      # 当前受击层数
        "max": 999999,     # 无上限概念
        "default_max": 999999
    },
    "bat": {               # 未来扩展，自动初始化
        "current": 0,
        "max": 100,
        "default_max": 100
    }
}
```

## 信号设计

单一信号取代 SoulManager 的 `soul_count_changed`:

```gdscript
signal totem_resource_changed(totem_id: String, current: int, max_value: int)
```

UI 监听此信号，根据 totem_id 更新对应显示:
```gdscript
func _on_totem_resource_changed(totem_id, current, max_value):
    if totem_id == "wolf":
        update_soul_display(current, max_value)
    elif totem_id == "cow":
        update_hit_count_display(current)
```

## 删除和清理清单

1. **删除文件**: `src/Autoload/SoulManager.gd`
2. **修改 project.godot**: 替换 `SoulManager` autoload 为 `TotemManager`
3. **重构 GameManager**:
   - 删除 `_on_enemy_died` 中的 SoulManager 硬编码
   - 清理 `soul_catcher_kills`, `soul_catcher_bonus` 冗余变量（如不再需要）
   - 移除 `_setup_soul_catcher` 方法（如不再需要）
4. **重构 MechanicWolfTotem**:
   - 替换 SoulManager 调用为 TotemManager
   - 击杀敌人时调用 `add_resource("wolf", 1)`
   - 合成单位时调用 `add_resource("wolf", 10)`
5. **重构 MechanicCowTotem**:
   - 删除 `hit_count` 变量
   - 使用 `add_resource("cow", 1)` 替代 `hit_count += 1`
   - 使用 `get_resource("cow")` 和 `clear_resource("cow")` 替代直接访问

## 边界情况处理

1. **自动初始化**: 访问未知 totem_id 时自动创建默认值，绝不返回 null
2. **上限保护**: `add_resource` 不会超过 max 值
3. **下限保护**: 资源值不会低于 0
4. **重复清理**: `clear_resource` 可安全多次调用

## 兼容性考虑

1. 狼图腾的伤害计算逻辑保持不变（基础伤害 + 魂魄数）
2. 牛图腾的5秒结算周期保持不变
3. 灵魂捕手遗物的核心效果保持不变（击杀增加上限）
