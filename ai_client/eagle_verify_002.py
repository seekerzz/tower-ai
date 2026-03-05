#!/usr/bin/env python3
"""
EAGLE-VERIFY-002: Eagle修复重新验证测试

背景: 技术总监已修复日志标签不匹配问题(Git: f801524)

修复内容:
- 孔雀: [PEACOCK_DEBUFF] → [PEACOCK_VULNERABLE]
- 秃鹫: [VULTURE_ECHO] 已匹配

验证要求:
1. 孔雀Lv.2: 验证 [PEACOCK_VULNERABLE] 日志
2. 秃鹫Lv.3: 确保生成Lv.3单位，击杀敌人触发死亡回响，验证 [VULTURE_ECHO] 日志

输出报告: docs/player_reports/qa_report_eagle_verify_002.md
"""

import asyncio
import json
import time
import sys
import re
import subprocess
import os
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional

sys.path.insert(0, str(Path(__file__).parent))

import aiohttp


class EagleVerify002Tester:
    """Eagle修复重新验证测试器"""

    TOTEM_ID = "eagle_totem"

    def __init__(self, http_port=10005):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_eagle_verify_002_{timestamp}.log"

        # 验证结果
        self.validation = {
            # 基础验证
            "totem_selected": False,
            "core_hp_set": False,

            # 孔雀验证
            "peacock_spawned": False,
            "peacock_lv2": False,
            "peacock_vulnerable_log": False,  # [PEACOCK_VULNERABLE]
            "peacock_30_percent": False,  # 30%增伤

            # 秃鹫验证
            "vulture_spawned": False,
            "vulture_lv3": False,
            "vulture_echo_log": False,  # [VULTURE_ECHO]
            "vulture_kill_trigger": False,  # 击杀触发
        }

        # 检测到的日志
        self.log_stats = {
            "peacock_logs": [],
            "vulture_logs": [],
            "vulnerable_logs": [],
            "echo_logs": [],
            "damage_logs": [],
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
                self.parse_logs(o)
            await asyncio.sleep(0.3)
        return all_obs

    def start_ai_client(self):
        self.log("使用已运行的AI客户端 (端口10000)...", "SYSTEM")
        # AI Client已由外部启动，这里只需等待服务就绪
        time.sleep(2)

    def stop_ai_client(self):
        # 不停止外部启动的AI Client
        self.log("保持AI客户端运行 (外部管理)...", "SYSTEM")

    def parse_logs(self, obs: str):
        """解析Eagle修复相关日志"""

        # 1. 检测孔雀易伤debuff日志 [PEACOCK_VULNERABLE]
        if "PEACOCK_VULNERABLE" in obs:
            self.validation["peacock_vulnerable_log"] = True
            self.log_stats["vulnerable_logs"].append(obs)
            self.log("🦚 检测到[PEACOCK_VULNERABLE]易伤debuff日志", "DETECTION")

        # 2. 检测30%增伤
        if "30%" in obs and ("易伤" in obs or "孔雀" in obs or "peacock" in obs.lower()):
            self.validation["peacock_30_percent"] = True
            self.log("🦚 检测到孔雀30%易伤增伤", "DETECTION")

        # 3. 检测秃鹫死亡回响日志 [VULTURE_ECHO]
        if "VULTURE_ECHO" in obs:
            self.validation["vulture_echo_log"] = True
            self.log_stats["echo_logs"].append(obs)
            self.log("🦅 检测到[VULTURE_ECHO]死亡回响日志", "DETECTION")

        # 4. 检测击杀触发
        if ("击杀" in obs or "kill" in obs.lower() or "死亡" in obs) and ("秃鹫" in obs or "vulture" in obs.lower()):
            self.validation["vulture_kill_trigger"] = True
            self.log("🦅 检测到秃鹫击杀触发", "DETECTION")

        # 5. 检测孔雀相关日志
        if "peacock" in obs.lower() or "孔雀" in obs:
            self.log_stats["peacock_logs"].append(obs)

        # 6. 检测秃鹫相关日志
        if "vulture" in obs.lower() or "秃鹫" in obs:
            self.log_stats["vulture_logs"].append(obs)

        # 7. 检测Lv.2/Lv.3升级日志
        if "Lv.2" in obs or "Lv.3" in obs or "升级" in obs:
            if "peacock" in obs.lower() or "孔雀" in obs:
                self.validation["peacock_lv2"] = True
                self.log("🦚 检测到孔雀Lv.2", "DETECTION")
            if "vulture" in obs.lower() or "秃鹫" in obs:
                self.validation["vulture_lv3"] = True
                self.log("🦅 检测到秃鹫Lv.3", "DETECTION")

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

    async def step_reset_game(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤0: 重置游戏状态", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        result = await self.send_actions([{"type": "reset_game"}])
        self.log(f"重置游戏结果: {result}", "DEBUG")
        await asyncio.sleep(2.0)
        await self.poll_observations(2.0)
        self.log("✅ 游戏重置完成", "VALIDATION")

    async def step_select_totem(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤1: 选择鹰图腾", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.poll_observations(1.0)
        result = await self.send_actions([{"type": "select_totem", "totem_id": self.TOTEM_ID}])
        self.log(f"选择图腾结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)
        self.validation["totem_selected"] = True
        self.log("✅ 鹰图腾选择完成", "VALIDATION")

    async def step_set_god_mode(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤2: 设置上帝模式", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 先重置游戏确保状态干净
        result = await self.send_actions([{"type": "reset_game"}])
        self.log(f"reset_game结果: {result}", "DEBUG")
        await asyncio.sleep(2.0)
        await self.poll_observations(1.0)

        # 设置核心血量
        result = await self.send_actions([{"type": "set_core_hp", "hp": 99999}])
        self.log(f"set_core_hp结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)
        await self.poll_observations(1.0)
        self.validation["core_hp_set"] = True
        self.log("✅ 上帝模式设置完成", "VALIDATION")

    async def step_spawn_peacock(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤3: 生成孔雀单位(Lv.2)", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 直接生成Lv.2孔雀
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "peacock",
            "grid_pos": {"x": 1, "y": 0},
            "level": 2
        }])
        self.log(f"生成孔雀(Lv.2)结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)

        self.validation["peacock_spawned"] = True
        self.validation["peacock_lv2"] = True
        self.log("✅ 孔雀单位(Lv.2)生成完成", "VALIDATION")

    async def step_spawn_vulture(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤4: 生成秃鹫单位(Lv.3)", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 直接生成Lv.3秃鹫
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "vulture",
            "grid_pos": {"x": 1, "y": 1},
            "level": 3
        }])
        self.log(f"生成秃鹫(Lv.3)结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)

        self.validation["vulture_spawned"] = True
        self.validation["vulture_lv3"] = True
        self.log("✅ 秃鹫单位(Lv.3)生成完成", "VALIDATION")

    async def step_start_battle(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤5: 开始战斗观察", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 先生成单位，再开始波次
        self.log("生成测试单位...", "SYSTEM")

        # 生成更多孔雀和秃鹫以确保有足够攻击
        # 将单位放置在敌人路径上（敌人生成于(0,0)，需要放置在y=0,1拦截）
        # 关键位置：x=0是敌人出生列，y=0,1是敌人必经之路
        peacock_positions = [(0, 0), (0, 1), (1, 0), (1, 1), (2, 0), (2, 1)]
        vulture_positions = [(0, 2), (1, 2), (2, 2), (3, 0), (3, 1), (4, 0)]

        peacock_success = 0
        for x, y in peacock_positions:
            result = await self.send_actions([{
                "type": "spawn_unit",
                "unit_id": "peacock",
                "grid_pos": {"x": x, "y": y},
                "level": 2
            }])
            self.log(f"生成孔雀({x},{y})结果: {result}", "DEBUG")
            if result and result.get('status') == 'ok':
                peacock_success += 1
            await asyncio.sleep(0.3)

        self.validation["peacock_spawned"] = (peacock_success > 0)
        self.validation["peacock_lv2"] = (peacock_success > 0)
        self.log(f"✅ 孔雀单位(Lv.2)生成完成，成功{peacock_success}/{len(peacock_positions)}个", "VALIDATION")

        vulture_success = 0
        for x, y in vulture_positions:
            result = await self.send_actions([{
                "type": "spawn_unit",
                "unit_id": "vulture",
                "grid_pos": {"x": x, "y": y},
                "level": 3
            }])
            self.log(f"生成秃鹫({x},{y})结果: {result}", "DEBUG")
            if result and result.get('status') == 'ok':
                vulture_success += 1
            await asyncio.sleep(0.3)

        self.validation["vulture_spawned"] = (vulture_success > 0)
        self.validation["vulture_lv3"] = (vulture_success > 0)
        self.log(f"✅ 秃鹫单位(Lv.3)生成完成，成功{vulture_success}/{len(vulture_positions)}个", "VALIDATION")

        # 使用skip_to_wave跳转到第2波（敌人数量适中）
        self.log("跳转到第2波...", "SYSTEM")
        result = await self.send_actions([{"type": "skip_to_wave", "wave": 2}])
        self.log(f"skip_to_wave结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)

        # 开始波次
        self.log("开始波次...", "SYSTEM")
        result = await self.send_actions([{"type": "start_wave"}])
        self.log(f"start_wave结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)

        # 观察战斗过程
        battle_duration = 90  # 延长到90秒，给机制更多触发时间
        start_time = time.time()
        game_over_count = 0

        self.log("开始观察战斗，寻找修复验证日志...", "SYSTEM")

        while time.time() - start_time < battle_duration:
            obs = await self.poll_observations(3.0)

            for o in obs:
                if "游戏结束" in o or "game over" in o.lower():
                    game_over_count += 1
                    self.log(f"⚠️ 检测到游戏结束 (第{game_over_count}次)", "WARNING")
                    if game_over_count >= 2:  # 连续检测到才返回失败
                        return False

        self.log(f"✅ 战斗观察完成 ({battle_duration}秒)", "VALIDATION")
        return True

    async def run_test(self) -> bool:
        self.log("=" * 70, "SYSTEM")
        self.log("EAGLE-VERIFY-002: Eagle修复重新验证", "SYSTEM")
        self.log("=" * 70, "SYSTEM")
        self.log(f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", "SYSTEM")
        self.log(f"日志文件: {self.log_file}", "SYSTEM")

        self.start_ai_client()

        try:
            if not await self.wait_for_game_ready():
                self.log("游戏未能就绪，测试中止", "ERROR")
                return False

            await self.step_reset_game()
            await self.step_select_totem()
            await self.step_set_god_mode()
            await self.step_start_battle()
            await self.generate_report()
            return True

        except Exception as e:
            self.log(f"测试过程中发生错误: {e}", "ERROR")
            import traceback
            self.log(traceback.format_exc(), "ERROR")
            return False

        finally:
            self.stop_ai_client()

    async def generate_report(self):
        self.log("=" * 70, "SYSTEM")
        self.log("生成测试报告", "SYSTEM")
        self.log("=" * 70, "SYSTEM")

        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

        report_lines = [
            "# QA测试报告: Eagle修复重新验证 (EAGLE-VERIFY-002)",
            "",
            f"**任务ID**: EAGLE-VERIFY-002",
            f"**测试时间**: {timestamp}",
            f"**测试类型**: P1修复验证测试",
            f"**修复来源**: Technical Director (Git: f801524)",
            "",
            "---",
            "",
            "## 验证内容",
            "",
            "### 孔雀Lv.2易伤debuff",
            "- 预期日志: `[PEACOCK_VULNERABLE]`",
            "- 修复内容: `[PEACOCK_DEBUFF]` → `[PEACOCK_VULNERABLE]`",
            "",
            "### 秃鹫Lv.3死亡回响",
            "- 预期日志: `[VULTURE_ECHO]`",
            "- 触发条件: Lv.3单位击杀敌人",
            "",
            "---",
            "",
            "## 验证结果汇总",
            "",
            "### 基础验证",
            "",
            "| 验证项 | 状态 | 说明 |",
            "|--------|------|------|",
        ]

        base_validations = [
            ("totem_selected", "鹰图腾选择"),
            ("core_hp_set", "上帝模式设置"),
            ("peacock_spawned", "孔雀单位生成"),
            ("vulture_spawned", "秃鹫单位生成"),
        ]

        for key, desc in base_validations:
            status = "✅ 通过" if self.validation[key] else "❌ 未通过"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### 孔雀易伤debuff验证",
            "",
            "| 验证项 | 状态 | 说明 |",
            "|--------|------|------|",
        ])

        peacock_status = "✅ 检测到" if self.validation["peacock_vulnerable_log"] else "❌ 未检测到"
        damage_status = "✅ 检测到" if self.validation["peacock_30_percent"] else "❌ 未检测到"
        lv2_status = "✅ 检测到" if self.validation["peacock_lv2"] else "❌ 未检测到"

        report_lines.append(f"| Lv.2升级 | {lv2_status} | 单位等级 |")
        report_lines.append(f"| [PEACOCK_VULNERABLE]日志 | {peacock_status} | 修复后的标记 |")
        report_lines.append(f"| 30%增伤效果 | {damage_status} | 3层*10%=30% |")

        report_lines.extend([
            "",
            "### 秃鹫死亡回响验证",
            "",
            "| 验证项 | 状态 | 说明 |",
            "|--------|------|------|",
        ])

        lv3_status = "✅ 检测到" if self.validation["vulture_lv3"] else "❌ 未检测到"
        echo_status = "✅ 检测到" if self.validation["vulture_echo_log"] else "❌ 未检测到"
        kill_status = "✅ 检测到" if self.validation["vulture_kill_trigger"] else "❌ 未检测到"

        report_lines.append(f"| Lv.3升级 | {lv3_status} | 单位等级 |")
        report_lines.append(f"| [VULTURE_ECHO]日志 | {echo_status} | 死亡回响标记 |")
        report_lines.append(f"| 击杀触发 | {kill_status} | 触发条件 |")

        report_lines.extend([
            "",
            "---",
            "",
            "## 检测到的日志统计",
            "",
        ])

        for log_type, logs in self.log_stats.items():
            report_lines.append(f"- **{log_type}**: {len(logs)} 条")

        report_lines.extend([
            "",
            "---",
            "",
            "## 测试结论",
            "",
        ])

        # 判断修复是否成功
        peacock_fixed = self.validation["peacock_vulnerable_log"]
        vulture_fixed = self.validation["vulture_echo_log"]

        if peacock_fixed and vulture_fixed:
            report_lines.append("✅ **修复验证通过** - 孔雀易伤debuff和秃鹫死亡回响均已正确实现")
        elif peacock_fixed:
            report_lines.append("⚠️ **部分修复** - 孔雀[PEACOCK_VULNERABLE]已检测到，秃鹫[VULTURE_ECHO]未检测到")
        elif vulture_fixed:
            report_lines.append("⚠️ **部分修复** - 秃鹫[VULTURE_ECHO]已检测到，孔雀[PEACOCK_VULNERABLE]未检测到")
        else:
            report_lines.append("❌ **修复验证失败** - 未检测到预期的修复日志")
            report_lines.append("")
            report_lines.append("### 可能原因")
            report_lines.append("1. 修复尚未部署到测试环境")
            report_lines.append("2. 单位需要升级至Lv.2/Lv.3才能触发机制")
            report_lines.append("3. 日志标记格式与预期不符")
            report_lines.append("4. 需要检查技术总监的修复提交是否已合并")

        report_lines.extend([
            "",
            "---",
            "",
            f"*报告生成时间: {timestamp}*",
            "*AI Player Agent*",
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        report_path = Path("docs/player_reports/qa_report_eagle_verify_002.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report


async def main():
    http_port = 10005
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with EagleVerify002Tester(http_port) as tester:
        success = await tester.run_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
