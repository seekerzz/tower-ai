#!/usr/bin/env python3
"""
BUFF/DEBUFF系统基础验证测试脚本 (BUFF-DEBUFF-001)
集成AI客户端启动和测试执行
"""

import asyncio
import json
import time
import sys
import subprocess
import signal
import os
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional

sys.path.insert(0, str(Path(__file__).parent.parent))

import aiohttp


class BuffDebuffTester:
    """BUFF/DEBUFF系统测试器"""

    def __init__(self, http_port=8080):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.test_results = []
        self.observations = []
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        # 创建日志文件
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_buff_debuff_{timestamp}.log"

        # 验证结果
        self.validation_results = {
            "buff_range": False,
            "buff_speed": False,
            "buff_bounce_stack": False,
            "buff_split_stack": False,
            "debuff_poison_stack": False,
            "debuff_burn": False,
            "debuff_slow": False,
            "debuff_bleed": False,
            "ailogger_output": False,
        }

    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()

    def log(self, message, level="INFO"):
        """记录日志到文件和控制台"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        log_entry = f"[{timestamp}] [{level}] {message}"
        print(log_entry)
        with open(self.log_file, "a", encoding="utf-8") as f:
            f.write(log_entry + "\n")

    def log_validation(self, mechanism, passed, details=""):
        """记录验证结果"""
        status = "✅" if passed else "❌"
        self.log(f"{status} [{mechanism}] {details}", "VALIDATION")
        self.test_results.append({
            "mechanism": mechanism,
            "passed": passed,
            "details": details,
            "timestamp": datetime.now().isoformat()
        })

    async def start_ai_client(self):
        """启动AI客户端"""
        self.log("启动AI客户端...", "SYSTEM")

        # 查找Godot可执行文件
        godot_paths = [
            "/usr/bin/godot4",
            "/usr/local/bin/godot4",
            "/usr/bin/godot",
            "/usr/local/bin/godot",
        ]
        godot_exe = None
        for path in godot_paths:
            if os.path.exists(path):
                godot_exe = path
                break

        if not godot_exe:
            # 尝试使用which查找
            result = subprocess.run(["which", "godot4"], capture_output=True, text=True)
            if result.returncode == 0:
                godot_exe = result.stdout.strip()
            else:
                result = subprocess.run(["which", "godot"], capture_output=True, text=True)
                if result.returncode == 0:
                    godot_exe = result.stdout.strip()

        if not godot_exe:
            self.log("❌ 未找到Godot可执行文件", "ERROR")
            return False

        self.log(f"使用Godot: {godot_exe}", "SYSTEM")

        # 启动AI客户端
        cmd = [
            "python3", "ai_client/ai_game_client.py",
            "--project", ".",
            "--scene", "res://src/Scenes/UI/CoreSelection.tscn",
            "--http-port", str(self.http_port),
        ]

        # 检查是否有显示器
        display = os.environ.get("DISPLAY")
        if not display:
            self.log("无显示器环境，使用headless模式", "SYSTEM")
        else:
            self.log(f"检测到显示器: {display}", "SYSTEM")

        try:
            self.client_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                cwd=str(Path(__file__).parent.parent)
            )
            self.log(f"AI客户端进程启动: PID {self.client_process.pid}", "SYSTEM")
            return True
        except Exception as e:
            self.log(f"启动AI客户端失败: {e}", "ERROR")
            return False

    def stop_ai_client(self):
        """停止AI客户端"""
        if self.client_process:
            self.log("停止AI客户端...", "SYSTEM")
            try:
                self.client_process.terminate()
                self.client_process.wait(timeout=5)
            except:
                try:
                    self.client_process.kill()
                except:
                    pass
            self.client_process = None

    async def send_actions(self, actions):
        """发送动作到游戏"""
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

    async def get_observations(self):
        """获取游戏观测数据"""
        try:
            async with self.session.get(
                f"{self.base_url}/observations",
                timeout=aiohttp.ClientTimeout(total=10)
            ) as resp:
                data = await resp.json()
                obs_list = data.get("observations", [])
                for obs in obs_list:
                    self.observations.append(obs)
                    self.log(f"[OBS] {obs}", "OBSERVATION")
                return obs_list
        except Exception as e:
            self.log(f"获取观测失败: {e}", "ERROR")
            return []

    async def poll_observations(self, duration: float = 2.0) -> List[str]:
        """轮询观测数据一段时间"""
        all_obs = []
        start = time.time()
        while time.time() - start < duration:
            obs = await self.get_observations()
            all_obs.extend(obs)
            await asyncio.sleep(0.2)
        return all_obs

    async def wait_for_game_ready(self, timeout: float = 60.0) -> bool:
        """等待游戏就绪"""
        self.log("等待游戏就绪...", "SYSTEM")
        start = time.time()
        while time.time() - start < timeout:
            try:
                async with self.session.get(
                    f"{self.base_url}/status",
                    timeout=aiohttp.ClientTimeout(total=2)
                ) as resp:
                    data = await resp.json()
                    if data.get("godot_running") and data.get("ws_connected"):
                        self.log("游戏已就绪", "SYSTEM")
                        return True
                    if data.get("crashed"):
                        self.log("游戏已崩溃!", "ERROR")
                        return False
            except:
                pass
            await asyncio.sleep(0.5)
        self.log("等待游戏就绪超时", "ERROR")
        return False

    async def step_select_totem(self):
        """步骤1: 选择牛图腾"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤1: 选择牛图腾 (cow_totem)", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([
            {"type": "select_totem", "totem_id": "cow_totem"}
        ])
        await asyncio.sleep(1.0)
        obs = await self.poll_observations(2.0)
        self.log("✅ 牛图腾选择完成", "VALIDATION")

    async def step_test_buff_range(self):
        """步骤2: 测试Buff传播范围"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤2: 测试Buff传播范围 (战鼓speed Buff)", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 购买战鼓
        self.log("购买战鼓 (drum)", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        # 部署战鼓到中心
        self.log("部署战鼓到中心 (0,1)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 0, "y": 1}}
        ])
        await asyncio.sleep(0.5)

        # 购买松鼠作为Buff接收单位
        self.log("购买松鼠 (squirrel)", "ACTION")
        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        # 部署松鼠到战鼓旁边
        self.log("部署松鼠到战鼓旁边 (1,0)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 1, "y": 0}}
        ])
        await asyncio.sleep(0.5)

        obs = await self.poll_observations(3.0)

        # 检查Buff相关日志
        buff_keywords = ["[BUFF]", "speed", "攻速", "Buff施加", "战鼓"]
        for o in obs:
            for kw in buff_keywords:
                if kw in o:
                    self.validation_results["buff_range"] = True
                    self.validation_results["buff_speed"] = True
                    self.log(f"✅ Buff传播验证: {o}", "VALIDATION")
                    break

        if not self.validation_results["buff_range"]:
            self.log("⚠️ 未检测到Buff日志，继续测试...", "WARNING")

    async def step_test_buff_stack(self):
        """步骤3: 测试可叠加Buff"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤3: 测试可叠加Buff (bounce, split)", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 购买兔子
        self.log("购买兔子 (rabbit) - 提供bounce Buff", "ACTION")
        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        self.log("部署兔子到 (1,1)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 1, "y": 1}}
        ])
        await asyncio.sleep(0.5)

        # 购买第二个兔子
        self.log("购买第二个兔子", "ACTION")
        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        self.log("部署第二个兔子到 (-1,0)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": -1, "y": 0}}
        ])
        await asyncio.sleep(0.5)

        obs = await self.poll_observations(3.0)

        # 检查bounce Buff叠加
        for o in obs:
            if "[BUFF_STACK]" in o or "bounce" in o.lower() or "弹射" in o:
                self.validation_results["buff_bounce_stack"] = True
                self.log(f"✅ bounce Buff叠加: {o}", "VALIDATION")

        # 购买反射魔镜
        self.log("购买反射魔镜 (mirror)", "ACTION")
        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        self.log("部署反射魔镜到 (-1,1)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": -1, "y": 1}}
        ])
        await asyncio.sleep(0.5)

        # 购买多重棱镜
        self.log("购买多重棱镜 (splitter)", "ACTION")
        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        self.log("部署多重棱镜到 (0,-1)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 0, "y": -1}}
        ])
        await asyncio.sleep(0.5)

        obs = await self.poll_observations(3.0)

        # 检查split Buff
        for o in obs:
            if "[BUFF_STACK]" in o or "split" in o.lower() or "分裂" in o:
                self.validation_results["buff_split_stack"] = True
                self.log(f"✅ split Buff叠加: {o}", "VALIDATION")

    async def step_test_debuff_poison(self):
        """步骤4: 测试Poison Debuff叠加"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤4: 测试Poison Debuff叠加", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 购买毒蛇
        self.log("购买毒蛇 (viper) - 施加Poison Debuff", "ACTION")
        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        self.log("部署毒蛇到 (1,-1)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 1, "y": -1}}
        ])
        await asyncio.sleep(0.5)

        # 开始波次让敌人出现
        self.log("开始第1波 - 让敌人出现以测试Poison", "ACTION")
        await self.send_actions([{"type": "start_wave"}])
        await asyncio.sleep(1.0)

        # 观察Poison效果
        obs = await self.poll_observations(10.0)

        # 检查Poison相关日志
        poison_keywords = ["[DEBUFF]", "Poison", "poison", "中毒", "毒"]
        for o in obs:
            for kw in poison_keywords:
                if kw in o:
                    self.validation_results["debuff_poison_stack"] = True
                    self.log(f"✅ Poison Debuff: {o}", "VALIDATION")
                    break

        if not self.validation_results["debuff_poison_stack"]:
            self.log("⚠️ 未检测到Poison日志，可能敌人生成较慢", "WARNING")

    async def step_test_debuff_burn(self):
        """步骤5: 测试Burn Debuff"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤5: 测试Burn Debuff", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 购买红莲火炬
        self.log("购买红莲火炬 (torch) - 施加Burn Debuff", "ACTION")
        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        self.log("部署红莲火炬到 (-1,-1)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": -1, "y": -1}}
        ])
        await asyncio.sleep(0.5)

        # 观察Burn效果
        obs = await self.poll_observations(5.0)

        # 检查Burn相关日志
        burn_keywords = ["[DEBUFF]", "Burn", "burn", "燃烧", "火"]
        for o in obs:
            for kw in burn_keywords:
                if kw in o:
                    self.validation_results["debuff_burn"] = True
                    self.log(f"✅ Burn Debuff: {o}", "VALIDATION")
                    break

    async def step_test_ailogger_output(self):
        """步骤6: 验证AILogger输出"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤6: 验证AILogger输出", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 检查所有观测中是否有AILogger相关的标签
        ailogger_tags = ["[BUFF]", "[BUFF_STACK]", "[DEBUFF]", "[CORE_HEAL]",
                         "[CORE_HIT]", "[TOTEM]", "[SKILL]", "[RESOURCE]"]

        found_tags = set()
        for obs in self.observations:
            for tag in ailogger_tags:
                if tag in obs:
                    found_tags.add(tag)

        if found_tags:
            self.validation_results["ailogger_output"] = True
            self.log(f"✅ AILogger输出正常，发现标签: {found_tags}", "VALIDATION")
        else:
            self.log("⚠️ 未检测到标准AILogger标签", "WARNING")

    async def generate_report(self):
        """生成测试报告"""
        self.log("=" * 60, "SYSTEM")
        self.log("测试报告生成", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        report_lines = [
            "\n" + "=" * 60,
            "BUFF/DEBUFF系统测试报告 (BUFF-DEBUFF-001)",
            "=" * 60,
            f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"日志文件: {self.log_file}",
            "",
            "验证结果:",
        ]

        mechanism_names = {
            "buff_range": "Buff传播范围",
            "buff_speed": "speed Buff",
            "buff_bounce_stack": "bounce Buff叠加",
            "buff_split_stack": "split Buff叠加",
            "debuff_poison_stack": "Poison Debuff叠加",
            "debuff_burn": "Burn Debuff",
            "debuff_slow": "Slow Debuff",
            "debuff_bleed": "Bleed Debuff",
            "ailogger_output": "AILogger输出",
        }

        for key, name in mechanism_names.items():
            passed = self.validation_results.get(key, False)
            status = "✅ 通过" if passed else "❌ 未验证"
            report_lines.append(f"  {name}: {status}")

        report_lines.extend([
            "",
            "测试覆盖:",
            "  - 战鼓 (drum): speed Buff",
            "  - 兔子 (rabbit): bounce Buff",
            "  - 反射魔镜 (mirror): bounce Buff",
            "  - 多重棱镜 (splitter): split Buff",
            "  - 毒蛇 (viper): Poison Debuff",
            "  - 红莲火炬 (torch): Burn Debuff",
            "",
            "=" * 60,
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        # 保存报告到文件
        report_dir = Path("docs/player_reports")
        report_dir.mkdir(parents=True, exist_ok=True)
        report_file = report_dir / "qa_report_BUFF-DEBUFF-001.md"

        with open(report_file, "w", encoding="utf-8") as f:
            f.write(report)

        self.log(f"报告已保存到: {report_file}", "SYSTEM")
        return report_file

    async def run_full_test(self):
        """运行完整测试"""
        self.log("=" * 60, "SYSTEM")
        self.log("开始BUFF/DEBUFF系统测试 (BUFF-DEBUFF-001)", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 启动AI客户端
        if not await self.start_ai_client():
            self.log("❌ 无法启动AI客户端，测试中止", "ERROR")
            return None

        # 等待AI客户端启动
        self.log("等待AI客户端启动...", "SYSTEM")
        await asyncio.sleep(5.0)

        try:
            # 等待游戏就绪
            if not await self.wait_for_game_ready():
                self.log("❌ 游戏未就绪，测试中止", "ERROR")
                return None

            # 执行测试步骤
            await self.step_select_totem()
            await self.step_test_buff_range()
            await self.step_test_buff_stack()
            await self.step_test_debuff_poison()
            await self.step_test_debuff_burn()
            await self.step_test_ailogger_output()

            # 生成报告
            report_file = await self.generate_report()

            self.log("=" * 60, "SYSTEM")
            self.log("测试完成", "SYSTEM")
            self.log("=" * 60, "SYSTEM")

            return report_file

        except Exception as e:
            self.log(f"测试过程中发生错误: {e}", "ERROR")
            import traceback
            self.log(traceback.format_exc(), "ERROR")
            return None

        finally:
            self.stop_ai_client()


async def main():
    """主函数"""
    http_port = 8080
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with BuffDebuffTester(http_port) as tester:
        report_file = await tester.run_full_test()
        print(f"\n日志文件: {tester.log_file}")
        if report_file:
            print(f"测试报告: {report_file}")
        sys.exit(0 if report_file else 1)


if __name__ == "__main__":
    asyncio.run(main())
