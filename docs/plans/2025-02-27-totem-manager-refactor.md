# TotemManager 重构实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 删除特化的 SoulManager，重构为高度泛化的 TotemManager，通过键值对结构接管所有图腾状态，并解耦 GameManager 的遗物硬编码。

**Architecture:** 创建新的 TotemManager 单例，使用 Dictionary 存储 `resources[totem_id] = {"current": int, "max": int, "default_max": int}` 结构。提供通用接口（add_resource, get_resource, modify_max_resource, clear_resource），自动初始化未知 totem_id。遗物效果泛化为"增加当前图腾资源上限"。

**Tech Stack:** Godot 4.x, GDScript

---

## Task 1: 创建 TotemManager 单例

**Files:**
- Create: `src/Autoload/TotemManager.gd`

**Step 1: 创建 TotemManager 文件**

```gdscript
extends Node

signal totem_resource_changed(totem_id: String, current: int, max_value: int)

# 资源存储结构: resources[totem_id] = {"current": int, "max": int, "default_max": int}
var resources: Dictionary = {}

const DEFAULT_MAX_VALUES: Dictionary = {
    "wolf": 500,
    "cow": 999999,
}

func _get_or_create_resource(totem_id: String) -> Dictionary:
    """获取或创建图腾资源条目，确保绝不返回 null"""
    if not resources.has(totem_id):
        var default_max = DEFAULT_MAX_VALUES.get(totem_id, 999999)
        resources[totem_id] = {
            "current": 0,
            "max": default_max,
            "default_max": default_max
        }
    return resources[totem_id]

func add_resource(totem_id: String, amount: int) -> void:
    """增加图腾资源当前值（不超过上限）"""
    var res = _get_or_create_resource(totem_id)
    res.current = min(res.current + amount, res.max)
    totem_resource_changed.emit(totem_id, res.current, res.max)

func get_resource(totem_id: String) -> int:
    """获取图腾资源当前值"""
    var res = _get_or_create_resource(totem_id)
    return res.current

func get_max_resource(totem_id: String) -> int:
    """获取图腾资源上限"""
    var res = _get_or_create_resource(totem_id)
    return res.max

func modify_max_resource(totem_id: String, amount: int) -> void:
    """修改图腾资源上限"""
    var res = _get_or_create_resource(totem_id)
    res.max += amount
    totem_resource_changed.emit(totem_id, res.current, res.max)

func clear_resource(totem_id: String) -> void:
    """清零图腾资源当前值"""
    var res = _get_or_create_resource(totem_id)
    res.current = 0
    totem_resource_changed.emit(totem_id, 0, res.max)

func set_resource(totem_id: String, amount: int) -> void:
    """直接设置图腾资源当前值（不超过上限）"""
    var res = _get_or_create_resource(totem_id)
    res.current = min(amount, res.max)
    totem_resource_changed.emit(totem_id, res.current, res.max)
```

**Step 2: 验证文件创建成功**

Run: `ls -la src/Autoload/TotemManager.gd`
Expected: 文件存在

**Step 3: Commit**

```bash
git add src/Autoload/TotemManager.gd
git commit -m "feat: create TotemManager singleton with generic resource interface"
```

---

## Task 2: 更新 project.godot 替换 Autoload

**Files:**
- Modify: `project.godot`

**Step 1: 替换 SoulManager 为 TotemManager**

在 `[autoload]` 部分，将：
```ini
SoulManager="*res://src/Autoload/SoulManager.gd"
```
替换为：
```ini
TotemManager="*res://src/Autoload/TotemManager.gd"
```

**Step 2: 验证修改**

Run: `grep -A 10 "\[autoload\]" project.godot`
Expected: 显示 TotemManager，不显示 SoulManager

**Step 3: Commit**

```bash
git add project.godot
git commit -m "chore: replace SoulManager with TotemManager in autoload"
```

---

## Task 3: 删除 SoulManager.gd

**Files:**
- Delete: `src/Autoload/SoulManager.gd`

**Step 1: 删除文件**

```bash
rm src/Autoload/SoulManager.gd
```

**Step 2: 验证删除**

Run: `ls src/Autoload/`
Expected: SoulManager.gd 不存在

**Step 3: Commit**

```bash
git add src/Autoload/SoulManager.gd
git commit -m "chore: remove SoulManager (replaced by TotemManager)"
```

