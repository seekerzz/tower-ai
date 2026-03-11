from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
UNIT = ROOT / 'src/Scripts/Unit.gd'
VISUAL = ROOT / 'src/Scripts/Components/UnitVisualComponent.gd'


def _read(path: Path) -> str:
    assert path.exists(), f"Missing file: {path}"
    return path.read_text(encoding='utf-8')


def test_unit_delegates_buff_visual_feedback_to_visual_component():
    unit = _read(UNIT)

    assert re.search(
        r"func play_buff_receive_anim\(\):\n\s*if visual_component:\n\s*visual_component\.play_buff_receive_anim\(\)",
        unit,
    )

    assert re.search(
        r"func spawn_buff_effect\(icon_char: String\):\n\s*if visual_component:\n\s*visual_component\.spawn_buff_effect\(icon_char\)",
        unit,
    )


def test_visual_component_owns_buff_feedback_implementation():
    visual = _read(VISUAL)

    assert "func play_buff_receive_anim():" in visual
    assert "func spawn_buff_effect(icon_char: String):" in visual
    assert "effect_node.name = \"BuffEffect\"" in visual
