from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
GRID = ROOT / 'src/Scripts/GridManager.gd'
BUFF = ROOT / 'src/Scripts/Services/GridBuffService.gd'
EXP = ROOT / 'src/Scripts/Services/GridExpansionService.gd'
INT = ROOT / 'src/Scripts/Services/GridInteractionService.gd'


def _read(path: Path) -> str:
    assert path.exists(), f'Missing file: {path}'
    return path.read_text(encoding='utf-8')


def test_services_files_exist_and_are_typed():
    buff = _read(BUFF)
    exp = _read(EXP)
    interaction = _read(INT)
    assert 'class_name GridBuffService' in buff
    assert 'class_name GridExpansionService' in exp
    assert 'class_name GridInteractionService' in interaction
    assert 'var grid_manager: Node2D' in buff
    assert 'var grid_manager: Node2D' in exp
    assert 'var grid_manager: Node2D' in interaction


def test_grid_manager_delegates_buff_and_expansion_methods():
    text = _read(GRID)

    assert 'const GridBuffService = preload("res://src/Scripts/Services/GridBuffService.gd")' in text
    assert 'const GridExpansionService = preload("res://src/Scripts/Services/GridExpansionService.gd")' in text

    # Delegation checks
    assert re.search(r"func recalculate_buffs\(\):\n\s*grid_buff_service\.recalculate_buffs\(\)", text)
    assert re.search(r"func _apply_buff_to_specific_pos\(target_pos: Vector2i, buff_id: String, provider_unit: Node2D = null\):\n\s*grid_buff_service\.apply_buff_to_specific_pos\(target_pos, buff_id, provider_unit\)", text)
    assert re.search(r"func _apply_buff_to_neighbors\(provider_unit, buff_type\):\n\s*grid_buff_service\.apply_buff_to_neighbors\(provider_unit, buff_type\)", text)
    assert re.search(r"func show_provider_icons\(provider_unit: Node2D\):\n\s*grid_buff_service\.show_provider_icons\(provider_unit\)", text)
    assert re.search(r"func _spawn_provider_icon_at\(grid_pos: Vector2i, buff_type: String, provider_unit: Node2D\):\n\s*grid_buff_service\.spawn_provider_icon_at\(grid_pos, buff_type, provider_unit\)", text)
    assert re.search(r"func hide_provider_icons\(\):\n\s*grid_buff_service\.hide_provider_icons\(\)", text)

    assert re.search(r"func toggle_expansion_mode\(\):\n\s*grid_expansion_service\.toggle_expansion_mode\(\)", text)
    assert re.search(r"func spawn_expansion_ghosts\(\):\n\s*grid_expansion_service\.spawn_expansion_ghosts\(\)", text)
    assert re.search(r"func clear_ghosts\(\):\n\s*grid_expansion_service\.clear_ghosts\(\)", text)
    assert re.search(r"func on_ghost_clicked\(x, y\):\n\s*grid_expansion_service\.on_ghost_clicked\(x, y\)", text)
    assert re.search(r"func get_closest_unlocked_tile\(world_pos: Vector2\) -> Node2D:\n\s*return grid_expansion_service\.get_closest_unlocked_tile\(world_pos\)", text)

    assert re.search(r"func _input\(event\):\n\s*grid_interaction_service\.handle_input\(event\)", text)
    assert re.search(r"func enter_skill_targeting\(unit: Node2D\):\n\s*grid_interaction_service\.enter_skill_targeting\(unit\)", text)
    assert re.search(r"func start_interaction_selection\(unit\):\n\s*grid_interaction_service\.start_interaction_selection\(unit\)", text)
    assert re.search(r"func start_trap_placement_sequence\(unit\):\n\s*grid_interaction_service\.start_trap_placement_sequence\(unit\)", text)
    assert re.search(r"func _cancel_deployment_sequence\(\):\n\s*grid_interaction_service\.cancel_deployment_sequence\(\)", text)


def test_no_private_buff_icon_calls_and_unit_exposes_icon_api():
    grid = _read(GRID)
    unit = _read(ROOT / "src/Scripts/Unit.gd")

    assert "._get_buff_icon(" not in grid
    buff = _read(BUFF)
    interaction = _read(INT)
    assert "grid_buff_service.resolve_buff_icon(" in interaction
    assert "func resolve_buff_icon(source_unit: Node2D, buff_id: String) -> String:" in buff
    assert "source_unit.has_method(\"get_buff_icon\")" in buff

    assert "func get_buff_icon(buff_type: String) -> String:" in unit
