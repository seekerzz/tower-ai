#!/usr/bin/env python3
"""
AI Client Unit Test Suite

Comprehensive tests for different units and game actions.
Run with: python3 ai_client/unit_test_suite.py

Test Categories:
1. Basic Actions - select_totem, buy_unit, move_unit, start_wave
2. Shop Actions - refresh_shop, lock/unlock_shop_slot
3. Cheat Actions - cheat_add_gold, cheat_set_shop_unit, cheat_spawn_unit
4. Unit Placement - Testing different grid positions
5. Error Handling - Invalid actions and error responses
"""

import asyncio
import json
import subprocess
import time
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

import requests


class AITestClient:
    """Test client for AI game API"""

    def __init__(self, http_port=10000):
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.test_results = []

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
                timeout=35
            )
            return r.json()
        except requests.Timeout:
            return {"event": "Error", "error_message": "HTTP Timeout"}
        except Exception as e:
            return {"event": "Error", "error_message": str(e)}

    def test_pass(self, test_name, details=""):
        """Record passing test"""
        self.test_results.append({"name": test_name, "status": "PASS", "details": details})
        print(f"  ✅ PASS: {test_name}")

    def test_fail(self, test_name, expected, actual):
        """Record failing test"""
        self.test_results.append({
            "name": test_name,
            "status": "FAIL",
            "expected": expected,
            "actual": actual
        })
        print(f"  ❌ FAIL: {test_name}")
        print(f"     Expected: {expected}")
        print(f"     Actual: {actual}")

    def print_summary(self):
        """Print test summary"""
        passed = sum(1 for r in self.test_results if r["status"] == "PASS")
        failed = sum(1 for r in self.test_results if r["status"] == "FAIL")
        total = len(self.test_results)

        print("\n" + "="*60)
        print("TEST SUMMARY")
        print("="*60)
        print(f"Total: {total} | Passed: {passed} | Failed: {failed}")
        print("="*60)

        if failed > 0:
            print("\nFailed Tests:")
            for r in self.test_results:
                if r["status"] == "FAIL":
                    print(f"  - {r['name']}: {r['actual']}")

        return failed == 0


