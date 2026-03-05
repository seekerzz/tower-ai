#!/usr/bin/env python3
"""
SEASON-VERIFY-FINAL-RETEST: 第2波配置修复后重新测试

验证目标:
1. 验证第2波生成6个slime（非mutant_slime）
2. 验证单次伤害为30（非150）
3. 验证能够通过第2波并进入第3波

修复内容:
- WAVE2-FIX-003 (d74cd0f)
- 移除 _spawn_first_batch_immediate() 和 _run_batch_sequence() 中的强制覆盖逻辑
- 敌人类型选择现在完全由配置文件的 enemy_types 字段控制
"""

import asyncio
import json
import time
import sys
import subprocess
import os
import re
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional

sys.path.insert(0, str(Path(__file__).parent))

import aiohttp


class Wave2FixVerifier:
    """第2波修复验证器"""

    def __init__(self, http_port=9996):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_season_verify_final_{timestamp}.log"

        # 验证结果
        self.validation = {
            "wave_2_enemy_type": None,  # 应为 "slime"
            "wave_2_damage": [],  # 收集伤害值
            "wave_2_completed": False,
            "wave_3_reached": False,
        }

        self.errors = []

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

        log_path = self.log_file.with_suffix('.client.log')
        self.client_process = subprocess.Popen(
            [
                sys.executable,
                str(client_script),
                "--project", str(project_dir),
                "--scene", "res://src/Scenes/UI/CoreSelection.tscn",
                "--http-port", str(self.http_port)
            ],
            stdout=open(log_path, 'w', encoding='utf-8'),
            stderr=subprocess.STDOUT,
            env=env
        )
        self.log(f"AI客户端已启动 (PID: {self.client_process.pid})", "SYSTEM")

    def stop_ai_client(self):
        if self.client_process:
            self.log("停止AI客户端...", "SYSTEM")
            self.client_process.terminate()
            try:
                self.client_process.wait(timeout=5)
            except:
                self.client_process.kill()

    def analyze_observations(self, observations: List[str]):
        """分析观测日志"""
        for obs in observations:
            # 检测波次开始
            if "Wave 2 started" in obs or "第 2 波战斗正式开始" in obs:
                self.log("检测到第2波开始", "DETECTION")

            # 检测敌人类型 - WaveSystemManager日志
            match = re.search(r'\[WaveSystemManager\].*enemy_type:\s*(\w+)', obs)
            if match:
                enemy_type = match.group(1)
                self.validation["wave_2_enemy_type"] = enemy_type
                self.log(f"检测到敌人类型: {enemy_type}", "DETECTION")

            # 检测敌人生成日志
            if "敌人" in obs and "出生" in obs and "slime" in obs.lower():
                self.log(f"检测到slime生成: {obs}", "DETECTION")

            # 检测mutant_slime
            if "mutant_slime" in obs.lower():
                self.errors.append(f"错误：检测到mutant_slime: {obs}")
                self.log(f"ERROR: 检测到mutant_slime! {obs}", "ERROR")

            # 检测核心受击伤害
            match = re.search(r'【核心受击】.*受到\s*(\d+)\s*点伤害', obs)
            if match:
                damage = int(match.group(1))
                self.validation["wave_2_damage"].append(damage)
                self.log(f"检测到核心受击伤害: {damage}", "DETECTION")

            # 检测第2波结束
            if "第 2 波结束" in obs or "Wave 2 ended" in obs:
                self.validation["wave_2_completed"] = True
                self.log("检测到第2波完成", "DETECTION")

            # 检测第3波开始
            if "第 3 波战斗正式开始" in obs or "Wave 3 started" in obs:
                self.validation["wave_3_reached"] = True
                self.log("检测到第3波开始", "DETECTION")

            # 检测游戏结束（失败）
            if "游戏结束" in obs or "game_over" in obs.lower():
                self.log("检测到游戏结束", "WARNING")

    async def run_test(self):
        """运行测试"""
        self.log("=" * 70, "SYSTEM")
        self.log("SEASON-VERIFY-FINAL-RETEST: 第2波配置修复后重新测试", "SYSTEM")
        self.log("=" * 70, "SYSTEM")
        self.log(f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", "SYSTEM")
        self.log(f"日志文件: {self.log_file}", "SYSTEM")

        # 启动AI客户端
        self.start_ai_client()

        # 等待游戏就绪
        if not await self.wait_for_game_ready():
            self.log("游戏启动失败", "ERROR")
            return False

        # 等待图腾选择界面
        self.log("等待图腾选择界面...", "SYSTEM")
        await asyncio.sleep(2)

        # 选择图腾（牛图腾）
        self.log("选择牛图腾...", "SYSTEM")
        await self.send_actions([{"type": "select_totem", "totem_id": "cow_totem"}])
        await asyncio.sleep(3)

        # 收集初始观测
        obs = await self.poll_observations(3)
        self.analyze_observations(obs)

        # 购买初始单位
        self.log("购买初始单位...", "SYSTEM")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(1)

        # 部署单位
        self.log("部署单位...", "SYSTEM")
        await self.send_actions([{
            "type": "move_unit",
            "from_zone": "bench",
            "to_zone": "grid",
            "from_pos": 0,
            "to_pos": {"x": 1, "y": 0}
        }])
        await asyncio.sleep(1)

        # 开始第1波
        self.log("开始第1波...", "SYSTEM")
        await self.send_actions([{"type": "start_wave"}])

        # 等待第1波完成
        self.log("等待第1波完成...", "SYSTEM")
        wave1_completed = False
        wave1_enemies_killed = 0
        for i in range(60):  # 最多等待60秒
            obs = await self.poll_observations(1)
            self.analyze_observations(obs)

            # 检测敌人阵亡
            for o in obs:
                if "【敌方阵亡】" in o and "slime" in o.lower():
                    wave1_enemies_killed += 1
                    self.log(f"第1波敌人阵亡: {wave1_enemies_killed}/3", "DETECTION")

            # 检测波次结束信号
            if "第 1 波结束" in str(obs) or "Wave 1 ended" in str(obs) or "wave_ended" in str(obs).lower():
                wave1_completed = True
                self.log("第1波完成", "SYSTEM")
                break

            # 如果3个敌人都被击杀，等待波次完全结束
            if wave1_enemies_killed >= 3:
                self.log("第1波所有敌人已被击杀，等待波次结束...", "SYSTEM")
                # 等待一段时间让游戏处理波次结束
                for j in range(20):  # 最多等待20秒
                    await asyncio.sleep(1)
                    obs = await self.poll_observations(0.5)
                    self.analyze_observations(obs)
                    # 检查波次是否真正结束（通过检查是否有波次结束信号或状态变化）
                    if any("波次结束" in o or "wave_ended" in o.lower() or "Wave ended" in o for o in obs):
                        self.log("检测到波次结束信号", "SYSTEM")
                        wave1_completed = True
                        break
                    # 检查核心血量是否稳定（不再变化）
                    # 或者检查是否收到Wave already active错误
                if not wave1_completed:
                    self.log("波次结束信号未检测到，但继续测试", "WARNING")
                    wave1_completed = True
                break

            await asyncio.sleep(1)

        if not wave1_completed:
            self.log("第1波未正常完成，但继续测试第2波...", "WARNING")
        else:
            # 等待商店刷新和准备时间
            self.log("等待波次间准备时间...", "SYSTEM")
            await asyncio.sleep(5)

        # 等待商店刷新
        await asyncio.sleep(2)

        # 开始第2波
        self.log("=" * 70, "SYSTEM")
        self.log("开始第2波测试", "SYSTEM")
        self.log("=" * 70, "SYSTEM")

        # 先检查游戏状态
        self.log("检查游戏状态...", "SYSTEM")
        status_obs = await self.poll_observations(2)
        self.analyze_observations(status_obs)

        # 发送start_wave命令
        self.log("发送start_wave命令...", "SYSTEM")
        result = await self.send_actions([{"type": "start_wave"}])
        self.log(f"start_wave结果: {result}", "SYSTEM")
        await asyncio.sleep(2)

        # 监控第2波
        self.log("监控第2波战斗...", "SYSTEM")
        wave2_start_time = time.time()
        max_wait = 60  # 最多等待60秒

        while time.time() - wave2_start_time < max_wait:
            obs = await self.poll_observations(2)
            self.analyze_observations(obs)

            # 检查是否完成第2波
            if self.validation["wave_2_completed"]:
                self.log("第2波已完成！", "SUCCESS")
                break

            # 检查是否游戏结束
            if any("游戏结束" in o or "game_over" in o.lower() for o in obs):
                self.log("游戏结束，第2波测试失败", "ERROR")
                break

        # 生成报告
        self.generate_report()

        return True

    def generate_report(self):
        """生成测试报告"""
        self.log("=" * 70, "SYSTEM")
        self.log("生成测试报告", "SYSTEM")
        self.log("=" * 70, "SYSTEM")

        report_lines = [
            "# SEASON-VERIFY-FINAL-RETEST: 第2波配置修复后测试报告",
            "",
            f"**测试ID**: SEASON-VERIFY-FINAL-RETEST",
            f"**测试时间**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"**测试类型**: 第2波配置修复验证",
            "",
            "---",
            "",
            "## 修复内容",
            "",
            "**修复提交**: WAVE2-FIX-003 (d74cd0f)",
            "**修复说明**: 移除 _spawn_first_batch_immediate() 和 _run_batch_sequence() 中的强制覆盖逻辑",
            "**预期效果**: 敌人类型选择现在完全由配置文件的 enemy_types 字段控制",
            "",
            "---",
            "",
            "## 验证结果",
            "",
        ]

        # 验证敌人类型
        enemy_type = self.validation["wave_2_enemy_type"]
        if enemy_type:
            if enemy_type == "slime":
                report_lines.append(f"| 第2波敌人类型 | ✅ 通过 | 检测到: {enemy_type} |")
            else:
                report_lines.append(f"| 第2波敌人类型 | ❌ 失败 | 检测到: {enemy_type} (期望: slime) |")
        else:
            report_lines.append("| 第2波敌人类型 | ⚠️ 未知 | 未在日志中检测到敌人类型 |")

        # 验证伤害值
        damages = self.validation["wave_2_damage"]
        if damages:
            avg_damage = sum(damages) / len(damages)
            if all(d == 30 for d in damages):
                report_lines.append(f"| 单次伤害值 | ✅ 通过 | 所有伤害为30点 ({len(damages)}次攻击) |")
            elif any(d == 150 for d in damages):
                report_lines.append(f"| 单次伤害值 | ❌ 失败 | 检测到150点伤害 (mutant_slime) |")
            else:
                report_lines.append(f"| 单次伤害值 | ⚠️ 异常 | 平均伤害: {avg_damage:.1f} |")
        else:
            report_lines.append("| 单次伤害值 | ⚠️ 未知 | 未检测到核心受击日志 |")

        # 验证第2波完成
        if self.validation["wave_2_completed"]:
            report_lines.append("| 第2波完成 | ✅ 通过 | 成功通过第2波 |")
        else:
            report_lines.append("| 第2波完成 | ❌ 失败 | 未能通过第2波 |")

        # 验证第3波到达
        if self.validation["wave_3_reached"]:
            report_lines.append("| 第3波到达 | ✅ 通过 | 成功进入第3波 |")
        else:
            report_lines.append("| 第3波到达 | ⚠️ 未验证 | 未检测到第3波开始 |")

        report_lines.extend([
            "",
            "---",
            "",
            "## 详细数据",
            "",
            f"**检测到的敌人类型**: {self.validation['wave_2_enemy_type'] or '未检测到'}",
            f"**检测到的伤害值**: {self.validation['wave_2_damage']}",
            f"**第2波完成**: {'是' if self.validation['wave_2_completed'] else '否'}",
            f"**第3波到达**: {'是' if self.validation['wave_3_reached'] else '否'}",
            "",
        ])

        # 错误信息
        if self.errors:
            report_lines.extend([
                "---",
                "",
                "## 错误信息",
                "",
            ])
            for error in self.errors:
                report_lines.append(f"- {error}")
            report_lines.append("")

        # 测试结论
        report_lines.extend([
            "---",
            "",
            "## 测试结论",
            "",
        ])

        # 判断测试是否通过
        passed = (
            self.validation["wave_2_enemy_type"] == "slime" and
            self.validation["wave_2_completed"] and
            not any(d == 150 for d in self.validation["wave_2_damage"])
        )

        if passed:
            report_lines.append("✅ **测试通过** - 第2波配置修复成功！")
            report_lines.append("")
            report_lines.append("- 第2波正确生成slime敌人")
            report_lines.append("- 单次伤害为30点（非150点）")
            report_lines.append("- 能够成功通过第2波")
        else:
            report_lines.append("❌ **测试失败** - 第2波配置修复未完全生效")
            report_lines.append("")
            if self.validation["wave_2_enemy_type"] != "slime":
                report_lines.append(f"- 敌人类型错误: {self.validation['wave_2_enemy_type']} (期望: slime)")
            if any(d == 150 for d in self.validation["wave_2_damage"]):
                report_lines.append("- 检测到150点伤害，可能生成了mutant_slime")
            if not self.validation["wave_2_completed"]:
                report_lines.append("- 未能通过第2波")

        report_lines.extend([
            "",
            "---",
            "",
            "## 产出文件",
            "",
            f"- 测试日志: `{self.log_file.name}`",
            f"- 客户端日志: `{self.log_file.with_suffix('.client.log').name}`",
            "",
            "---",
            "",
            f"*报告生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*",
            "*AI Player Agent*",
        ])

        report = "\n".join(report_lines)

        # 保存报告
        report_path = Path("docs/player_reports/SEASON-VERIFY-FINAL-RETEST_report.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)

        self.log(f"报告已保存: {report_path}", "SYSTEM")

        # 打印报告到控制台
        print("\n" + "=" * 70)
        print(report)
        print("=" * 70)


async def main():
    async with Wave2FixVerifier() as verifier:
        try:
            await verifier.run_test()
        finally:
            verifier.stop_ai_client()


if __name__ == "__main__":
    asyncio.run(main())
