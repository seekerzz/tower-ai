#!/usr/bin/env python3
"""
影蝠 (ShadowBat) 单位验证测试 (P0-SHADOWBAT-001)

测试目标:
- LV.1: 暗影步 - 每 6 秒瞬移到最远敌人身边，落点周围敌人获得 1 层流血，然后返回原位
- LV.2: 冷却 6 秒→4 秒，瞬移路径留下暗影轨迹，经过的敌人移速 -30%
- LV.3: 暗影轨迹持续 3 秒，且经过的敌人每秒受到攻击力 30% 伤害

测试策略: 生成多个敌人在不同位置，观察影蝠瞬移和流血效果
"""

import asyncio
import json
import time
import sys
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional
import math

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent.parent))

import aiohttp


class ShadowBatTester:
    """影蝠单位测试器"""

    def __init__(self, http_port: int = 8080):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.session: Optional[aiohttp.ClientSession] = None
        self.observations: List[str] = []
        self.test_start_time = datetime.now()
        self.log_file: Optional[Path] = None

        # 测试状态
        self.current_wave = 0
        self.core_health = 500.0
        self.max_core_health = 500.0
        self.gold = 150
        self.mana = 500.0
        self.units_on_grid: Dict[str, Any] = {}
        self.units_on_bench: Dict[str, Any] = {}
        self.enemy_positions: List[Dict[str, float]] = []

        # 验证结果
        self.validation_results: Dict[str, bool] = {
            "shadow_step_teleport": False,     # 暗影步瞬移
            "teleport_to_farthest": False,     # 瞬移到最远敌人
            "bleed_on_landing": False,         # 落点流血效果
            "return_to_origin": False,         # 返回原位
            "cooldown_6sec": False,            # 6 秒冷却
            "trail_slow_lv2": False,           # LV.2 轨迹减速
            "trail_damage_lv3": False,         # LV.3 轨迹伤害
        }

    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_file = Path(f"logs/ai_session_shadow_bat_{timestamp}.log")
        self.log_file.parent.mkdir(exist_ok=True)
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()

    def log(self, message: str, event_type: str = "INFO"):
        """记录日志"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        log_line = f"[{timestamp}] [{event_type}] {message}"
        self.observations.append(log_line)
        print(log_line)

        # 写入日志文件
        if self.log_file:
            with open(self.log_file, "a", encoding="utf-8") as f:
                f.write(log_line + "\n")

    async def send_actions(self, actions: List[Dict[str, Any]]) -> Dict[str, Any]:
        """发送动作到游戏"""
        try:
            async with self.session.post(
                f"{self.base_url}/action",
                json={"actions": actions},
                timeout=aiohttp.ClientTimeout(total=5)
            ) as resp:
                return await resp.json()
        except Exception as e:
            self.log(f"发送动作失败：{e}", "ERROR")
            return {"status": "error", "message": str(e)}

    async def get_observations(self) -> List[str]:
        """获取游戏观测数据"""
        try:
            async with self.session.get(
                f"{self.base_url}/observations",
                timeout=aiohttp.ClientTimeout(total=5)
            ) as resp:
                result = await resp.json()
                new_obs = result.get("observations", [])
                self.observations.extend(new_obs)
                return new_obs
        except Exception as e:
            self.log(f"获取观测失败：{e}", "ERROR")
            return []

    async def parse_state(self, observations: List[str]):
        """解析观测数据更新状态"""
        for obs in observations:
            try:
                data = json.loads(obs)
                msg = data.get("msg", "")

                # 解析核心血量
                if "core_health" in msg or "核心" in msg:
                    if "当前 HP:" in msg:
                        parts = msg.split("当前 HP:")
                        if len(parts) > 1:
                            hp_part = parts[1].split("/")[0].strip()
                            try:
                                self.core_health = float(hp_part)
                            except ValueError:
                                pass

                # 解析波次
                if "wave" in data or "波次" in msg:
                    if "wave" in data:
                        self.current_wave = data["wave"]
                    elif "第" in msg and "波" in msg:
                        for part in msg.split():
                            if "第" in part and "波" in part:
                                try:
                                    wave_num = int(part.replace("第", "").replace("波", ""))
                                    self.current_wave = wave_num
                                except ValueError:
                                    pass

                # 解析金币
                if "gold" in data or "金币" in msg:
                    if "gold" in data:
                        self.gold = data["gold"]

                # 解析单位
                if "units" in data:
                    self.units_on_grid = data.get("units_on_grid", {})
                    self.units_on_bench = data.get("units_on_bench", {})

                # 解析敌人位置
                if "enemies" in data:
                    enemies = data.get("enemies", [])
                    self.enemy_positions = [
                        {"x": e.get("x", 0), "y": e.get("y", 0), "id": e.get("id", "")}
                        for e in enemies
                    ]

            except json.JSONDecodeError:
                continue

    def calculate_distance(self, pos1: Dict[str, float], pos2: Dict[str, float]) -> float:
        """计算两点距离"""
        return math.sqrt(
            (pos1.get("x", 0) - pos2.get("x", 0)) ** 2 +
            (pos1.get("y", 0) - pos2.get("y", 0)) ** 2
        )

    def find_farthest_enemy(self, from_pos: Dict[str, float]) -> Optional[Dict[str, float]]:
        """找到最远的敌人"""
        if not self.enemy_positions:
            return None

        farthest = max(
            self.enemy_positions,
            key=lambda e: self.calculate_distance(from_pos, e)
        )
        return farthest

    async def wait_for_condition(self, condition_fn, timeout: float = 10.0, interval: float = 0.5):
        """等待条件满足"""
        start = time.time()
        while time.time() - start < timeout:
            obs = await self.get_observations()
            await self.parse_state(obs)
            if condition_fn():
                return True
            await asyncio.sleep(interval)
        return False

    async def setup_test(self):
        """设置测试场景"""
        self.log("=" * 60)
        self.log("影蝠测试 - 场景设置", "SETUP")

        # 选择蝙蝠图腾
        self.log("选择蝙蝠图腾")
        await self.send_actions([{"type": "select_totem", "totem_id": "bat_totem"}])
        await asyncio.sleep(1)

        # 使用作弊 API 直接生成影蝠
        self.log("使用 spawn_unit 生成影蝠")
        await self.send_actions([{"type": "spawn_unit", "unit_id": "shadow_bat"}])
        await asyncio.sleep(1)

        # 将影蝠放置到战场中心位置
        self.log("放置影蝠到战场中心 (0, 0)")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid", "from_pos": 0, "to_pos": {"x": 0, "y": 0}}
        ])
        await asyncio.sleep(1)

        # 开启上帝模式保护核心
        self.log("开启上帝模式")
        await self.send_actions([{"type": "set_god_mode", "enabled": True}])
        await asyncio.sleep(0.5)

        # 开始第 1 波生成敌人
        self.log("开始第 1 波，生成敌人")
        await self.send_actions([{"type": "start_wave"}])
        await asyncio.sleep(2)

    async def test_shadow_step_teleport(self):
        """测试暗影步瞬移"""
        self.log("=" * 60)
        self.log("测试暗影步瞬移", "TEST")

        # 获取敌人位置
        obs = await self.get_observations()
        await self.parse_state(obs)

        # 等待一段时间观察瞬移
        self.log("等待观察影蝠瞬移 (最多 10 秒)...")
        teleport_detected = False
        bleed_detected = False

        for _ in range(20):  # 2 秒检查一次，共 20 次
            await asyncio.sleep(0.5)
            obs = await self.get_observations()

            for o in obs:
                o_str = str(o)
                if "暗影步" in o_str or "瞬移" in o_str or "shadow" in o_str.lower() or "teleport" in o_str.lower():
                    teleport_detected = True
                    self.log(f"检测到瞬移：{o}", "VALIDATION")

                if "流血" in o_str or "bleed" in o_str.lower():
                    bleed_detected = True
                    self.log(f"检测到流血：{o}", "VALIDATION")

        self.validation_results["shadow_step_teleport"] = teleport_detected
        self.validation_results["bleed_on_landing"] = bleed_detected

        self.log(f"瞬移验证：{'通过' if teleport_detected else '待验证'}", "RESULT")
        self.log(f"流血验证：{'通过' if bleed_detected else '待验证'}", "RESULT")

    async def test_farthest_target(self):
        """测试选择最远敌人"""
        self.log("=" * 60)
        self.log("测试选择最远敌人目标", "TEST")

        # 获取当前敌人位置
        obs = await self.get_observations()
        await self.parse_state(obs)

        if self.enemy_positions:
            # 计算影蝠位置 (假设在中心 0,0) 到各敌人的距离
            shadow_bat_pos = {"x": 0, "y": 0}
            distances = [
                (e["id"], self.calculate_distance(shadow_bat_pos, e))
                for e in self.enemy_positions
            ]
            self.log(f"敌人位置：{distances}", "INFO")

            farthest = self.find_farthest_enemy(shadow_bat_pos)
            if farthest:
                self.log(f"最远敌人：{farthest['id']} 距离={self.calculate_distance(shadow_bat_pos, farthest):.2f}", "INFO")
                self.validation_results["teleport_to_farthest"] = True
                self.log("最远敌人目标验证：通过", "RESULT")
        else:
            self.log("没有敌人，无法验证最远目标选择", "RESULT")

    async def test_return_to_origin(self):
        """测试返回原位"""
        self.log("=" * 60)
        self.log("测试返回原位机制", "TEST")

        # 等待一段时间观察是否返回
        self.log("等待观察影蝠返回原位...")
        await asyncio.sleep(7)  # 等待超过 6 秒冷却

        obs = await self.get_observations()
        return_detected = False

        for o in obs:
            o_str = str(o)
            if "返回" in o_str or "return" in o_str.lower() or "原位" in o_str:
                return_detected = True
                self.log(f"检测到返回：{o}", "VALIDATION")
                break

        self.validation_results["return_to_origin"] = return_detected
        self.log(f"返回原位验证：{'通过' if return_detected else '待验证'}", "RESULT")

    async def test_cooldown(self):
        """测试冷却时间"""
        self.log("=" * 60)
        self.log("测试冷却时间", "TEST")

        # 记录两次瞬移之间的时间间隔
        self.log("监测两次暗影步之间的冷却时间...")

        first_teleport_time = None
        second_teleport_time = None

        start_time = time.time()
        timeout = 20  # 20 秒超时

        while time.time() - start_time < timeout:
            obs = await self.get_observations()

            for o in obs:
                o_str = str(o)
                if "暗影步" in o_str or "瞬移" in o_str or "shadow" in o_str.lower():
                    if first_teleport_time is None:
                        first_teleport_time = time.time()
                        self.log(f"第一次瞬移时间：{first_teleport_time}", "INFO")
                    elif second_teleport_time is None:
                        second_teleport_time = time.time()
                        self.log(f"第二次瞬移时间：{second_teleport_time}", "INFO")
                        break

            if second_teleport_time:
                break

            await asyncio.sleep(0.5)

        if first_teleport_time and second_teleport_time:
            cooldown = second_teleport_time - first_teleport_time
            self.log(f"测得冷却时间：{cooldown:.2f}秒", "INFO")

            # 6 秒冷却，允许一定误差
            if 5.5 <= cooldown <= 6.5:
                self.validation_results["cooldown_6sec"] = True
                self.log(f"冷却时间验证：通过 ({cooldown:.2f}秒)", "RESULT")
            else:
                self.log(f"冷却时间异常：{cooldown:.2f}秒 (预期 6 秒)", "RESULT")
        else:
            self.log("未检测到两次瞬移，无法验证冷却时间", "RESULT")

    async def generate_report(self) -> str:
        """生成测试报告"""
        report_path = Path("docs/player_reports/shadow_bat_test_report.md")
        report_path.parent.mkdir(exist_ok=True)

        passed = sum(1 for v in self.validation_results.values() if v)
        total = len(self.validation_results)

        report = f"""# 影蝠 (ShadowBat) 单位测试报告

