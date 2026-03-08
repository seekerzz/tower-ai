# Exploration Plan
1. Need to refactor unit visuals into a dedicated class `UnitVisuals` that listens to signals from `Unit`.
2. Need to refactor unit interactions (mouse enter/exit, dragging) into a dedicated class `UnitInteraction` that listens to signals/controls states of `Unit`.
3. Modify `Unit.gd` to integrate these two new scripts and strip the old hardcoded visuals/interactions.
4. Ensure no `await` usage in `UnitVisuals`, only Tween chaining, auto-killing previous Tweens.
5. Create a test script covering multiple fast damage bounce events and drag state toggling / ghost node cleanup.

Let's check `Unit.gd` again to identify all visual methods to extract:
- `play_attack_anim`
- `start_breathe_anim`
- bounce/wobble on `take_damage`
- `play_buff_receive_anim`
- `update_visuals` (icon and label initialization)
- `_update_buff_icons`
- `spawn_buff_effect`
- highlight functions (`set_highlight`, `set_force_highlight`)
- floating text calls (maybe leave in Unit or move to Visuals?)

Identify all interaction methods to extract:
- `_on_area_2d_mouse_entered`
- `_on_area_2d_mouse_exited`
- `_on_area_2d_input_event`
- `start_drag`, `end_drag`, `create_ghost`, `remove_ghost`, `return_to_start`
- `_input` event loop

I need to write two new classes `UnitVisuals.gd` and `UnitInteraction.gd`.
Then inject them into `Unit.gd` (or replace the inline code with instantiating them). The requirements specify:
- UnitVisuals 仅暴露事件响应函数（如 play_attack_anim, play_damage_bounce），通过监听组件信号来执行 Tween，内部自动接管 Tween 的 kill 和重建。
- UnitInteraction 统管 _on_area_2d_mouse_entered 等事件，仅负责高亮控制和拖拽状态管理。

Let's check if `Unit` has an `Area2D`. Looking at `Unit.gd`, it connects to `_on_area_2d_mouse_entered` etc., so probably the scene (`Unit.tscn`) has an `Area2D` that delegates to `Unit.gd`. We can just redirect these in `UnitInteraction.gd` or have `UnitInteraction` attach to the `Area2D` signals itself.

Let's locate `Unit.tscn` to see how it's structured.
