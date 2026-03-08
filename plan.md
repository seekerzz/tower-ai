1. **Create `UnitVisuals.gd`**:
   - Save in `src/Scripts/Units/UnitVisuals.gd`.
   - Inherits from `Node2D`.
   - Keeps track of `breathe_tween`, `attack_tween`, `damage_tween`, `buff_tween`, `level_up_tween`.
   - Connects to signals from `Unit` (like `damage_taken`, `attack_started`, `buff_received`, `level_up`, `skill_cast`).
   - Handles the entire `VisualHolder` lifecycle and its children.
   - Strips hardcoded `await` and relies entirely on chained Godot `Tween`s with auto-kill to ensure visual consistency.

2. **Create `UnitInteraction.gd`**:
   - Save in `src/Scripts/Units/UnitInteraction.gd`.
   - Inherits from `Node2D` or `Node`.
   - Listens to signals from `Unit`'s `Area2D` (`mouse_entered`, `mouse_exited`, `input_event`).
   - Manages hover state, highlighing logic (calling methods on `UnitVisuals` or triggering `queue_redraw` on `Unit`).
   - Manages dragging state (`is_dragging`), `ghost_node` creation, update, and queue_free deletion.

3. **Modify `Unit.gd`**:
   - Remove visual functions (`play_attack_anim`, `start_breathe_anim`, `update_visuals`, `spawn_buff_effect`, `play_buff_receive_anim`).
   - Remove interaction functions (`_on_area_2d_input_event`, `_on_area_2d_mouse_entered`, `_on_area_2d_mouse_exited`, `_input`, `start_drag`, `end_drag`, `create_ghost`, `remove_ghost`).
   - Expose signals for Visuals to hook into:
     - `signal damage_taken_visual(amount, source)`
     - `signal attack_started_visual(attack_type, target_pos, duration)`
     - `signal buff_received_visual()`
     - `signal level_up_visual()`
     - `signal skill_cast_visual()`
     - `signal visual_update_requested()`
   - Add references to `UnitVisuals` and `UnitInteraction`, instantiating them dynamically or expecting them as children.

4. **Modify `Unit.tscn`**:
   - Either attach `UnitVisuals` and `UnitInteraction` as children here, or have `Unit.gd` instantiate them in `_ready()`. (Instantiating dynamically is cleaner for separating concerns).

5. **Create tests (`src/Scripts/Tests/UnitVisualsAndInteractionTest.gd`)**:
   - Write tests as requested:
     - test 1: emit damage_taken 5 times quickly, verify tweens are killed and node remains bounded.
     - test 2: simulate mouse interactions for dragging, verify state and ghost node creation/cleanup.
   - Run it to ensure tests pass.

6. **Pre-commit**:
   - Run `pre_commit_instructions` tool and complete steps.

7. **Submit**.