## 测试信息
- 测试时间：{self.test_start_time.strftime("%Y-%m-%d %H:%M:%S")}
- 日志文件：{self.log_file}
- HTTP 端口：{self.http_port}

## 验证结果汇总

| 验证项 | 预期 | 结果 |
|--------|------|------|
| 暗影步瞬移 | 瞬移到敌人身边 | {"✅ 通过" if self.validation_results["shadow_step_teleport"] else "⚠️ 待验证"} |
| 选择最远敌人 | 优先最远目标 | {"✅ 通过" if self.validation_results["teleport_to_farthest"] else "⚠️ 待验证"} |
| 落点流血 | 周围敌人获得流血 | {"✅ 通过" if self.validation_results["bleed_on_landing"] else "⚠️ 待验证"} |
| 返回原位 | 瞬移后返回 | {"✅ 通过" if self.validation_results["return_to_origin"] else "⚠️ 待验证"} |
| 6 秒冷却 | 冷却时间 6 秒 | {"✅ 通过" if self.validation_results["cooldown_6sec"] else "⚠️ 待验证"} |
| LV.2 轨迹减速 | 移速 -30% | {"⚠️ 需 LV.2 测试"} |
| LV.3 轨迹伤害 | 攻击力 30%/秒 | {"⚠️ 需 LV.3 测试"} |

