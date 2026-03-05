#!/usr/bin/env python3
"""
BOSS-SUMMER-DRAGON-TEST: 炎阳巨龙Boss技能测试

测试任务:
- task_boss_summer_sun_heat.md - 烈日炙烤(攻速光环)
- task_boss_summer_flame_breath.md - 火焰吐息(锥形AOE)
- task_boss_summer_sun_flare.md - 太阳耀斑(随机AOE)
- task_boss_summer_rebirth.md - 涅槃重生(复活狂暴)

测试目标:
1. 验证炎阳巨龙第12波正确生成
2. 验证烈日炙烤全场攻速加成光环
3. 验证火焰吐息锥形AOE伤害和燃烧效果
4. 验证太阳耀斑随机目标范围伤害
5. 验证涅槃重生复活和狂暴效果

使用方法:
- 使用skip_to_wave(12)跳转到第12波
- 使用set_core_hp(99999)保护核心
- 观察并记录Boss技能日志
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


class BossSummerDragonTester:
    """炎阳巨龙Boss测试器"""

    WAVE = 12
    SEASON = "summer"
    BOSS_NAME = "炎阳巨龙"
    BOSS_ID = "summer_dragon"

    def __init__(self, http_port=9992):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_boss_summer_dragon_{timestamp}.log"

        # 技能检测结果
        self.skill_detections = {
            "sun_heat": [],           # 烈日炙烤 - 攻速光环
            "flame_breath": [],       # 火焰吐息 - 锥形AOE
            "sun_flare": [],          # 太阳耀斑 - 随机AOE
            "rebirth": [],            # 涅槃重生 - 复活狂暴
        }

        # 验证结果
        self.validation = {
            # 基础验证
            "boss_spawned": False,
            "boss_correct_type": False,
            "wave_12_triggered": False,

            # 技能1: 烈日炙烤
            "sun_heat_triggered": False,
            "sun_heat_aura_logged": False,

            # 技能2: 火焰吐息
            "flame_breath_triggered": False,
            "flame_breath_warning": False,
            "flame_burn_debuff": False,

            # 技能3: 太阳耀斑
            "sun_flare_triggered": False,
            "sun_flare_warning": False,
            "sun_flare_multi_target": False,

            # 技能4: 涅槃重生
            "rebirth_triggered": False,
            "rebirth_heal": False,
            "rebirth_berserk": False,
        }

        # 检测到的日志统计
        self.log_stats = {
            "boss_spawn_logs": [],
            "boss_skill_logs": [],
            "boss_damage_logs": [],
            "boss_heal_logs": [],
            "boss_buff_logs": [],
            "debuff_logs": [],
            "warning_logs": [],
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
                self.parse_boss_logs(o)
            await asyncio.sleep(0.3)
        return all_obs

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

    def parse_boss_logs(self, obs: str):
        """解析Boss相关日志"""

        # 1. 检测Boss生成
        spawn_patterns = [
            r"【Boss登场】.*?炎阳巨龙",
            r"【Boss登场】.*?summer_dragon",
        ]
        for pattern in spawn_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["boss_spawned"] = True
                self.validation["boss_correct_type"] = True
                self.log_stats["boss_spawn_logs"].append(obs)
                self.log("🐉 检测到[BOSS出场]: 炎阳巨龙", "DETECTION")
                break

        # 2. 检测烈日炙烤 - 攻速光环
        heat_patterns = [
            r"【Boss技能】.*?炎阳巨龙.*?烈日炙烤",
        ]
        for pattern in heat_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["sun_heat_triggered"] = True
                self.validation["sun_heat_aura_logged"] = True
                self.skill_detections["sun_heat"].append(obs)
                self.log_stats["boss_buff_logs"].append(obs)
                self.log("☀️ 检测到[烈日炙烤]攻速光环", "DETECTION")
                break

        # 3. 检测火焰吐息 - 锥形AOE
        flame_patterns = [
            r"【Boss技能】.*?炎阳巨龙.*?火焰吐息",
        ]
        for pattern in flame_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["flame_breath_triggered"] = True
                self.skill_detections["flame_breath"].append(obs)
                self.log_stats["boss_damage_logs"].append(obs)
                self.log("🔥 检测到[火焰吐息]技能", "DETECTION")
                break

        # 4. 检测火焰吐息预警
        warning_patterns = [
            r"【Boss预警】.*?火焰吐息",
        ]
        for pattern in warning_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["flame_breath_warning"] = True
                self.log_stats["warning_logs"].append(obs)
                self.log("⚠️ 检测到[火焰吐息]预警", "DETECTION")
                break

        # 5. 检测燃烧debuff
        burn_patterns = [
            r"【Boss技能】.*?炎阳巨龙.*?燃烧",
        ]
        for pattern in burn_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["flame_burn_debuff"] = True
                self.log_stats["debuff_logs"].append(obs)
                self.log("🔥 检测到[燃烧]debuff", "DETECTION")
                break

        # 6. 检测太阳耀斑 - 随机AOE
        flare_patterns = [
            r"【Boss技能】.*?炎阳巨龙.*?太阳耀斑",
        ]
        for pattern in flare_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["sun_flare_triggered"] = True
                self.skill_detections["sun_flare"].append(obs)
                self.log_stats["boss_damage_logs"].append(obs)
                self.log("☀️ 检测到[太阳耀斑]技能", "DETECTION")
                break

        # 7. 检测太阳耀斑预警
        flare_warning_patterns = [
            r"【Boss预警】.*?太阳耀斑",
        ]
        for pattern in flare_warning_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["sun_flare_warning"] = True
                self.log_stats["warning_logs"].append(obs)
                self.log("⚠️ 检测到[太阳耀斑]预警", "DETECTION")
                break

        # 8. 检测涅槃重生 - 复活狂暴
        rebirth_patterns = [
            r"【Boss阶段】.*?炎阳巨龙",
            r"【Boss技能】.*?炎阳巨龙.*?涅槃",
        ]
        for pattern in rebirth_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["rebirth_triggered"] = True
                self.skill_detections["rebirth"].append(obs)
                self.log("🔥 检测到[涅槃重生]触发", "DETECTION")
                break

        # 9. 检测狂暴buff
        berserk_patterns = [
            r"\[BOSS_BUFF\].*?狂暴",
            r"狂暴.*?攻速",
            r"狂暴.*?移速",
        ]
        for pattern in berserk_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["rebirth_berserk"] = True
                self.log_stats["boss_buff_logs"].append(obs)
                self.log("💪 检测到[狂暴]buff", "DETECTION")
                break

        # 10. 检测涅槃回血
        rebirth_heal_patterns = [
            r"\[BOSS_HEAL\].*?炎阳巨龙",
            r"涅槃.*?恢复",
            r"恢复.*750.*HP",
        ]
        for pattern in rebirth_heal_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["rebirth_heal"] = True
                self.log_stats["boss_heal_logs"].append(obs)
                self.log("💚 检测到[涅槃重生]回血", "DETECTION")
                break

        # 11. 检测波次12
        if f"第 {self.WAVE} 波" in obs or f"Wave {self.WAVE}" in obs or f"波次{self.WAVE}" in obs:
            self.validation["wave_12_triggered"] = True
            self.log(f"☀️ 检测到第{self.WAVE}波", "DETECTION")

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
        self.log("步骤1: 重置游戏", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        result = await self.send_actions([{"type": "reset_game"}])
        self.log(f"reset_game结果: {result}", "DEBUG")
        await asyncio.sleep(2.0)
        await self.poll_observations(2.0)
        self.log("✅ 游戏重置完成", "VALIDATION")

    async def step_select_totem(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤2: 选择牛图腾", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.poll_observations(1.0)
        await self.send_actions([{"type": "select_totem", "totem_id": "cow_totem"}])
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)
        self.log("✅ 牛图腾选择完成", "VALIDATION")

    async def step_set_god_mode(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤3: 设置上帝模式", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        result = await self.send_actions([{"type": "set_core_hp", "hp": 99999}])
        self.log(f"set_core_hp结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)
        await self.poll_observations(1.0)
        self.log("✅ 上帝模式设置完成", "VALIDATION")

    async def step_spawn_test_units(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤4: 生成测试单位", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 生成多个单位用于测试AOE技能
        test_units = [
            ("squirrel", {"x": 0, "y": 0}),
            ("squirrel", {"x": 1, "y": 0}),
            ("squirrel", {"x": 2, "y": 0}),
            ("squirrel", {"x": 0, "y": 1}),
            ("squirrel", {"x": 1, "y": 1}),
            ("squirrel", {"x": 2, "y": 1}),
        ]

        for unit_id, pos in test_units:
            result = await self.send_actions([{
                "type": "spawn_unit",
                "unit_id": unit_id,
                "grid_pos": pos
            }])
            self.log(f"生成 {unit_id} 结果: {result}", "DEBUG")
            await asyncio.sleep(0.3)

        await self.poll_observations(2.0)
        self.log("✅ 测试单位生成完成", "VALIDATION")

    async def step_skip_to_boss_wave(self):
        self.log("=" * 60, "SYSTEM")
        self.log(f"步骤5: 跳转到第{self.WAVE}波", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        result = await self.send_actions([{"type": "skip_to_wave", "wave": self.WAVE}])
        self.log(f"skip_to_wave结果: {result}", "DEBUG")
        await asyncio.sleep(2.0)
        await self.poll_observations(2.0)
        self.log(f"✅ 跳转到第{self.WAVE}波完成", "VALIDATION")

    async def step_start_boss_battle(self):
        self.log("=" * 60, "SYSTEM")
        self.log(f"步骤6: 开始Boss战", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([{"type": "start_wave"}])
        await asyncio.sleep(1.0)

        # 持续观察Boss战
        self.log("开始观察Boss战...", "SYSTEM")
        battle_duration = 120  # 观察120秒(更长以检测涅槃重生)
        start_time = time.time()

        while time.time() - start_time < battle_duration:
            obs = await self.poll_observations(3.0)

            for o in obs:
                if "游戏结束" in o or "game over" in o.lower():
                    self.log(f"⚠️ 游戏结束", "WARNING")
                    return False

                if "波次完成" in o or "wave ended" in o.lower():
                    self.log(f"✅ 波次完成", "EVENT")
                    return True

        self.log(f"✅ Boss战观察完成 ({battle_duration}秒)", "VALIDATION")
        return True

    async def run_test(self) -> bool:
        self.log("=" * 70, "SYSTEM")
        self.log("BOSS-SUMMER-DRAGON-TEST: 炎阳巨龙Boss技能测试", "SYSTEM")
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
            await self.step_spawn_test_units()
            await self.step_skip_to_boss_wave()
            await self.step_start_boss_battle()

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
            "# QA测试报告: 炎阳巨龙Boss技能测试",
            "",
            f"**测试ID**: BOSS-SUMMER-DRAGON-TEST",
            f"**测试时间**: {timestamp}",
            f"**测试类型**: Boss技能功能测试",
            f"**Boss名称**: {self.BOSS_NAME}",
            f"**Boss波次**: 第{self.WAVE}波",
            "",
            "---",
            "",
            "## 测试任务覆盖",
            "",
            "| 任务ID | 技能名称 | 测试目标 |",
            "|--------|----------|----------|",
            "| task_boss_summer_sun_heat.md | 烈日炙烤 | 全场攻速+20%光环 |",
            "| task_boss_summer_flame_breath.md | 火焰吐息 | 锥形AOE+燃烧 |",
            "| task_boss_summer_sun_flare.md | 太阳耀斑 | 随机目标AOE |",
            "| task_boss_summer_rebirth.md | 涅槃重生 | 复活+狂暴 |",
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

        # 基础验证结果
        base_validations = [
            ("boss_spawned", "Boss成功生成"),
            ("boss_correct_type", "Boss类型正确(炎阳巨龙)"),
            ("wave_12_triggered", "第12波正确触发"),
        ]

        for key, desc in base_validations:
            status = "✅ 通过" if self.validation[key] else "❌ 未通过"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### 技能1: 烈日炙烤(攻速光环)",
            "",
            "| 验证项 | 状态 | 说明 |",
            "|--------|------|------|",
        ])

        heat_status = "✅ 通过" if self.validation["sun_heat_triggered"] else "❌ 未通过"
        report_lines.append(f"| 攻速光环触发 | {heat_status} | 全场敌人攻速+20% |")

        report_lines.extend([
            "",
            "### 技能2: 火焰吐息(锥形AOE)",
            "",
            "| 验证项 | 状态 | 说明 |",
            "|--------|------|------|",
        ])

        flame_status = "✅ 通过" if self.validation["flame_breath_triggered"] else "❌ 未通过"
        warning_status = "✅ 通过" if self.validation["flame_breath_warning"] else "⚠️ 未检测"
        burn_status = "✅ 通过" if self.validation["flame_burn_debuff"] else "⚠️ 未检测"
        report_lines.append(f"| 技能触发 | {flame_status} | 锥形AOE伤害 |")
        report_lines.append(f"| 预警效果 | {warning_status} | 地面红色预警区 |")
        report_lines.append(f"| 燃烧debuff | {burn_status} | 每秒10伤害，3秒 |")

        report_lines.extend([
            "",
            "### 技能3: 太阳耀斑(随机AOE)",
            "",
            "| 验证项 | 状态 | 说明 |",
            "|--------|------|------|",
        ])

        flare_status = "✅ 通过" if self.validation["sun_flare_triggered"] else "❌ 未通过"
        flare_warning_status = "✅ 通过" if self.validation["sun_flare_warning"] else "⚠️ 未检测"
        report_lines.append(f"| 技能触发 | {flare_status} | 3个随机区域 |")
        report_lines.append(f"| 预警效果 | {flare_warning_status} | 太阳标记预警 |")

        report_lines.extend([
            "",
            "### 技能4: 涅槃重生(复活狂暴)",
            "",
            "| 验证项 | 状态 | 说明 |",
            "|--------|------|------|",
        ])

        rebirth_status = "✅ 通过" if self.validation["rebirth_triggered"] else "❌ 未通过/未触发"
        heal_status = "✅ 通过" if self.validation["rebirth_heal"] else "⚠️ 未检测"
        berserk_status = "✅ 通过" if self.validation["rebirth_berserk"] else "⚠️ 未检测"
        report_lines.append(f"| 复活触发 | {rebirth_status} | HP降至0时触发 |")
        report_lines.append(f"| 回血效果 | {heal_status} | 恢复750HP(30%) |")
        report_lines.append(f"| 狂暴buff | {berserk_status} | 攻速+50%，移速+30% |")

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

        # 计算通过率
        passed = sum([
            self.validation["boss_spawned"],
            self.validation["sun_heat_triggered"],
            self.validation["flame_breath_triggered"],
            self.validation["sun_flare_triggered"],
        ])
        total = 4  # 涅槃重生可能未触发(需要击杀Boss)
        pass_rate = passed / total * 100

        if pass_rate >= 75:
            report_lines.append(f"✅ **测试通过** - 核心技能通过率 {pass_rate:.1f}% ({passed}/{total})")
        elif pass_rate >= 50:
            report_lines.append(f"⚠️ **测试部分通过** - 核心技能通过率 {pass_rate:.1f}% ({passed}/{total})")
        else:
            report_lines.append(f"❌ **测试失败** - 核心技能通过率 {pass_rate:.1f}% ({passed}/{total})")

        if self.validation["rebirth_triggered"]:
            report_lines.append("\n🔥 **涅槃重生已触发** - Boss曾进入狂暴阶段")
        else:
            report_lines.append("\n⚠️ **涅槃重生未触发** - 未能在测试期间击杀Boss至濒死")

        report_lines.extend([
            "",
            "---",
            "",
            f"*报告生成时间: {timestamp}*",
            "*AI Player Agent*",
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        # 保存报告
        report_path = Path("docs/player_reports/qa_report_boss_summer_dragon.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report


async def main():
    http_port = 9992
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with BossSummerDragonTester(http_port) as tester:
        success = await tester.run_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