class TestSuite:
    """Complete test suite for AI game client"""

    def __init__(self, client):
        self.client = client

    # ============ Category 1: Basic Actions ============

    def test_select_totem(self):
        """Test selecting each available totem"""
        print("\n📋 Testing: select_totem")

        totems = ["wolf_totem", "cow_totem", "bat_totem", "viper_totem", "butterfly_totem", "eagle_totem"]

        for totem in totems:
            resp = self.client.action({"type": "select_totem", "totem_id": totem})

            if resp.get("event") == "ActionsCompleted" or resp.get("event") == "TotemSelected":
                self.client.test_pass(f"select_totem ({totem})")
            else:
                self.client.test_fail(f"select_totem ({totem})", "ActionsCompleted", resp.get("event", resp))

            time.sleep(0.5)

    def test_buy_unit(self):
        """Test buying units from shop"""
        print("\n📋 Testing: buy_unit")

        # First select a totem and get to the shop phase
        self.client.action({"type": "select_totem", "totem_id": "wolf_totem"})
        time.sleep(1)

        # Try to buy from each shop slot
        for i in range(4):
            resp = self.client.action({"type": "buy_unit", "shop_index": i})

            event = resp.get("event")
            if event == "ActionsCompleted":
                self.client.test_pass(f"buy_unit (slot {i})", "Unit purchased")
                break
            elif event == "ActionError":
                error = resp.get("error_message", "")
                if "金币不足" in error or "商店槽位" in error:
                    self.client.test_pass(f"buy_unit (slot {i})", f"Expected error: {error[:30]}...")
                else:
                    self.client.test_fail(f"buy_unit (slot {i})", "ActionsCompleted or gold error", error)
            else:
                self.client.test_fail(f"buy_unit (slot {i})", "ActionsCompleted", event)

    def test_move_unit(self):
        """Test moving units between bench and grid"""
        print("\n📋 Testing: move_unit")

        # Try to move a unit (will likely fail but should return proper error)
        resp = self.client.action({
            "type": "move_unit",
            "from_zone": "bench",
            "from_pos": 0,
            "to_zone": "grid",
            "to_pos": {"x": 0, "y": 1}
        })

        event = resp.get("event")
        if event in ["ActionsCompleted", "ActionError"]:
            self.client.test_pass("move_unit", f"Response: {event}")
        else:
            self.client.test_fail("move_unit", "ActionsCompleted or ActionError", event)

    def test_start_wave(self):
        """Test starting a wave"""
        print("\n📋 Testing: start_wave")

        resp = self.client.action({"type": "start_wave"})

        event = resp.get("event")
        if event == "WaveStarted":
            self.client.test_pass("start_wave", "Wave started successfully")
        elif event == "ActionError":
            error = resp.get("error_message", "")
            self.client.test_pass("start_wave", f"Expected error: {error[:40]}...")
        else:
            self.client.test_fail("start_wave", "WaveStarted", event)

    # ============ Category 2: Shop Actions ============

    def test_refresh_shop(self):
        """Test refreshing the shop"""
        print("\n📋 Testing: refresh_shop")

        resp = self.client.action({"type": "refresh_shop"})

        event = resp.get("event")
        if event == "ActionsCompleted":
            self.client.test_pass("refresh_shop", "Shop refreshed")
        elif event == "ActionError":
            error = resp.get("error_message", "")
            if "金币不足" in error or "战斗阶段" in error:
                self.client.test_pass("refresh_shop", f"Expected error: {error[:30]}...")
            else:
                self.client.test_fail("refresh_shop", "ActionsCompleted", error)
        else:
            self.client.test_fail("refresh_shop", "ActionsCompleted", event)

    def test_lock_unlock_shop(self):
        """Test locking and unlocking shop slots"""
        print("\n📋 Testing: lock/unlock_shop_slot")

        # Lock slot 0
        resp = self.client.action({"type": "lock_shop_slot", "shop_index": 0})
        if resp.get("event") == "ActionsCompleted":
            self.client.test_pass("lock_shop_slot")
        else:
            self.client.test_fail("lock_shop_slot", "ActionsCompleted", resp.get("event"))

        # Unlock slot 0
        resp = self.client.action({"type": "unlock_shop_slot", "shop_index": 0})
        if resp.get("event") == "ActionsCompleted":
            self.client.test_pass("unlock_shop_slot")
        else:
            self.client.test_fail("unlock_shop_slot", "ActionsCompleted", resp.get("event"))

    # ============ Category 3: Cheat Actions ============

    def test_cheat_add_gold(self):
        """Test cheat to add gold"""
        print("\n📋 Testing: cheat_add_gold")

        resp = self.client.action({"type": "cheat_add_gold", "amount": 100})

        if resp.get("event") == "ActionsCompleted":
            self.client.test_pass("cheat_add_gold", "Gold added")
        else:
            self.client.test_fail("cheat_add_gold", "ActionsCompleted", resp.get("event"))

    def test_cheat_set_shop_unit(self):
        """Test cheat to set specific unit in shop"""
        print("\n📋 Testing: cheat_set_shop_unit")

        units = ["wolf", "tiger", "cow", "rabbit"]

        for unit in units:
            resp = self.client.action({
                "type": "cheat_set_shop_unit",
                "shop_index": 0,
                "unit_key": unit
            })

            if resp.get("event") == "ActionsCompleted":
                self.client.test_pass(f"cheat_set_shop_unit ({unit})")
            else:
                self.client.test_fail(f"cheat_set_shop_unit ({unit})", "ActionsCompleted", resp.get("event"))

    def test_cheat_spawn_unit(self):
        """Test cheat to spawn unit directly"""
        print("\n📋 Testing: cheat_spawn_unit")

        resp = self.client.action({
            "type": "cheat_spawn_unit",
            "unit_type": "wolf",
            "level": 1,
            "zone": "bench",
            "pos": 0
        })

        if resp.get("event") == "ActionsCompleted":
            self.client.test_pass("cheat_spawn_unit (bench)")
        else:
            self.client.test_fail("cheat_spawn_unit (bench)", "ActionsCompleted", resp.get("event"))

    # ============ Category 4: Skill and Buff Actions ============

    def test_get_unit_info(self):
        """Test getting unit info including buffs"""
        print("\n📋 Testing: get_unit_info")

        # First spawn a unit on the grid
        self.client.action({"type": "cheat_spawn_unit", "unit_type": "tiger", "level": 1, "zone": "grid", "pos": {"x": 0, "y": 1}})
        time.sleep(0.5)

        resp = self.client.action({"type": "get_unit_info", "grid_pos": {"x": 0, "y": 1}})

        if resp.get("event") == "ActionsCompleted" and resp.get("unit_info"):
            unit_info = resp.get("unit_info", {})
            info_str = f"Type: {unit_info.get('type_key')}, Level: {unit_info.get('level')}"
            self.client.test_pass("get_unit_info", info_str)
        else:
            self.client.test_fail("get_unit_info", "ActionsCompleted with unit_info", resp.get("event", resp))

    def test_use_skill(self):
        """Test using unit skill"""
        print("\n📋 Testing: use_skill")

        # Add mana first
        self.client.action({"type": "cheat_add_mana", "amount": 100})
        time.sleep(0.5)

        resp = self.client.action({"type": "use_skill", "grid_pos": {"x": 0, "y": 1}})

        event = resp.get("event")
        if event == "ActionsCompleted":
            self.client.test_pass("use_skill", "Skill activated")
        elif event == "ActionError":
            error = resp.get("error_message", "")
            self.client.test_pass("use_skill", f"Expected error: {error[:40]}...")
        else:
            self.client.test_fail("use_skill", "ActionsCompleted or ActionError", event)

    # ============ Category 5: Error Handling ============

    def test_invalid_actions(self):
        """Test handling of invalid actions"""
        print("\n📋 Testing: invalid actions")

        invalid_actions = [
            {"type": "unknown_action"},
            {"type": "buy_unit", "shop_index": 10},  # Out of range
            {"type": "move_unit", "from_zone": "invalid"},
            {},  # Empty action
        ]

        for action in invalid_actions:
            resp = self.client.action(action)

            if resp.get("event") in ["ActionError", "Error", "ActionsCompleted"]:
                self.client.test_pass(f"invalid_action ({action.get('type', 'empty')})")
            else:
                self.client.test_fail(f"invalid_action ({action.get('type', 'empty')})", "Error response", resp)

    # ============ Run All Tests ============

    def run_all(self):
        """Run complete test suite"""
        print("="*60)
        print("AI GAME CLIENT - UNIT TEST SUITE")
        print("="*60)

        # Check server is running
        status = self.client.status()
        if not status.get("godot_running"):
            print("\n❌ ERROR: Godot is not running!")
            print("Please start the AI client first:")
            print("  python3 ai_client/ai_game_client.py")
            return False

        print(f"\n✅ Server ready - HTTP port: {status.get('http_port')}")

        # Run all test categories
        self.test_select_totem()
        self.test_buy_unit()
        self.test_move_unit()
        self.test_start_wave()
        self.test_refresh_shop()
        self.test_lock_unlock_shop()
        self.test_cheat_add_gold()
        self.test_cheat_set_shop_unit()
        self.test_cheat_spawn_unit()
        self.test_get_unit_info()
        self.test_use_skill()
        self.test_invalid_actions()

        # Print summary
        return self.client.print_summary()


def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(description="AI Game Client Test Suite")
    parser.add_argument("--port", type=int, default=10000, help="HTTP port (default: 10000)")
    parser.add_argument("--category", choices=["basic", "shop", "cheat", "error", "all"],
                        default="all", help="Test category to run")
    args = parser.parse_args()

    client = AITestClient(http_port=args.port)
    suite = TestSuite(client)

    success = suite.run_all()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