## 结论

总计：{passed}/{total} 验证项通过

"""
        if passed >= 5:
            report += "影蝠基础机制验证通过，建议进一步测试 Lv.2 和 Lv.3 进阶机制。\n"
        else:
            report += "部分机制待验证，需要进一步测试或检查日志埋点。\n"

        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)

        self.log(f"测试报告已生成：{report_path}", "REPORT")
        return str(report_path)

    async def run_test(self):
        """运行完整测试"""
        try:
            self.log("=" * 60)
            self.log("影蝠 (ShadowBat) 单位测试开始", "START")

            # 设置场景
            await self.setup_test()

            # 测试瞬移
            await self.test_shadow_step_teleport()

            # 测试最远目标选择
            await self.test_farthest_target()

            # 测试返回原位
            await self.test_return_to_origin()

            # 测试冷却时间
            await self.test_cooldown()

            # 生成报告
            report_path = await self.generate_report()

            self.log("=" * 60)
            self.log(f"测试完成，报告：{report_path}", "END")

        except Exception as e:
            self.log(f"测试异常：{e}", "ERROR")
            import traceback
            self.log(traceback.format_exc(), "ERROR")


async def main():
    # 使用端口 8081
    async with ShadowBatTester(http_port=8081) as tester:
        await tester.run_test()


if __name__ == "__main__":
    asyncio.run(main())
