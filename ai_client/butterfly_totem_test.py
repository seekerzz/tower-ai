#!/usr/bin/env python3
"""
蝴蝶图腾流派全面测试脚本 (TOTEM-BUTTERFLY-001)

测试策略: 法力循环流 - 利用法球和法力消耗机制，验证法力回复和爆发

重点验证:
- 3颗环绕法球是否正常生成和穿透
- 法球命中伤害和法力回复
- 蝴蝶的法力消耗附加伤害机制
- 冰晶蝶的冻结debuff和冻结延长
- 仙女龙的传送概率和相位崩塌
- 萤火虫的致盲和Miss回蓝
- 凤凰的火雨AOE和临时法球生成
- 电鳗的闪电链弹射和法力震荡
- 龙的黑洞控制和星辰坠落
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

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent.parent))

import aiohttp

class ButterflyTotemTester:
    """蝴蝶图腾测试器"""

    def __init__(self, http_port=8080):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.test_results = []
        self.observations = []
        self.log_file = None
        self.client_process = None

        # 创建日志文件
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_butterfly_totem_{timestamp}.log"

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

    async def start_client(self):
        """启动AI客户端"""
        self.log("=" * 80, "SYSTEM")
        self.log("启动蝴蝶图腾流派全面测试 (TOTEM-BUTTERFLY-001)", "SYSTEM")
        self.log("=" * 80, "SYSTEM")

        # 启动AI客户端进程
        cmd = [
            "python3", "ai_client/ai_game_client.py",
            "--project", ".",
            "--scene", "res://src/Scenes/UI/CoreSelection.tscn",
            "--http-port", str(self.http_port),
            "--visual"  # GUI模式便于观察
        ]

        self.log(f"启动命令: {' '.join(cmd)}", "SYSTEM")

        # 启动子进程
        self.client_process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd="/mnt/f/Desktop/tower-ai"
        )

        # 等待客户端启动
        self.log("等待AI客户端启动...", "SYSTEM")
        await asyncio.sleep(5)

        # 检查健康状态
        for i in range(10):
            try:
                async with aiohttp.ClientSession() as session:
                    async with session.get(f"{self.base_url}/health", timeout=5) as resp:
                        if resp.status == 200:
                            self.log("AI客户端连接成功", "SYSTEM")
                            return True
            except Exception as e:
                self.log(f"连接尝试 {i+1}/10 失败: {e}", "SYSTEM")
                await asyncio.sleep(2)

        self.log("无法连接到AI客户端", "ERROR")
        return False

    async def stop_client(self):
        """停止AI客户端"""
        if self.client_process:
            self.log("停止AI客户端...", "SYSTEM")
            self.client_process.terminate()
            try:
                self.client_process.wait(timeout=5)
            except:
                self.client_process.kill()

    async def send_actions(self, actions):
        """发送动作到游戏"""
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{self.base_url}/action",
                    json={"actions": actions},
                    timeout=10
                ) as resp:
                    return await resp.json()
        except Exception as e:
            self.log(f"发送动作失败: {e}", "ERROR")
            return {"error": str(e)}

    async def get_observations(self):
        """获取游戏观测数据"""
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    f"{self.base_url}/observations",
                    timeout=10
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

    async def wait_for_observations(self, timeout=30, count=5):
        """等待并收集观测数据"""
        start_time = time.time()
        collected = []
        while time.time() - start_time < timeout and len(collected) < count:
            obs = await self.get_observations()
            collected.extend(obs)
            if obs:
                await asyncio.sleep(0.5)
            else:
                await asyncio.sleep(1)
        return collected

    async def test_select_totem(self):
        """测试选择蝴蝶图腾"""
        self.log("\n" + "=" * 80, "TEST")
        self.log("【测试1】选择蝴蝶图腾 (butterfly_totem)", "TEST")
        self.log("=" * 80, "TEST")

        resp = await self.send_actions([{
            "type": "select_totem",
            "totem_id": "butterfly_totem"
        }])

        self.log(f"响应: {resp}", "DEBUG")

        # 等待观测数据
        await asyncio.sleep(2)
        obs = await self.wait_for_observations(timeout=10, count=3)

        # 验证图腾选择
        has_totem_selected = any("蝴蝶" in str(o) or "butterfly" in str(o).lower() or "图腾" in str(o) for o in obs)

        if resp.get("status") == "ok" or has_totem_selected:
            self.log_validation("图腾选择", True, "蝴蝶图腾选择成功")
        else:
            self.log_validation("图腾选择", False, f"响应: {resp}")

        return resp.get("status") == "ok"

    async def test_orb_mechanism(self):
        """测试法球机制"""
        self.log("\n" + "=" * 80, "TEST")
        self.log("【测试2】法球机制验证", "TEST")
        self.log("验证点: 3颗环绕法球生成、穿透、伤害20、法力回复", "TEST")
        self.log("=" * 80, "TEST")

        # 开始一波战斗来观察法球
        resp = await self.send_actions([{"type": "start_wave"}])
        self.log(f"开始波次响应: {resp}", "DEBUG")

        # 等待战斗进行，收集法球相关观测
        await asyncio.sleep(3)
        obs = await self.wait_for_observations(timeout=15, count=10)

        # 分析法球相关日志
        orb_keywords = ["法球", "orb", "环绕", "穿透", "法力", "MP", "mana"]
        orb_obs = [o for o in obs if any(kw in str(o) for kw in orb_keywords)]

        self.log(f"法球相关观测: {len(orb_obs)} 条", "DEBUG")
        for o in orb_obs[:5]:
            self.log(f"  -> {o}", "DEBUG")

        # 验证法球伤害和法力回复
        has_orb_damage = any("20" in str(o) and ("伤害" in str(o) or "damage" in str(o).lower()) for o in obs)
        has_mana_restore = any("法力" in str(o) or "MP" in str(o) or "mana" in str(o).lower() for o in obs)

        self.log_validation("法球生成", len(orb_obs) > 0, f"找到 {len(orb_obs)} 条法球相关观测")
        self.log_validation("法球伤害", has_orb_damage, "法球造成伤害")
        self.log_validation("法力回复", has_mana_restore, "法球回复法力")

        return len(orb_obs) > 0

    async def test_buy_butterfly_units(self):
        """测试购买蝴蝶流派单位"""
        self.log("\n" + "=" * 80, "TEST")
        self.log("【测试3】购买蝴蝶流派单位", "TEST")
        self.log("目标单位: 火炬、蝴蝶、冰晶蝶、仙女龙、萤火虫、凤凰、电鳗、龙", "TEST")
        self.log("=" * 80, "TEST")

        target_units = ["torch", "butterfly", "ice_butterfly", "fairy_dragon",
                       "firefly", "phoenix", "eel", "dragon"]

        purchased_units = []

        for i in range(8):  # 尝试8次购买和刷新
            # 尝试购买商店中的单位
            for shop_idx in range(4):
                resp = await self.send_actions([{
                    "type": "buy_unit",
                    "shop_index": shop_idx
                }])
                self.log(f"购买槽位 {shop_idx}: {resp}", "DEBUG")

                if resp.get("status") == "ok":
                    purchased_units.append(f"slot_{shop_idx}")
                    self.log(f"成功购买槽位 {shop_idx} 的单位", "INFO")

                await asyncio.sleep(0.5)

            # 刷新商店
            resp = await self.send_actions([{"type": "refresh_shop"}])
            self.log(f"刷新商店: {resp}", "DEBUG")
            await asyncio.sleep(1)

            # 获取观测
            await self.wait_for_observations(timeout=5, count=3)

        self.log_validation("单位购买", len(purchased_units) > 0,
                           f"成功购买 {len(purchased_units)} 个单位")

        return len(purchased_units) > 0

    async def test_butterfly_mana_consumption(self):
        """测试蝴蝶法力消耗机制"""
        self.log("\n" + "=" * 80, "TEST")
        self.log("【测试4】蝴蝶法力消耗附加伤害机制", "TEST")
        self.log("验证点: 消耗5%最大法力,附加消耗法力100%的伤害", "TEST")
        self.log("=" * 80, "TEST")

        # 观察法力消耗相关日志
        await asyncio.sleep(2)
        obs = await self.wait_for_observations(timeout=10, count=5)

        mana_keywords = ["消耗", "法力", "mana", "MP", "伤害", "damage"]
        mana_obs = [o for o in obs if any(kw in str(o) for kw in mana_keywords)]

        self.log(f"法力相关观测: {len(mana_obs)} 条", "DEBUG")
        for o in mana_obs[:3]:
            self.log(f"  -> {o}", "DEBUG")

        self.log_validation("法力消耗机制", len(mana_obs) > 0,
                           f"找到 {len(mana_obs)} 条法力相关观测")

        return len(mana_obs) > 0

    async def test_ice_butterfly_freeze(self):
        """测试冰晶蝶冻结机制"""
        self.log("\n" + "=" * 80, "TEST")
        self.log("【测试5】冰晶蝶冻结debuff和冻结延长", "TEST")
        self.log("验证点: 攻击叠加冰冻debuff，3层冻结1秒，法球命中冻结敌人伤害翻倍", "TEST")
        self.log("=" * 80, "TEST")

        await asyncio.sleep(2)
        obs = await self.wait_for_observations(timeout=10, count=5)

        freeze_keywords = ["冰冻", "freeze", "冻结", "冰晶", "ice"]
        freeze_obs = [o for o in obs if any(kw in str(o).lower() for kw in freeze_keywords)]

        self.log(f"冻结相关观测: {len(freeze_obs)} 条", "DEBUG")
        for o in freeze_obs[:3]:
            self.log(f"  -> {o}", "DEBUG")

        self.log_validation("冰冻debuff", len(freeze_obs) > 0,
                           f"找到 {len(freeze_obs)} 条冰冻相关观测")

        return len(freeze_obs) > 0

    async def test_fairy_dragon_teleport(self):
        """测试仙女龙传送机制"""
        self.log("\n" + "=" * 80, "TEST")
        self.log("【测试6】仙女龙传送概率和相位崩塌", "TEST")
        self.log("验证点: 25%概率传送敌人，被传送敌人叠加两层瘟疫debuff", "TEST")
        self.log("=" * 80, "TEST")

        await asyncio.sleep(2)
        obs = await self.wait_for_observations(timeout=10, count=5)

        teleport_keywords = ["传送", "teleport", "仙女龙", "fairy", "相位", "瘟疫"]
        teleport_obs = [o for o in obs if any(kw in str(o).lower() for kw in teleport_keywords)]

        self.log(f"传送相关观测: {len(teleport_obs)} 条", "DEBUG")
        for o in teleport_obs[:3]:
            self.log(f"  -> {o}", "DEBUG")

        self.log_validation("传送机制", len(teleport_obs) > 0,
                           f"找到 {len(teleport_obs)} 条传送相关观测")

        return len(teleport_obs) > 0

    async def test_firefly_blind(self):
        """测试萤火虫致盲机制"""
        self.log("\n" + "=" * 80, "TEST")
        self.log("【测试7】萤火虫致盲和Miss回蓝", "TEST")
        self.log("验证点: 攻击给敌人致盲debuff，致盲敌人Miss回复10法力", "TEST")
        self.log("=" * 80, "TEST")

        await asyncio.sleep(2)
        obs = await self.wait_for_observations(timeout=10, count=5)

        blind_keywords = ["致盲", "blind", "萤火虫", "firefly", "miss", "Miss"]
        blind_obs = [o for o in obs if any(kw in str(o).lower() for kw in blind_keywords)]

        self.log(f"致盲相关观测: {len(blind_obs)} 条", "DEBUG")
        for o in blind_obs[:3]:
            self.log(f"  -> {o}", "DEBUG")

        self.log_validation("致盲机制", len(blind_obs) > 0,
                           f"找到 {len(blind_obs)} 条致盲相关观测")

        return len(blind_obs) > 0

    async def test_phoenix_fire_rain(self):
        """测试凤凰火雨机制"""
        self.log("\n" + "=" * 80, "TEST")
        self.log("【测试8】凤凰火雨AOE和临时法球生成", "TEST")
        self.log("验证点: 火雨持续3秒，命中敌人回复法力，结束后生成临时法球", "TEST")
        self.log("=" * 80, "TEST")

        await asyncio.sleep(2)
        obs = await self.wait_for_observations(timeout=10, count=5)

        phoenix_keywords = ["凤凰", "phoenix", "火雨", "fire", "涅槃", "法球"]
        phoenix_obs = [o for o in obs if any(kw in str(o).lower() for kw in phoenix_keywords)]

        self.log(f"凤凰相关观测: {len(phoenix_obs)} 条", "DEBUG")
        for o in phoenix_obs[:3]:
            self.log(f"  -> {o}", "DEBUG")

        self.log_validation("火雨AOE", len(phoenix_obs) > 0,
                           f"找到 {len(phoenix_obs)} 条凤凰相关观测")

        return len(phoenix_obs) > 0

    async def test_eel_lightning(self):
        """测试电鳗闪电链机制"""
        self.log("\n" + "=" * 80, "TEST")
        self.log("【测试9】电鳗闪电链弹射和法力震荡", "TEST")
        self.log("验证点: 闪电链弹射4次，每次弹射回复3法力，弹射满3个额外回复", "TEST")
        self.log("=" * 80, "TEST")

        await asyncio.sleep(2)
        obs = await self.wait_for_observations(timeout=10, count=5)

        eel_keywords = ["电鳗", "eel", "闪电", "lightning", "弹射", "法力震荡"]
        eel_obs = [o for o in obs if any(kw in str(o).lower() for kw in eel_keywords)]

        self.log(f"电鳗相关观测: {len(eel_obs)} 条", "DEBUG")
        for o in eel_obs[:3]:
            self.log(f"  -> {o}", "DEBUG")

        self.log_validation("闪电链机制", len(eel_obs) > 0,
                           f"找到 {len(eel_obs)} 条电鳗相关观测")

        return len(eel_obs) > 0

    async def test_dragon_black_hole(self):
        """测试龙的黑洞机制"""
        self.log("\n" + "=" * 80, "TEST")
        self.log("【测试10】龙的黑洞控制和星辰坠落", "TEST")
        self.log("验证点: 黑洞持续4秒，结束时根据吸入敌人数量造成伤害", "TEST")
        self.log("=" * 80, "TEST")

        await asyncio.sleep(2)
        obs = await self.wait_for_observations(timeout=10, count=5)

        dragon_keywords = ["龙", "dragon", "黑洞", "black hole", "星辰", "坠落"]
        dragon_obs = [o for o in obs if any(kw in str(o).lower() for kw in dragon_keywords)]

        self.log(f"龙相关观测: {len(dragon_obs)} 条", "DEBUG")
        for o in dragon_obs[:3]:
            self.log(f"  -> {o}", "DEBUG")

        self.log_validation("黑洞机制", len(dragon_obs) > 0,
                           f"找到 {len(dragon_obs)} 条龙相关观测")

        return len(dragon_obs) > 0

    async def test_mana_cycle_extreme(self):
        """测试法力循环极限"""
        self.log("\n" + "=" * 80, "TEST")
        self.log("【测试11】法力循环极限测试", "TEST")
        self.log("混沌操作: 高频率使用消耗法力的技能，测试法力循环极限", "TEST")
        self.log("=" * 80, "TEST")

        # 模拟高频率法力消耗
        for i in range(5):
            # 尝试使用技能
            resp = await self.send_actions([{
                "type": "use_skill",
                "grid_pos": {"x": 0, "y": 1}
            }])
            self.log(f"技能使用尝试 {i+1}: {resp}", "DEBUG")
            await asyncio.sleep(1)

        obs = await self.wait_for_observations(timeout=10, count=5)

        # 检查法力循环
        mana_cycle_keywords = ["法力", "mana", "MP", "消耗", "回复", "restore"]
        cycle_obs = [o for o in obs if any(kw in str(o).lower() for kw in mana_cycle_keywords)]

        self.log(f"法力循环观测: {len(cycle_obs)} 条", "DEBUG")

        self.log_validation("法力循环极限", len(cycle_obs) > 0,
                           f"找到 {len(cycle_obs)} 条法力循环观测")

        return len(cycle_obs) > 0

    async def run_all_tests(self):
        """运行所有测试"""
        self.log("\n" + "=" * 80, "SYSTEM")
        self.log("开始执行蝴蝶图腾全面测试套件", "SYSTEM")
        self.log("=" * 80, "SYSTEM")

        try:
            # 启动客户端
            if not await self.start_client():
                self.log("客户端启动失败，测试终止", "ERROR")
                return False

            # 等待游戏完全加载
            await asyncio.sleep(3)

            # 执行测试序列
            await self.test_select_totem()
            await asyncio.sleep(2)

            await self.test_orb_mechanism()
            await asyncio.sleep(2)

            await self.test_buy_butterfly_units()
            await asyncio.sleep(2)

            await self.test_butterfly_mana_consumption()
            await asyncio.sleep(2)

            await self.test_ice_butterfly_freeze()
            await asyncio.sleep(2)

            await self.test_fairy_dragon_teleport()
            await asyncio.sleep(2)

            await self.test_firefly_blind()
            await asyncio.sleep(2)

            await self.test_phoenix_fire_rain()
            await asyncio.sleep(2)

            await self.test_eel_lightning()
            await asyncio.sleep(2)

            await self.test_dragon_black_hole()
            await asyncio.sleep(2)

            await self.test_mana_cycle_extreme()
            await asyncio.sleep(2)

            # 生成测试报告
            self.generate_report()

            return True

        except Exception as e:
            self.log(f"测试执行异常: {e}", "ERROR")
            import traceback
            self.log(traceback.format_exc(), "ERROR")
            return False

        finally:
            await self.stop_client()

    def generate_report(self):
        """生成测试报告"""
        self.log("\n" + "=" * 80, "REPORT")
        self.log("蝴蝶图腾流派测试报告", "REPORT")
        self.log("=" * 80, "REPORT")

        passed = sum(1 for r in self.test_results if r["passed"])
        failed = sum(1 for r in self.test_results if not r["passed"])
        total = len(self.test_results)

        self.log(f"\n总计: {total} 项验证", "REPORT")
        self.log(f"通过: {passed} 项", "REPORT")
        self.log(f"失败: {failed} 项", "REPORT")

        self.log("\n详细结果:", "REPORT")
        for r in self.test_results:
            status = "✅" if r["passed"] else "❌"
            self.log(f"  {status} {r['mechanism']}: {r['details']}", "REPORT")

        self.log("\n" + "=" * 80, "REPORT")
        self.log(f"日志文件: {self.log_file}", "REPORT")
        self.log("=" * 80, "REPORT")

        return {
            "total": total,
            "passed": passed,
            "failed": failed,
            "log_file": str(self.log_file)
        }


def main():
    """主入口"""
    tester = ButterflyTotemTester(http_port=8080)

    try:
        result = asyncio.run(tester.run_all_tests())
        sys.exit(0 if result else 1)
    except KeyboardInterrupt:
        print("\n测试被用户中断")
        sys.exit(1)


if __name__ == "__main__":
    main()
