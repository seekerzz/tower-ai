from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
GRID = ROOT / 'src/Scripts/GridManager.gd'
BUFF = ROOT / 'src/Scripts/Services/GridBuffService.gd'
EXP = ROOT / 'src/Scripts/Services/GridExpansionService.gd'


def _read(path: Path) -> str:
    assert path.exists(), f'Missing file: {path}'
    return path.read_text(encoding='utf-8')


def test_services_files_exist_and_are_typed():
    buff = _read(BUFF)
    exp = _read(EXP)
    assert 'class_name GridBuffService' in buff
    assert 'class_name GridExpansionService' in exp
    assert 'var grid_manager: Node2D' in buff
    assert 'var grid_manager: Node2D' in exp


def test_grid_manager_delegates_buff_and_expansion_methods():
    text = _read(GRID)

    assert 'const GridBuffService = preload("res://src/Scripts/Services/GridBuffService.gd")' in text
    assert 'const GridExpansionService = preload("res://src/Scripts/Services/GridExpansionService.gd")' in text

    # Delegation checks
    assert re.search(r"func recalculate_buffs\(\):\n\s*grid_buff_service\.recalculate_buffs\(\)", text)
    assert re.search(r"func _apply_buff_to_specific_pos\(target_pos: Vector2i, buff_id: String, provider_unit: Node2D = null\):\n\s*grid_buff_service\.apply_buff_to_specific_pos\(target_pos, buff_id, provider_unit\)", text)

    assert re.search(r"func toggle_expansion_mode\(\):\n\s*grid_expansion_service\.toggle_expansion_mode\(\)", text)
    assert re.search(r"func spawn_expansion_ghosts\(\):\n\s*grid_expansion_service\.spawn_expansion_ghosts\(\)", text)
    assert re.search(r"func clear_ghosts\(\):\n\s*grid_expansion_service\.clear_ghosts\(\)", text)
    assert re.search(r"func on_ghost_clicked\(x, y\):\n\s*grid_expansion_service\.on_ghost_clicked\(x, y\)", text)
    assert re.search(r"func get_closest_unlocked_tile\(world_pos: Vector2\) -> Node2D:\n\s*return grid_expansion_service\.get_closest_unlocked_tile\(world_pos\)", text)


def test_no_private_buff_icon_calls_and_unit_exposes_icon_api():
    grid = _read(GRID)
    unit = _read(ROOT / "src/Scripts/Unit.gd")

    assert "._get_buff_icon(" not in grid
    assert "func _resolve_buff_icon(source_unit: Node2D, buff_id: String) -> String:" in grid
    assert "source_unit.has_method(\"get_buff_icon\")" in grid

    assert "func get_buff_icon(buff_type: String) -> String:" in unit
