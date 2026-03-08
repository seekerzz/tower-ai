So `Unit.tscn` connects `Area2D` signals to `Unit.gd`. We can remove these methods from `Unit.gd` and move them to `UnitInteraction.gd`. But `UnitInteraction.gd` would either be a child node or instantiated via code. Let's create `UnitInteraction` and `UnitVisuals` as standard classes (`class_name`) and instantiate them inside `Unit.gd`, or add them as nodes.
Creating them as custom RefCounted classes or Node classes?
Requirements:
"UnitVisuals 仅暴露事件响应函数（如 play_attack_anim, play_damage_bounce），通过监听组件信号来执行 Tween，内部自动接管 Tween 的 kill 和重建。"
"UnitInteraction 统管 _on_area_2d_mouse_entered 等事件，仅负责高亮控制和拖拽状态管理。"

If we use `Node`, they can process `_input` and `_process`. Let's create them as subclasses of `Node` (or `Node2D` if they hold Visuals) and add them as children of `Unit` inside `_ready()` or `setup()`.

Signals to add to `Unit.gd`:
- `damage_taken(amount, source)`
- `attack_windup(attack_type, target_pos, duration)`
- `attack_strike(attack_type, target_pos)`
- `attack_recover(attack_type)`
- `buff_received()`
- `level_up_anim()`
- `skill_cast_anim()`

Wait, `UnitVisuals` can just expose methods like `play_attack_anim`, `play_damage_bounce`.
"UnitVisuals 仅暴露事件响应函数... 通过监听组件信号来执行 Tween"
So `Unit.gd` emits a signal `on_damage_taken`, `UnitVisuals` listens to it and executes `play_damage_bounce()`.

Let's make sure the tests pass. The tests should be written in `src/Scripts/Tests/UnitVisualsAndInteractionTest.gd` (or similar). The prompt says:
"创建对应的 Test 脚本。由于涉及视觉，需在测试中构建虚拟的 VisualHolder 节点树。"

Tests required:
1. "连续高频触发 on_damage_taken 信号 5 次，验证 Tween 是否正确调用了 kill() 以防止动画状态机崩溃或节点飞出屏幕。"
2. "模拟拖拽事件序列（Mouse Down -> Mouse Motion -> Mouse Up），验证 is_dragging 状态的正确切换以及拖拽残影（Ghost Node）的创建与彻底销毁。"

Let's look at how automated tests are structured here.
