#!/usr/bin/env python3
"""
Test script to verify AI client stability during wave transitions.

This test:
1. Starts a wave
2. Waits for it to complete (or uses cheat to speed up)
3. Verifies the AI client receives WaveEnded event immediately
4. Verifies the connection stays alive during upgrade selection
5. Resumes and starts next wave

Run with: python3 test_wave_transition.py
"""

import asyncio
import json
import subprocess
import time
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent))

import requests


class WaveTransitionTester:
    """Test wave transition stability"""

    def __init__(self, http_port=10000):
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.tests_passed = 0
        self.tests_failed = 0

    def status(self):
        """Get server status"""
        try:
            r = requests.get(f"{self.base_url}/status", timeout=5)
            return r.json()
        except Exception as e:
            return {"error": str(e)}

    def action(self, actions):
        """Send action(s) and return response"""
        try:
            r = requests.post(
                f"{self.base_url}/action",
                json={"actions": actions if isinstance(actions, list) else [actions]},
                timeout=65
            )
            return r.json()
        except requests.Timeout:
            return {"event": "Error", "error_message": "HTTP Timeout"}
        except Exception as e:
            return {"event": "Error", "error_message": str(e)}

    def log(self, message, level="INFO"):
        """Log a message"""
        print(f"[{level}] {message}")

    def test_pass(self, test_name):
        """Record passing test"""
        self.tests_passed += 1
        self.log(f"PASS: {test_name}", "PASS")

    def test_fail(self, test_name, reason):
        """Record failing test"""
        self.tests_failed += 1
        self.log(f"FAIL: {test_name} - {reason}", "FAIL")

    def run_tests(self):
        """Run all wave transition tests"""
        self.log("=" * 60)
        self.log("AI Client Wave Transition Stability Test")
        self.log("=" * 60)

        # Check server is running
        status = self.status()
        if status.get("error"):
            self.log(f"Server not available: {status['error']}", "ERROR")
            return False

        self.log(f"Server status: {status}")

        # Test 1: Select totem and set up
        self.log("\n--- Test 1: Setup (Select Totem) ---")
        result = self.action({"type": "select_totem", "totem_id": "cow_totem"})
        if result.get("event") in ["TotemSelected", "StateUpdate"]:
            self.test_pass("Select Totem")
        else:
            self.test_fail("Select Totem", f"Unexpected response: {result}")

        # Test 2: Add gold for units
        self.log("\n--- Test 2: Add Resources ---")
        result = self.action({"type": "cheat_add_gold", "amount": 1000})
        if result.get("event") != "Error":
            self.test_pass("Add Gold")
        else:
            self.test_fail("Add Gold", result.get("error_message", "Unknown error"))

        # Test 3: Spawn some units
        self.log("\n--- Test 3: Spawn Units ---")
        result = self.action([
            {"type": "cheat_spawn_unit", "unit_type": "cow", "level": 1, "zone": "grid", "pos": {"x": 1, "y": 1}},
            {"type": "cheat_spawn_unit", "unit_type": "milk_cow", "level": 1, "zone": "grid", "pos": {"x": 2, "y": 1}},
            {"type": "cheat_spawn_unit", "unit_type": "healer", "level": 1, "zone": "grid", "pos": {"x": 1, "y": 2}},
        ])
        if result.get("event") == "ActionsCompleted":
            self.test_pass("Spawn Units")
        else:
            self.test_fail("Spawn Units", f"Unexpected response: {result}")

        # Test 4: Start wave 1
        self.log("\n--- Test 4: Start Wave 1 ---")
        result = self.action({"type": "start_wave"})
        event = result.get("event")
        if event == "WaveStarted":
            self.test_pass("Start Wave 1")
            self.log(f"Wave started: {result.get('event_data', {})}")
        else:
            self.test_fail("Start Wave 1", f"Unexpected event: {event}")

        # Test 5: Wait for wave to end (with timeout)
        self.log("\n--- Test 5: Wait for Wave 1 to Complete ---")
        self.log("Waiting for WaveEnded event (this may take a while)...")

        wave_ended_received = False
        start_time = time.time()
        max_wait = 60  # 60 seconds max wait

        while time.time() - start_time < max_wait:
            # Send a resume action to check state
            result = self.action({"type": "resume", "wait_time": 1.0})
            event = result.get("event")

            if event == "WaveEnded":
                self.log(f"WaveEnded received: {result.get('event_data', {})}")
                wave_ended_received = True
                self.test_pass("Wave 1 Ended - Event Received")
                break
            elif event == "UpgradeSelection":
                self.log("UpgradeSelection shown - wave completed")
                wave_ended_received = True
                self.test_pass("Wave 1 Ended - Upgrade Selection Shown")
                break
            elif event == "Error":
                if "wave" in result.get("error_message", "").lower():
                    self.log(f"Still in wave: {result.get('error_message')}")
                else:
                    self.log(f"Error: {result.get('error_message')}")

            time.sleep(2)

        if not wave_ended_received:
            self.test_fail("Wave 1 End", "Timeout waiting for wave to end")
            return False

        # Test 6: Verify connection is still alive
        self.log("\n--- Test 6: Verify Connection Alive ---")
        status = self.status()
        if status.get("ws_connected") and status.get("godot_running"):
            self.test_pass("Connection Alive After Wave End")
        else:
            self.test_fail("Connection Alive", f"Status: {status}")

        # Test 7: Resume to dismiss upgrade selection
        self.log("\n--- Test 7: Resume After Wave ---")
        result = self.action({"type": "resume", "wait_time": 0.5})
        if result.get("event") != "Error":
            self.test_pass("Resume After Wave")
        else:
            self.test_fail("Resume After Wave", result.get("error_message", "Unknown error"))

        # Test 8: Start wave 2
        self.log("\n--- Test 8: Start Wave 2 ---")
        result = self.action({"type": "start_wave"})
        event = result.get("event")
        if event == "WaveStarted":
            self.test_pass("Start Wave 2")
            self.log(f"Wave 2 started: {result.get('event_data', {})}")
        else:
            self.test_fail("Start Wave 2", f"Unexpected event: {event}")

        # Test 9: Immediate status check
        self.log("\n--- Test 9: Status During Wave 2 ---")
        status = self.status()
        if status.get("ws_connected"):
            self.test_pass("Connection Alive During Wave 2")
        else:
            self.test_fail("Connection During Wave 2", f"Status: {status}")

        # Test 10: End wave 2 early
        self.log("\n--- Test 10: End Wave 2 Early ---")
        result = self.action({"type": "cheat_set_time_scale", "scale": 10.0})
        time.sleep(1)
        result = self.action({"type": "resume", "wait_time": 2.0})

        # Wait for wave 2 to end
        start_time = time.time()
        while time.time() - start_time < 30:
            result = self.action({"type": "resume", "wait_time": 1.0})
            if result.get("event") in ["WaveEnded", "UpgradeSelection"]:
                self.test_pass("Wave 2 Ended")
                break
            time.sleep(1)
        else:
            self.test_fail("Wave 2 End", "Timeout")

        # Reset time scale
        self.action({"type": "cheat_set_time_scale", "scale": 1.0})

        # Final status
        self.log("\n" + "=" * 60)
        self.log(f"Tests Passed: {self.tests_passed}")
        self.log(f"Tests Failed: {self.tests_failed}")
        self.log("=" * 60)

        return self.tests_failed == 0


def main():
    """Main entry point"""
    print("Wave Transition Stability Test")
    print("Make sure the AI client is running:")
    print("  python3 ai_client/ai_game_client.py --visual")
    print()

    # Try to auto-detect port
    tester = None
    for port in [10000, 8080, 9000, 9090]:
        try:
            r = requests.get(f"http://127.0.0.1:{port}/status", timeout=2)
            if r.status_code == 200:
                print(f"Found AI client on port {port}")
                tester = WaveTransitionTester(port)
                break
        except:
            continue

    if tester is None:
        print("Could not auto-detect AI client port. Please specify manually.")
        port = input("Enter port number (default 10000): ").strip()
        if not port:
            port = 10000
        else:
            port = int(port)
        tester = WaveTransitionTester(port)

    success = tester.run_tests()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