---

## Task 4: 重构 MechanicWolfTotem.gd

**Files:**
- Modify: `src/Scripts/CoreMechanics/MechanicWolfTotem.gd`

**Step 1: 读取当前文件内容**

Run: `cat src/Scripts/CoreMechanics/MechanicWolfTotem.gd`

**Step 2: 修改 MechanicWolfTotem.gd**

完整替换为：

```gdscript
class_name MechanicWolfTotem
extends BaseTotemMechanic

@export var attack_interval: float = 5.0
@export var base_damage: int = 15

const TOTEM_ID: String = "wolf"

func _ready():
    var timer = Timer.new()
    timer.wait_time = attack_interval
    timer.timeout.connect(_on_totem_attack)
    add_child(timer)
    timer.start()

    # 连接信号以获取魂魄
    GameManager.enemy_died.connect(_on_enemy_died)
    GameManager.unit_upgraded.connect(_on_unit_upgraded)

func _on_enemy_died(_enemy, _killer_unit):
    """击杀敌人时增加魂魄"""
    TotemManager.add_resource(TOTEM_ID, 1)

func _on_unit_upgraded(_unit, _old_level, _new_level):
    """单位合成/升级时增加魂魄"""
    TotemManager.add_resource(TOTEM_ID, 10)

func _on_totem_attack():
    var targets = get_nearest_enemies(3)
    var soul_bonus = TotemManager.get_resource(TOTEM_ID)
    for enemy in targets:
        var damage = base_damage + soul_bonus
        deal_damage(enemy, damage)
```

**Step 3: 验证修改**

Run: `grep -n "TotemManager" src/Scripts/CoreMechanics/MechanicWolfTotem.gd`
Expected: 显示 TotemManager 调用

**Step 4: Commit**

```bash
git add src/Scripts/CoreMechanics/MechanicWolfTotem.gd
git commit -m "refactor: MechanicWolfTotem use TotemManager instead of SoulManager"
```

---

## Task 5: 重构 MechanicCowTotem.gd

**Files:**
- Modify: `src/Scripts/CoreMechanics/MechanicCowTotem.gd`

**Step 1: 读取当前文件内容**

Run: `cat src/Scripts/CoreMechanics/MechanicCowTotem.gd`

**Step 2: 修改 MechanicCowTotem.gd**

完整替换为：

```gdscript
extends "res://src/Scripts/CoreMechanics/CoreMechanic.gd"

var timer: Timer
const TOTEM_ID: String = "cow"

func _ready():
    timer = Timer.new()
    timer.wait_time = 5.0
    timer.autostart = true
    timer.one_shot = false
    timer.timeout.connect(_on_timer_timeout)
    add_child(timer)

func on_core_damaged(_amount: float):
    """核心受击时增加层数"""
    TotemManager.add_resource(TOTEM_ID, 1)

func _on_timer_timeout():
    var hit_count = TotemManager.get_resource(TOTEM_ID)
    var damage = hit_count * 5.0

    print("[CowTotem] Timeout. Hits: ", hit_count, " Damage: ", damage)

    # 清零层数（必须在计算伤害后）
    TotemManager.clear_resource(TOTEM_ID)

    if damage > 0:
        if GameManager.combat_manager:
            print("[CowTotem] Dealing global damage...")
            GameManager.combat_manager.deal_global_damage(damage, "magic")

        # Visual feedback
        GameManager.trigger_impact(Vector2.ZERO, 1.0)
        GameManager.spawn_floating_text(Vector2.ZERO, "Cow Totem: %d" % damage, Color.RED)
```

**Step 3: 验证修改**

Run: `grep -n "TotemManager\|hit_count" src/Scripts/CoreMechanics/MechanicCowTotem.gd`
Expected: 显示 TotemManager 调用，不显示 `var hit_count`

**Step 4: Commit**

```bash
git add src/Scripts/CoreMechanics/MechanicCowTotem.gd
git commit -m "refactor: MechanicCowTotem use TotemManager, remove hit_count variable"
```

---

## Task 6: 重构 GameManager.gd - 解耦遗物效果

**Files:**
- Modify: `src/Autoload/GameManager.gd`

**Step 1: 修改 _on_enemy_died 函数**

