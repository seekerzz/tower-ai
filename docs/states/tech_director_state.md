# Technical Director State

## [Inbox - 待办]

1. `[P0]` Boss 生成系统验证修复 - ✅ 代码审查完成
   - 状态：代码已正确实现，日志埋点正常 (`WaveSystemManager.gd:844`, `BossBehavior.gd:172`)
   - 阻塞：需要 Godot 环境运行测试，当前 headless 服务器无法运行
   - 人工验证点：启动游戏，观察第 6/12/18/24 波 Boss 生成

2. `[P1]` 鹰图腾单位修复 - ✅ 代码审查完成
   - Eagle.gd: ✅ 已实现 (优先攻击最高 HP 敌人，Lv3 处决>80% HP)
   - Vulture.gd: ✅ 已实现 (优先攻击最低 HP 敌人，Lv2 永久叠加攻击力，Lv3 死亡回响)
   - Echo Amplifier: ❌ **缺失** - 需要创建 `res://src/Scripts/Units/Behaviors/EchoAmplifier.gd`

3. `[P1]` 眼镜蛇图腾单位修复 - ✅ 代码审查完成
   - ArrowFrog.gd: ✅ 已实现 (斩杀机制，中毒)
   - Rat: ❌ **缺失** - 需要创建 `res://src/Scripts/Units/Behaviors/Rat.gd`
   - Toad: ⚠️ **部分实现** - 只有 ToadTrap.gd，需要创建蟾蜍单位本体

4. `[P2]` 狼图腾血食单位修复 - ✅ 代码审查完成
   - BloodMeat.gd: ✅ 已实现 (血魂层数系统，狼族光环，血祭技能)
   - 日志埋点：`[BLOOD_SOUL]`, `[BLOOD_AURA]`, `[BLOOD_SACRIFICE]`
   - 需要运行测试验证血魂层数效果

5. `[P2]` 公共单位孔雀修复 - ✅ 代码审查完成
   - Peacock.gd: ✅ 已实现 (羽毛攻击，Lv2 易伤 debuff)
   - 日志埋点：`[PEACOCK_VULNERABLE]`
   - 需要运行测试验证易伤 debuff 效果

## 待实现的单位清单

| 单位 | 文件路径 | 状态 |
|------|---------|------|
| Echo Amplifier | `src/Scripts/Units/Behaviors/EchoAmplifier.gd` | ❌ 缺失 |
| Rat | `src/Scripts/Units/Behaviors/Rat.gd` | ❌ 缺失 |
| Toad (本体) | `src/Scripts/Units/Behaviors/Toad.gd` | ❌ 缺失 |

## [Archive - 历史归档]

(无)
