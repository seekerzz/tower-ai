#!/usr/bin/env python3
"""
次级图腾选择功能测试脚本

测试内容：
1. 启动游戏并选择主图腾
2. 使用调试命令跳转到次级图腾选择阶段
3. 验证次级图腾选择界面显示
4. 选择次级图腾
5. 验证商店刷新时包含两个图腾的单位

使用方法：
    python3 ai_client/secondary_totem_test.py

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


class SecondaryTotemTest:
    """次级图腾选择功能测试器"""

    def __init__(self, http_port=9998):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_secondary_totem_{timestamp}.log"

        # 测试结果
        self.test_results = []
        self.validation = {
            "main_totem_selected": False,
            "secondary_totem_interface": False,
            "secondary_totem_selected": False,
            "dual_faction_shop": False,
        }

    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()

    def log(self, message: str, level="INFO"):
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        log_entry = f"[{timestamp}] [{level}] {message}"
        print(log_entry)
        with open(self.log_file, "a", encoding="utf-8") as f:
            f.write(log_entry + "\n")

    async def send_actions(self, actions: List[Dict]) -> Dict:
        try:
            async with self.session.post(
                f"{self.base_url}/action",
                json={"actions": actions},
                timeout=aiohttp.ClientTimeout(total=10)
            ) as resp:
                return await resp.json()
        except Exception as e:
            self.log(f"发送动作失败: {e}", "ERROR")
            return {"error": str(e)}

    async def get_observations(self) -> List[str]:
        try:
            async with self.session.get(
                f"{self.base_url}/observations",
                timeout=aiohttp.ClientTimeout(total=10)
            ) as resp:
                data = await resp.json()
                return data.get("observations", [])
        except Exception as e:
            self.log(f"获取观测失败: {e}", "ERROR")
            return []

    async def poll_observations(self, duration: float = 2.0) -> List[str]:
        all_obs = []
        start = time.time()
        while time.time() - start < duration:
            obs = await self.get_observations()
            all_obs.extend(obs)
            for o in obs:
                self.log(f"[OBS] {o}", "OBS")
            await asyncio.sleep(0.3)
        return all_obs

    async def wait_for_game_ready(self, timeout: float = 60.0) -> bool:
        self.log("等待游戏就绪...", "SYSTEM")
        start = time.time()
        while time.time() - start < timeout:
            try:
                async with self.session.get(f"{self.base_url}/status", timeout=aiohttp.ClientTimeout(total=3)) as resp:
                    data = await resp.json()
                    if data.get("godot_running") and data.get("ws_connected"):
                        self.log("游戏已就绪", "SYSTEM")
                        return True
            except:
                pass
            await asyncio.sleep(0.5)
        self.log("等待游戏就绪超时", "ERROR")
        return False

    def start_ai_client(self):
        self.log("启动AI客户端...", "SYSTEM")
        project_dir = Path(__file__).parent.parent
        client_script = project_dir / "ai_client" / "ai_game_client.py"

        env = os.environ.copy()
        env["PYTHONIOENCODING"] = "utf-8"

        self.client_process = subprocess.Popen(
            [
                sys.executable,
                str(client_script),
                "--project", str(project_dir),
                "--scene", "res://src/Scenes/UI/CoreSelection.tscn",
                "--http-port", str(self.http_port)
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            cwd=str(project_dir),
            env=env
        )
        time.sleep(12)
        self.log(f"AI客户端已启动 (PID: {self.client_process.pid})", "SYSTEM")

    def stop_ai_client(self):
        if self.client_process:
            self.log("停止AI客户端...", "SYSTEM")
            self.client_process.terminate()
            try:
                self.client_process.wait(timeout=5)
            except:
                self.client_process.kill()
            self.client_process = None

    async def run_test(self) -> bool:
        """运行次级图腾功能测试"""
        self.log("=" * 70, "SYSTEM")
        self.log("次级图腾选择功能测试", "SYSTEM")
        self.log("=" * 70, "SYSTEM")

        try:
            # 启动AI客户端
            self.start_ai_client()

            # 等待游戏就绪
            if not await self.wait_for_game_ready(60):
                self.log("游戏启动失败", "ERROR")
                return False

            # 步骤1: 选择主图腾
            main_totem = "cow_totem"
            self.log(f"步骤1: 选择主图腾 - {main_totem}", "TEST")
            await self.poll_observations(3.0)
            await self.send_actions([{"type": "select_totem", "totem_id": main_totem}])
            await asyncio.sleep(2.0)
            obs = await self.poll_observations(5.0)

            # 检查图腾选择完成
            for o in obs:
                if "图腾选择完成" in o or "主图腾" in o:
                    self.validation["main_totem_selected"] = True
                    self.log(f"主图腾选择确认: {o}", "SUCCESS")
                    break

            # 步骤2: 使用调试命令跳转到次级图腾选择
            self.log("步骤2: 使用调试命令跳转到次级图腾选择阶段", "TEST")
            await self.send_actions([{"type": "debug_skip_to_secondary_totem"}])
            await asyncio.sleep(2.0)

            # 等待次级图腾选择界面
            self.log("等待次级图腾选择界面...", "TEST")
            obs = await self.poll_observations(5.0)

            secondary_detected = False
            for o in obs:
                if "次级图腾选择" in o or "secondary_totem" in o.lower():
                    secondary_detected = True
                    self.validation["secondary_totem_interface"] = True
                    self.log(f"检测到次级图腾选择界面: {o}", "SUCCESS")
                    break

            if not secondary_detected:
                self.log("未检测到次级图腾选择界面，继续观察...", "WARNING")

            # 步骤3: 选择次级图腾
            secondary_totem = "wolf_totem"
            self.log(f"步骤3: 选择次级图腾 - {secondary_totem}", "TEST")
            await self.send_actions([{
                "type": "select_secondary_totem",
                "totem_id": secondary_totem
            }])
            await asyncio.sleep(2.0)
            obs = await self.poll_observations(3.0)

            # 检查次级图腾选择完成
            for o in obs:
                if "次级图腾" in o and ("选择" in o or "已选择" in o or "Wolf" in o or secondary_totem in o):
                    self.validation["secondary_totem_selected"] = True
                    self.log(f"次级图腾选择确认: {o}", "SUCCESS")
                    break

            # 步骤4: 验证商店刷新
            self.log("步骤4: 刷新商店并验证双阵营单位", "TEST")
            await self.send_actions([{"type": "refresh_shop"}])
            await asyncio.sleep(1.0)
            obs = await self.poll_observations(3.0)

            # 检查商店是否包含双阵营单位
            for o in obs:
                if "商店刷新" in o or "商店调试" in o:
                    self.log(f"商店信息: {o}", "INFO")
                    if "主阵营" in o or "次级阵营" in o or "cow" in o.lower() or "wolf" in o.lower():
                        self.validation["dual_faction_shop"] = True
                        self.log("检测到双阵营商店内容", "SUCCESS")

            # 测试完成
            self.log("=" * 70, "SYSTEM")
            self.log("测试结果汇总:", "SYSTEM")
            for key, value in self.validation.items():
                status = "通过" if value else "未通过"
                self.log(f"  {key}: {status}", "RESULT")
            self.log("=" * 70, "SYSTEM")

            return all(self.validation.values())

        except Exception as e:
            self.log(f"测试出错: {e}", "ERROR")
            import traceback
            traceback.print_exc()
            return False

        finally:
            self.stop_ai_client()


async def main():
    async with SecondaryTotemTest(http_port=9998) as test:
        success = await test.run_test()

        if success:
            test.log("=" * 70, "SYSTEM")
            test.log("测试通过!", "SUCCESS")
            test.log("=" * 70, "SYSTEM")
            return 0
        else:
            test.log("=" * 70, "SYSTEM")
            test.log("测试失败!", "ERROR")
            test.log("=" * 70, "SYSTEM")
            return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