找到 `_on_enemy_died` 函数（约第179-192行），替换为：

```gdscript
func _on_enemy_died(enemy, killer_unit):
    """
    敌人死亡时触发，处理灵魂捕手效果
    泛化效果: 增加当前图腾的资源上限
    """
    if reward_manager and "soul_catcher" in reward_manager.acquired_artifacts:
        soul_catcher_kills += 1
        soul_catcher_bonus += 1
        # 泛化遗物效果: 增加当前图腾的资源上限
        if core_type:
            TotemManager.modify_max_resource(core_type, 1)
            print("[GameManager] 灵魂捕手触发: %s 图腾资源上限+1 (总计+%d)" % [core_type, soul_catcher_bonus])
```

**Step 2: 删除 _setup_soul_catcher 函数（如不再需要）**

检查 `_setup_soul_catcher` 函数（约第172-177行）是否在其他地方被调用。如果没有被调用，删除该函数。

**Step 3: 验证修改**

Run: `grep -n "TotemManager\|SoulManager" src/Autoload/GameManager.gd`
Expected: 只显示 TotemManager，不显示 SoulManager

**Step 4: Commit**

```bash
git add src/Autoload/GameManager.gd
git commit -m "refactor: GameManager use TotemManager, remove SoulManager coupling"
```

---

## Task 7: 检查并清理其他 SoulManager 引用

**Files:**
- Search: 整个项目

**Step 1: 搜索 SoulManager 引用**

Run: `grep -r "SoulManager" --include="*.gd" src/`
Expected: 无输出（或只有注释）

**Step 2: 如有残留，逐一清理**

如果找到任何 SoulManager 引用，分析并替换为 TotemManager。

**Step 3: Commit（如有修改）**

```bash
git add -A
git commit -m "chore: clean up remaining SoulManager references"
```

---

## Task 8: 运行 Godot 语法检查

**Files:**
- All modified .gd files

**Step 1: 使用 Godot 命令行检查语法**

Run: `godot --headless --check-only project.godot 2>&1 || echo "Check completed with warnings/errors"`
Expected: 无语法错误（可能有警告）

或者手动检查关键文件：
```bash
# 检查 GDScript 语法（Godot 4.x）
for file in src/Autoload/TotemManager.gd src/Autoload/GameManager.gd src/Scripts/CoreMechanics/MechanicWolfTotem.gd src/Scripts/CoreMechanics/MechanicCowTotem.gd; do
    echo "Checking $file..."
    # 基本语法检查：确保文件可解析
done
```

**Step 2: 修复任何语法错误**

如有错误，根据错误信息修复。

---

## Task 9: 最终验证和提交

**Files:**
- All modified files

**Step 1: 查看所有修改**

Run: `git diff --stat HEAD~8..HEAD`
Expected: 显示所有相关文件的修改

**Step 2: 运行游戏测试（如可能）**

如果环境支持，运行游戏测试基本功能：
- 狼图腾攻击时伤害随魂魄增加
- 击杀敌人增加魂魄
- 牛图腾受击后结算伤害
- 灵魂捕手遗物增加上限

**Step 3: 最终提交总结**

```bash
# 确保所有修改已提交
git status
```

---

## 实现后检查清单

- [ ] TotemManager.gd 创建完成，包含所有通用接口
- [ ] project.godot 中 SoulManager 替换为 TotemManager
- [ ] SoulManager.gd 已删除
- [ ] MechanicWolfTotem.gd 使用 TotemManager
- [ ] MechanicCowTotem.gd 使用 TotemManager，移除 hit_count
- [ ] GameManager._on_enemy_died 使用 TotemManager.modify_max_resource
- [ ] 项目中无 SoulManager 残留引用
- [ ] Godot 语法检查通过

## 注意事项

1. **狼图腾信号连接**: 新的 MechanicWolfTotem 在 `_ready()` 中连接 `GameManager.enemy_died` 和 `unit_upgraded` 信号，确保能获取魂魄。

2. **牛图腾清零时机**: `clear_resource` 在伤害计算之后调用，确保结算正确。

3. **灵魂捕手泛化**: 现在增加的是当前激活图腾的资源上限，不再硬编码为魂魄。

4. **自动初始化**: TotemManager 对所有未知 totem_id 自动初始化，未来添加新图腾无需修改 TotemManager。
