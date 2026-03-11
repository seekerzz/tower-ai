import os
import shutil
import subprocess


def _resolve_godot_bin() -> str | None:
    candidates = [
        os.environ.get("GODOT_BIN"),
        shutil.which("godot"),
        shutil.which("godot4"),
        "/opt/godot45/Godot_v4.5-stable_linux.x86_64",
        "/opt/godot4/Godot_v4.2.2-stable_linux.x86_64",
    ]
    for c in candidates:
        if c and os.path.exists(c):
            return c
    return None


def test_grid_manager_refactor_via_godot_headless_runtime():
    godot_bin = _resolve_godot_bin()
    assert godot_bin, "Godot binary not found. Set GODOT_BIN or install Godot 4."

    cmd = [
        godot_bin,
        "--headless",
        "--script",
        "/workspace/tower-ai/tests/godot/test_grid_services_headless_runner.gd",
    ]

    result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    output = (result.stdout or "") + "\n" + (result.stderr or "")

    assert result.returncode == 0, f"Godot headless test failed.\n{output}"
    assert "[HEADLESS TEST PASS]" in output, output
