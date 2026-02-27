#!/bin/bash
cd /home/zhangzhan/tower
echo "Running Godot in test mode..."
godot --path . --headless --debug 2>&1 | tee test_output.log &
PID=$!
sleep 10
kill $PID 2>/dev/null
wait $PID 2>/dev/null

echo ""
echo "=== Checking test results ==="
if grep -q "BoardController API Test" test_output.log; then
    echo "✅ Test script executed"
else
    echo "❌ Test script not found in output"
fi

if grep -q "SessionData exists.*PASS" test_output.log; then
    echo "✅ SessionData test passed"
else
    echo "❌ SessionData test failed"
fi

if grep -q "BoardController exists.*PASS" test_output.log; then
    echo "✅ BoardController test passed"
else
    echo "❌ BoardController test failed"
fi

if grep -q "Null Reference" test_output.log; then
    echo "❌ Null Reference errors found:"
    grep "Null Reference" test_output.log | head -5
fi

if grep -q "Method not found" test_output.log; then
    echo "❌ Method not found errors:"
    grep "Method not found" test_output.log | head -5
fi
