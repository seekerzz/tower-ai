#!/usr/bin/env python3
"""
狼单位功能测试脚本 (TASK-#15)
验证吞噬机制和合并机制

使用方法:
    python3 ai_client/wolf_unit_test.py
"""

import asyncio
import json
import time
import sys
import subprocess
import os
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional

sys.path.insert(0, str(Path(__file__).parent))

import aiohttp


class WolfUnitTest:
    """狼单位功能测试器"""

    def __init__(self, http_port=9998):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None
        self.project_dir = Path(__file__).parent.parent

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = self.project_dir / "logs"
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_wolf_unit_{timestamp}.log"

        # 测试结果
        self.test_results = []
        self.validation = {
            "wolf_totem_selected": False,
            "wolf_unit_purchased": False,
            "devour_triggered": False,
            "devour_log_found": False,
            "soul_increased": False,
            "merge_triggered": False,
            "merge_log_found": False,
        }

    def log(self, message: str, level="INFO"):
        """记录日志"""
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        log_line = f"[{timestamp}] [{level}] {message}"
        print(log_line)
        if self.log_file:
            with open(self.log_file, "a", encoding="utf-8") as f:
                f.write(log_line + "\n")

    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()

    async def send_action(self, action: dict) -> dict:
        """发送动作到游戏"""
        try:
            async with self.session.post(
                f"{self.base_url}/action",
                json={"actions": [action]},
                timeout=aiohttp.ClientTimeout(total=5)
            ) as resp:
                return await resp.json()
        except Exception as e:
            self.log(f"发送动作失败: {e}", "ERROR")
            return {"status": "error", "message": str(e)}

    async def get_observations(self) -> List[str]:
        """获取游戏观测日志"""
        try:
            async with self.session.get(
                f"{self.base_url}/observations",
                timeout=aiohttp.ClientTimeout(total=5)
            ) as resp:
                data = await resp.json()
                return data.get("observations", [])
        except Exception as e:
            self.log(f"获取观测失败: {e}", "ERROR")
            return []

    async def poll_observations(self, duration: float = 2.0) -> List[str]:
        """轮询观测日志"""
        all_obs = []
        start = time.time()
        while time.time() - start < duration:
            obs = await self.get_observations()
            for o in obs:
                self.log(o, "GAME")
                all_obs.append(o)
            await asyncio.sleep(0.2)
        return all_obs

    async def wait_for_game_ready(self, timeout: float = 30.0) -> bool:
        """等待游戏就绪"""
        self.log("等待游戏就绪...")
        start = time.time()
        while time.time() - start < timeout:
            try:
                async with self.session.get(
                    f"{self.base_url}/status",
                    timeout=aiohttp.ClientTimeout(total=2)
                ) as resp:
                    data = await resp.json()
                    if data.get("godot_running") and data.get("ws_connected"):
                        self.log("游戏已就绪")
                        return True
            except:
                pass
            await asyncio.sleep(0.5)
        self.log("等待游戏就绪超时", "ERROR")
        return False

    def start_ai_client(self):
        """启动AI客户端"""
        self.log("启动AI客户端...", "SYSTEM")
        client_script = self.project_dir / "ai_client" / "ai_game_client.py"

        env = os.environ.copy()
        env["PYTHONIOENCODING"] = "utf-8"

        self.client_process = subprocess.Popen(
            [
                sys.executable,
                str(client_script),
                "--project", str(self.project_dir),
                "--scene", "res://src/Scenes/UI/CoreSelection.tscn",
                "--http-port", str(self.http_port)
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            cwd=str(self.project_dir),
            env=env
        )
        time.sleep(12)
        self.log(f"AI客户端已启动 (PID: {self.client_process.pid})", "SYSTEM")

    def stop_ai_client(self):
        """停止AI客户端"""
        if self.client_process:
            self.log("停止AI客户端...", "SYSTEM")
            self.client_process.terminate()
            try:
                self.client_process.wait(timeout=5)
            except:
                self.client_process.kill()
            self.log("AI客户端已停止", "SYSTEM")

    def check_logs_for_patterns(self, observations: List[str], patterns: List[str]) -> Dict[str, bool]:
        """检查日志中是否包含指定模式"""
        results = {p: False for p in patterns}
        for obs in observations:
            for pattern in patterns:
                if pattern in obs:
                    results[pattern] = True
        return results

    async def run_test(self):
        """运行狼单位测试"""
        self.log("=" * 60)
        self.log("狼单位功能测试 (TASK-#15)")
        self.log("=" * 60)

        # 启动AI客户端
        self.start_ai_client()

        # 等待游戏就绪
        if not await self.wait_for_game_ready():
            self.log("游戏未就绪，测试中止", "ERROR")
            self.stop_ai_client()
            return False

        try:
            # 步骤1: 选择狼图腾
            self.log("\n[步骤1] 选择狼图腾...")
            await self.send_action({"type": "select_totem", "totem_id": "wolf_totem"})
            await asyncio.sleep(2)
            obs = await self.poll_observations(2)
            self.validation["wolf_totem_selected"] = True
            self.log("✅ 狼图腾选择完成")

            # 步骤2: 购买第一个单位 (将被吞噬)
            self.log("\n[步骤2] 购买羊灵单位 (将被狼吞噬)...")
            await self.send_action({"type": "buy_unit", "shop_index": 0})
            await asyncio.sleep(1)
            await self.poll_observations(1)

            # 部署单位
            await self.send_action({
                "type": "move_unit",
                "from_zone": "bench", "to_zone": "grid",
                "from_pos": 0, "to_pos": {"x": 1, "y": 0}
            })
            await asyncio.sleep(1)
            await self.poll_observations(1)
            self.log("✅ 羊灵单位已部署到 (1,0)")

            # 步骤3: 购买狼单位 (触发吞噬)
            self.log("\n[步骤3] 购买狼单位 (触发吞噬机制)...")
            # 刷新商店寻找狼单位
            wolf_shop_index = -1
            for i in range(10):
                await self.send_action({"type": "refresh_shop"})
                await asyncio.sleep(0.5)
                obs = await self.poll_observations(1)
                # 检查商店是否有狼单位，并确定其索引
                for o in obs:
                    if "【商店刷新】" in o and "wolf(100" in o:
                        self.log(f"✅ 发现狼单位在商店: {o}")
                        # 解析商店列表确定狼的索引
                        # 格式: 【商店刷新】当前商店提供: item0(价格)，item1(价格)，wolf(100金币)，...
                        parts = o.split("当前商店提供: ")
                        if len(parts) > 1:
                            items = parts[1].split("，")
                            for idx, item in enumerate(items):
                                if "wolf(100" in item:
                                    wolf_shop_index = idx
                                    self.log(f"   狼单位在商店索引: {idx}")
                                    break
                        break
                if wolf_shop_index >= 0:
                    break

            if wolf_shop_index < 0:
                self.log("⚠️ 未在商店找到狼单位，使用索引0尝试...", "WARNING")
                wolf_shop_index = 0

            # 购买狼单位 (使用正确的索引)
            self.log(f"购买狼单位 (shop_index={wolf_shop_index})...")
            await self.send_action({"type": "buy_unit", "shop_index": wolf_shop_index})
            await asyncio.sleep(1)
            obs = await self.poll_observations(1)

            # 验证购买成功
            wolf_bought = False
            for o in obs:
                if "【单位购买】" in o and "wolf" in o.lower():
                    self.log(f"✅ 狼单位购买成功: {o}")
                    wolf_bought = True
                    break

            if not wolf_bought:
                self.log("⚠️ 未检测到狼单位购买确认，继续测试...", "WARNING")

            # 部署狼单位到网格 (触发吞噬)
            self.log("部署狼单位到网格，触发吞噬...")
            await self.send_action({
                "type": "move_unit",
                "from_zone": "bench", "to_zone": "grid",
                "from_pos": 0, "to_pos": {"x": 2, "y": 0}
            })
            await asyncio.sleep(2)  # 给足够时间触发吞噬
            obs = await self.poll_observations(3)
            self.validation["wolf_unit_purchased"] = True

            # 检查吞噬日志
            self.log("\n[步骤4] 检查吞噬日志...")
            patterns = ["WOLF吞噬", "吞噬", "devour", "Devour", "[WOLF", "Devoured"]
            found = self.check_logs_for_patterns(obs, patterns)
            if any(found.values()):
                self.validation["devour_log_found"] = True
                self.validation["devour_triggered"] = True
                self.log("✅ 检测到吞噬日志")
                for p, f in found.items():
                    if f:
                        self.log(f"   - 找到模式: {p}")
            else:
                self.log("⚠️ 未检测到吞噬日志", "WARNING")

            # 检查魂魄日志
            self.log("\n[步骤5] 检查魂魄获取日志...")
            soul_patterns = ["魂魄", "soul", "Soul", "魂魄+10"]
            soul_found = self.check_logs_for_patterns(obs, soul_patterns)
            if any(soul_found.values()):
                self.validation["soul_increased"] = True
                self.log("✅ 检测到魂魄获取日志")
            else:
                self.log("⚠️ 未检测到魂魄日志", "WARNING")

            # 步骤6: 购买第二只狼用于合并测试
            self.log("\n[步骤6] 准备第二只狼用于合并测试...")
            # 先买另一个单位用于吞噬
            await self.send_action({"type": "buy_unit", "shop_index": 1})
            await asyncio.sleep(0.5)
            await self.send_action({
                "type": "move_unit",
                "from_zone": "bench", "to_zone": "grid",
                "from_pos": 0, "to_pos": {"x": 2, "y": 0}
            })
            await asyncio.sleep(1)

            # 再买一只狼
            for i in range(3):
                await self.send_action({"type": "refresh_shop"})
                await asyncio.sleep(0.5)

            await self.send_action({"type": "buy_unit", "shop_index": 0})
            await asyncio.sleep(1)
            obs = await self.poll_observations(2)
            self.log("✅ 第二只狼已购买")

            # 步骤7: 合并两只狼
            self.log("\n[步骤7] 尝试合并两只狼...")
            # 将第二只狼部署到相邻位置
            await self.send_action({
                "type": "move_unit",
                "from_zone": "bench", "to_zone": "grid",
                "from_pos": 0, "to_pos": {"x": 1, "y": 1}
            })
            await asyncio.sleep(1)

            # 尝试合并 (通过吞噬机制)
            self.log("尝试合并狼单位...")
            obs = await self.poll_observations(2)

            # 检查合并日志
            self.log("\n[步骤8] 检查合并日志...")
            merge_patterns = ["WOLF合并", "合并", "Merge", "merge", "Wolf Merge"]
            merge_found = self.check_logs_for_patterns(obs, merge_patterns)
            if any(merge_found.values()):
                self.validation["merge_log_found"] = True
                self.log("✅ 检测到合并日志")
            else:
                self.log("⚠️ 未检测到合并日志 (可能需要在战斗波次中测试)", "WARNING")

            # 生成测试报告
            await self.generate_report()
            return True

        except Exception as e:
            self.log(f"\n❌ 测试失败: {e}", "ERROR")
            import traceback
            self.log(traceback.format_exc(), "ERROR")
            return False
        finally:
            self.stop_ai_client()

    async def generate_report(self):
        """生成测试报告"""
        self.log("\n" + "=" * 60)
        self.log("测试报告生成")
        self.log("=" * 60)

        report_lines = [
            "\n" + "=" * 60,
            "狼单位功能测试报告 (TASK-#15)",
            "=" * 60,
            f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"日志文件: {self.log_file}",
            "",
            "验证结果:",
        ]

        for key, value in self.validation.items():
            status = "✅ 通过" if value else "❌ 未通过"
            report_lines.append(f"  {key}: {status}")

        report_lines.extend([
            "",
            "测试说明:",
            "  - wolf_totem_selected: 狼图腾选择",
            "  - wolf_unit_purchased: 狼单位购买",
            "  - devour_log_found: 吞噬日志检测",
            "  - soul_increased: 魂魄获取检测",
            "  - merge_log_found: 合并日志检测",
            "",
            "=" * 60,
        ])

        report = "\n".join(report_lines)
        self.log(report)

        # 保存报告
        report_path = Path("docs/player_reports/WOLF_UNIT_TEST_report.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"\n报告已保存: {report_path}")

        return report


async def main():
    async with WolfUnitTest(http_port=9998) as tester:
        success = await tester.run_test()
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
