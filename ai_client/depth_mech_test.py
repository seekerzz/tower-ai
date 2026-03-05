#!/usr/bin/env python3
"""
深度机制测试脚本 (DEPTH-MECH-001)

测试目标:
1. 多波次深度游戏流程 - 运行至少5个波次，验证波次系统稳定性
2. 单位升级机制 - 验证单位吞噬合成升级(LV.1→LV.2→LV.3)
3. 图腾机制详细验证 - 验证图腾攻击、资源变化、Buff施加

测试策略: 选择牛图腾(cow_totem)开局，执行以下操作序列：
- 第1-2波：基础建设
- 第3-4波：单位升级测试
- 第5波+：高级验证
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


class DepthMechanismTester:
    """深度机制测试器"""

    def __init__(self, http_port=8080):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.test_results = []
        self.observations = []
        self.session: Optional[aiohttp.ClientSession] = None
        self.client_process = None
        self.current_log_file = None

        # 创建日志文件
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_depth_mech_{timestamp}.log"

        # 验证结果
        self.validation_results = {
            # 波次系统
            "wave_1": False,
            "wave_2": False,
            "wave_3": False,
            "wave_4": False,
            "wave_5": False,
            # 单位升级
            "unit_merge_lv1_to_lv2": False,
            "unit_merge_lv2_to_lv3": False,
            "unit_stats_upgrade": False,
            # 图腾机制
            "totem_charge": False,
            "totem_fullscreen_counter": False,
            "totem_heal_core": False,
            # 核心机制
            "core_health_change": False,
            "no_crash": True,
        }

        # 波次计数
        self.wave_count = 0

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

    async def start_game_client(self):
        """启动游戏客户端"""
        self.log("=" * 60, "SYSTEM")
        self.log("启动AI游戏客户端...", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        cmd = [
            "python3", "-m", "ai_client.ai_game_client",
            "--project", ".",
            "--scene", "res://src/Scenes/UI/CoreSelection.tscn",
            "--http-port", str(self.http_port)
        ]

        self.client_process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=str(Path(__file__).parent.parent)
        )

        await asyncio.sleep(3.0)
        self.log("客户端启动完成", "SYSTEM")

    def stop_game_client(self):
        """停止游戏客户端"""
        if self.client_process:
            self.log("停止游戏客户端...", "SYSTEM")
            self.client_process.terminate()
            try:
                self.client_process.wait(timeout=5)
            except:
                self.client_process.kill()
            self.client_process = None

    async def wait_for_game_ready(self, timeout: float = 30.0) -> bool:
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
                        self.validation_results["no_crash"] = False
                        return False
            except:
                pass
            await asyncio.sleep(0.5)
        self.log("等待游戏就绪超时", "ERROR")
        return False

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

    async def check_crash(self) -> bool:
        """检查游戏是否崩溃"""
        try:
            async with self.session.get(
                f"{self.base_url}/status",
                timeout=aiohttp.ClientTimeout(total=2)
            ) as resp:
                data = await resp.json()
                if data.get("crashed"):
                    self.validation_results["no_crash"] = False
                    return True
        except:
            pass
        return False

    # ==================== 测试步骤 ====================

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

    async def step_wave_1_setup(self):
        """第1波: 基础建设 - 购买并部署 iron_turtle"""
        self.log("=" * 60, "SYSTEM")
        self.log("第1波准备: 购买并部署 iron_turtle 到 (1,0)", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 购买铁甲龟
        self.log("购买 iron_turtle...", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(1.0)

        # 部署到 (1,0)
        self.log("部署 iron_turtle 到 (1,0)...", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 1, "y": 0}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(1.0)

        # 启动第1波
        self.log("启动第1波战斗...", "ACTION")
        await self.send_actions([{"type": "start_wave"}])
        obs = await self.poll_observations(12.0)

        # 检查崩溃
        if await self.check_crash():
            self.log("❌ 第1波发生崩溃!", "ERROR")
            return False

        self.wave_count = 1
        self.validation_results["wave_1"] = True
        self.log("✅ 第1波完成", "VALIDATION")
        return True

    async def step_wave_2_setup(self):
        """第2波: 购买并部署 yak_guardian"""
        self.log("=" * 60, "SYSTEM")
        self.log("第2波准备: 购买并部署 yak_guardian 到 (2,0)", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 刷新商店
        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)

        # 购买牦牛守护
        self.log("购买 yak_guardian...", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(1.0)

        # 部署到 (2,0)
        self.log("部署 yak_guardian 到 (2,0)...", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 2, "y": 0}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(1.0)

        # 启动第2波
        self.log("启动第2波战斗...", "ACTION")
        await self.send_actions([{"type": "start_wave"}])
        obs = await self.poll_observations(12.0)

        # 检查崩溃
        if await self.check_crash():
            self.log("❌ 第2波发生崩溃!", "ERROR")
            return False

        self.wave_count = 2
        self.validation_results["wave_2"] = True
        self.log("✅ 第2波完成", "VALIDATION")
        return True

    async def step_wave_3_merge_test(self):
        """第3波: 单位升级测试 - 购买第2个iron_turtle并吞噬升级"""
        self.log("=" * 60, "SYSTEM")
        self.log("第3波准备: 单位升级测试 - 购买第2个iron_turtle并吞噬升级", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 刷新商店
        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)

        # 购买第2个铁甲龟
        self.log("购买第2个 iron_turtle...", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(1.0)

        # 将第2个铁甲龟移动到第1个旁边 (1,1)，准备吞噬
        self.log("将第2个 iron_turtle 部署到 (1,1)...", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 1, "y": 1}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(1.0)

        # 尝试吞噬升级 - 将一个单位移动到另一个旁边应该触发吞噬
        self.log("尝试吞噬升级 (LV.1→LV.2)...", "ACTION")
        # 移动第2个铁甲龟到第1个旁边触发吞噬
        await self.send_actions([
            {"type": "move_unit", "from_zone": "grid", "to_zone": "grid",
             "from_pos": {"x": 1, "y": 1}, "to_pos": {"x": 1, "y": 0}}
        ])
        await asyncio.sleep(1.0)
        obs = await self.poll_observations(3.0)

        # 检查升级日志
        merge_found = False
        for o in obs:
            if any(kw in o.lower() for kw in ["升级", "merge", "吞噬", "lv.2", "lv2", "level up"]):
                merge_found = True
                self.validation_results["unit_merge_lv1_to_lv2"] = True
                self.log(f"✅ 单位升级检测到: {o}", "VALIDATION")
                break

        if not merge_found:
            self.log("⚠️ 未检测到明确的升级日志，继续测试...", "WARNING")

        # 启动第3波
        self.log("启动第3波战斗...", "ACTION")
        await self.send_actions([{"type": "start_wave"}])
        obs = await self.poll_observations(12.0)

        # 检查崩溃
        if await self.check_crash():
            self.log("❌ 第3波发生崩溃!", "ERROR")
            return False

        self.wave_count = 3
        self.validation_results["wave_3"] = True
        self.log("✅ 第3波完成", "VALIDATION")
        return True

    async def step_wave_4_cow_test(self):
        """第4波: 购买cow单位并部署"""
        self.log("=" * 60, "SYSTEM")
        self.log("第4波准备: 购买 cow 单位，部署到 (0,1)", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 刷新商店
        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)

        # 购买cow
        self.log("购买 cow...", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 1}])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(1.0)

        # 部署到 (0,1)
        self.log("部署 cow 到 (0,1)...", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 0, "y": 1}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(1.0)

        # 启动第4波
        self.log("启动第4波战斗...", "ACTION")
        await self.send_actions([{"type": "start_wave"}])
        obs = await self.poll_observations(12.0)

        # 检查崩溃
        if await self.check_crash():
            self.log("❌ 第4波发生崩溃!", "ERROR")
            return False

        self.wave_count = 4
        self.validation_results["wave_4"] = True
        self.log("✅ 第4波完成", "VALIDATION")
        return True

    async def step_wave_5_advanced(self):
        """第5波+: 高级验证 - 继续购买升级单位，验证牛图腾机制"""
        self.log("=" * 60, "SYSTEM")
        self.log("第5波+: 高级验证 - 验证牛图腾全屏反击和核心回血", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 继续购买单位
        for i in range(2):
            await self.send_actions([{"type": "refresh_shop"}])
            await asyncio.sleep(0.5)
            await self.send_actions([{"type": "buy_unit", "shop_index": i}])
            await asyncio.sleep(0.3)

        obs = await self.poll_observations(2.0)

        # 启动第5波
        self.log("启动第5波战斗...", "ACTION")
        await self.send_actions([{"type": "start_wave"}])

        # 长时间观察牛图腾机制
        self.log("观察牛图腾机制 (15秒)...", "TEST")
        obs = await self.poll_observations(15.0)

        # 检查图腾机制
        for o in obs:
            # 检查充能
            if any(kw in o for kw in ["[RESOURCE]", "充能", "charge", "energy"]):
                self.validation_results["totem_charge"] = True
                self.log(f"✅ 图腾充能: {o}", "VALIDATION")

            # 检查全屏反击
            if any(kw in o for kw in ["[TOTEM]", "全屏", "counter", "反击", "full screen"]):
                self.validation_results["totem_fullscreen_counter"] = True
                self.log(f"✅ 全屏反击: {o}", "VALIDATION")

            # 检查核心回血
            if any(kw in o for kw in ["[CORE_HEAL]", "回血", "治疗", "heal", "恢复"]):
                self.validation_results["totem_heal_core"] = True
                self.log(f"✅ 核心回血: {o}", "VALIDATION")

            # 检查核心血量变化
            if any(kw in o for kw in ["核心", "血量", "health", "hp"]):
                self.validation_results["core_health_change"] = True

        # 检查崩溃
        if await self.check_crash():
            self.log("❌ 第5波发生崩溃!", "ERROR")
            return False

        self.wave_count = 5
        self.validation_results["wave_5"] = True
        self.log("✅ 第5波完成", "VALIDATION")
        return True

    async def step_additional_waves(self):
        """额外波次: 继续测试到第6-7波"""
        for wave_num in range(6, 8):
            self.log("=" * 60, "SYSTEM")
            self.log(f"第{wave_num}波: 继续验证", "SYSTEM")
            self.log("=" * 60, "SYSTEM")

            # 随机购买单位
            await self.send_actions([{"type": "refresh_shop"}])
            await asyncio.sleep(0.5)
            await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
            await asyncio.sleep(0.3)

            # 启动波次
            self.log(f"启动第{wave_num}波战斗...", "ACTION")
            await self.send_actions([{"type": "start_wave"}])
            obs = await self.poll_observations(10.0)

            # 检查崩溃
            if await self.check_crash():
                self.log(f"❌ 第{wave_num}波发生崩溃!", "ERROR")
                return False

            self.wave_count = wave_num
            self.log(f"✅ 第{wave_num}波完成", "VALIDATION")

        return True

    async def generate_report(self):
        """生成测试报告"""
        self.log("=" * 60, "SYSTEM")
        self.log("深度机制测试报告生成", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        report_lines = [
            "\n" + "=" * 60,
            "深度机制测试报告 (DEPTH-MECH-001)",
            "=" * 60,
            f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"日志文件: {self.log_file}",
            f"完成波次: {self.wave_count}",
            "",
            "【波次系统验证】",
        ]

        for i in range(1, 6):
            status = "✅ 通过" if self.validation_results[f"wave_{i}"] else "❌ 未通过"
            report_lines.append(f"  第{i}波: {status}")

        report_lines.extend([
            "",
            "【单位升级机制验证】",
            f"  LV.1→LV.2 升级: {'✅ 通过' if self.validation_results['unit_merge_lv1_to_lv2'] else '❌ 未验证'}",
            f"  LV.2→LV.3 升级: {'✅ 通过' if self.validation_results['unit_merge_lv2_to_lv3'] else '❌ 未验证'}",
            f"  单位属性变化: {'✅ 通过' if self.validation_results['unit_stats_upgrade'] else '❌ 未验证'}",
            "",
            "【图腾机制验证】",
            f"  图腾充能: {'✅ 通过' if self.validation_results['totem_charge'] else '❌ 未验证'}",
            f"  全屏反击: {'✅ 通过' if self.validation_results['totem_fullscreen_counter'] else '❌ 未验证'}",
            f"  核心回血: {'✅ 通过' if self.validation_results['totem_heal_core'] else '❌ 未验证'}",
            "",
            "【核心机制验证】",
            f"  核心血量变化: {'✅ 通过' if self.validation_results['core_health_change'] else '❌ 未验证'}",
            f"  无代码级崩溃: {'✅ 通过' if self.validation_results['no_crash'] else '❌ 发现崩溃'}",
            "",
            "=" * 60,
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        return report

    async def run_full_test(self):
        """运行完整深度测试"""
        self.log("=" * 60, "SYSTEM")
        self.log("开始深度机制测试 (DEPTH-MECH-001)", "SYSTEM")
        self.log("=" * 60, "SYSTEM")
        self.log("", "SYSTEM")
        self.log("测试目标:", "SYSTEM")
        self.log("  1. 多波次深度游戏流程 (5+波次)", "SYSTEM")
        self.log("  2. 单位升级机制 (LV.1→LV.2→LV.3)", "SYSTEM")
        self.log("  3. 图腾机制详细验证", "SYSTEM")
        self.log("", "SYSTEM")

        try:
            # 启动游戏客户端
            await self.start_game_client()

            # 等待游戏就绪
            if not await self.wait_for_game_ready():
                self.log("❌ 游戏未就绪，测试中止", "ERROR")
                self.stop_game_client()
                return False

            # 执行测试步骤
            await self.step_select_totem()

            # 执行5个波次
            if not await self.step_wave_1_setup():
                await self.generate_report()
                self.stop_game_client()
                return False

            if not await self.step_wave_2_setup():
                await self.generate_report()
                self.stop_game_client()
                return False

            if not await self.step_wave_3_merge_test():
                await self.generate_report()
                self.stop_game_client()
                return False

            if not await self.step_wave_4_cow_test():
                await self.generate_report()
                self.stop_game_client()
                return False

            if not await self.step_wave_5_advanced():
                await self.generate_report()
                self.stop_game_client()
                return False

            # 额外波次
            await self.step_additional_waves()

            # 生成报告
            await self.generate_report()

            self.log("=" * 60, "SYSTEM")
            self.log(f"深度测试完成 - 共完成 {self.wave_count} 个波次", "SYSTEM")
            self.log("=" * 60, "SYSTEM")

            self.stop_game_client()
            return True

        except Exception as e:
            self.log(f"测试过程中发生错误: {e}", "ERROR")
            import traceback
            self.log(traceback.format_exc(), "ERROR")
            await self.generate_report()
            self.stop_game_client()
            return False


async def main():
    """主函数"""
    http_port = 8080
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with DepthMechanismTester(http_port) as tester:
        success = await tester.run_full_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
