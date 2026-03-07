#!/bin/bash
godot --headless -s src/Scripts/Tests/test_combat_manager_refactor.gd &
GODOT_PID=$!
sleep 5
kill $GODOT_PID 2>/dev/null
