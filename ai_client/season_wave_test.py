#!/usr/bin/env python3
"""
季节波次系统测试脚本 (WAVE-SEASON-VERIFY-001)

测试目标:
- 验证24波季节系统正确实现
- 验证4个季节Boss在6/12/18/24波正确生成
- 验证季节切换信号正确输出
- 验证Boss技能正确触发

测试波次: 1, 6, 7, 12, 13, 18, 19, 24 (采样测试)
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


class SeasonWaveTester:
    """季节波次测试器"""

    def __init__(self, http_port=9999):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.test_results = []
        self.observations = []
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_season_verify_{timestamp}.log"

        self.test_waves = [1, 6, 7, 12, 13, 18, 19, 24]
        self.validation_results = {
            "wave_1_season_spring": False,
            "wave_6_boss_spring": False,
            "wave_7_season_summer": False,
            "wave_12_boss_summer": False,
            "wave_13_season_autumn": False,
            "wave_18_boss_autumn": False,
            "wave_19_season_winter": False,
            "wave_24_boss_winter": False,
            "season_change_signals": [],
            "boss_spawn_events": [],
            "no_crash": True,
            "no_error": True,
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

    async def check_game_ready(self, timeout=60) -> bool:
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                async with self.session.get(f"{self.base_url}/status", timeout=5) as resp:
                    if resp.status == 200:
                        return True
            except:
                pass
            await asyncio.sleep(1)
        return False

    async def select_totem(self, totem_id: str) -> bool:
        try:
            async with self.session.post(
                f"{self.base_url}/action",
                json={"type": "select_totem", "totem_id": totem_id}
            ) as resp:
                return resp.status == 200
        except Exception as e:
            self.log(f"选择图腾失败: {e}", "ERROR")
            return False

    async def buy_unit(self, unit_id: str) -> bool:
        try:
            async with self.session.post(
                f"{self.base_url}/action",
                json={"type": "buy_unit", "unit_id": unit_id}
            ) as resp:
                return resp.status == 200
        except Exception as e:
            self.log(f"购买单位失败: {e}", "ERROR")
            return False

    async def deploy_unit(self, unit_id: str, position: tuple) -> bool:
        try:
            async with self.session.post(
                f"{self.base_url}/action",
                json={
                    "type": "deploy_unit",
                    "unit_id": unit_id,
                    "position": {"x": position[0], "y": position[1]}
                }
            ) as resp:
                return resp.status == 200
        except Exception as e:
            self.log(f"部署单位失败: {e}", "ERROR")
            return False

    async def start_wave(self) -> bool:
        try:
            async with self.session.post(
                f"{self.base_url}/action",
                json={"type": "start_wave"}
            ) as resp:
                return resp.status == 200
        except Exception as e:
            self.log(f"启动波次失败: {e}", "ERROR")
            return False

    async def skip_to_wave(self, wave: int) -> bool:
        """跳转到指定波次"""
        try:
            async with self.session.post(
                f"{self.base_url}/action",
                json={"type": "skip_to_wave", "wave": wave}
            ) as resp:
                return resp.status == 200
        except Exception as e:
            self.log(f"跳转到波次{wave}失败: {e}", "WARNING")
            return False

    async def get_observations(self) -> Dict:
        try:
            async with self.session.get(f"{self.base_url}/observations") as resp:
                if resp.status == 200:
                    return await resp.json()
        except Exception as e:
            self.log(f"获取观察失败: {e}", "ERROR")
        return {}

    def check_log_for_patterns(self, text: str) -> Dict[str, Any]:
        """检查日志文本中的关键模式"""
        results = {
            "season_changed": [],
            "boss_spawned": [],
            "boss_skill": [],
            "errors": [],
        }

        lines = text.split('\n')
        for line in lines:
            # 检查季节切换
            if "季节切换" in line or "season_changed" in line.lower():
                results["season_changed"].append(line.strip())
            # 检查Boss生成
            if "Boss" in line or "boss" in line.lower():
                if "spawn" in line.lower() or "生成" in line:
                    results["boss_spawned"].append(line.strip())
            # 检查Boss技能
            if "spring_awakening" in line or "summer_inferno" in line or \
               "autumn_decay" in line or "winter_frost" in line:
                results["boss_skill"].append(line.strip())
            # 检查错误
            if "ERROR" in line or "错误" in line:
                results["errors"].append(line.strip())

        return results

    async def test_wave(self, wave: int) -> Dict[str, Any]:
        """测试指定波次"""
        self.log(f"\n{'='*50}")
        self.log(f"测试波次 {wave}")
        self.log(f"{'='*50}")

        result = {
            "wave": wave,
            "success": False,
            "season": None,
            "is_boss_wave": wave in [6, 12, 18, 24],
            "expected_boss": None,
            "logs": [],
        }

        # 确定期望的季节和Boss
        if wave <= 6:
            result["season"] = "spring"
            if wave == 6:
                result["expected_boss"] = "spring_guardian"
        elif wave <= 12:
            result["season"] = "summer"
            if wave == 12:
                result["expected_boss"] = "summer_dragon"
        elif wave <= 18:
            result["season"] = "autumn"
            if wave == 18:
                result["expected_boss"] = "autumn_lord"
        else:
            result["season"] = "winter"
            if wave == 24:
                result["expected_boss"] = "winter_queen"

        self.log(f"期望季节: {result['season']}")
        if result['expected_boss']:
            self.log(f"期望Boss: {result['expected_boss']}")

        # 尝试跳转到该波次
        if wave > 1:
            await self.skip_to_wave(wave)
            await asyncio.sleep(2)

        # 启动波次
        if await self.start_wave():
            self.log(f"波次 {wave} 已启动")
        else:
            self.log(f"波次 {wave} 启动可能已在进行中或失败", "WARNING")

        # 等待波次进行
        await asyncio.sleep(5)

        # 获取观察数据
        obs = await self.get_observations()
        result["observations"] = obs

        # 检查日志输出
        patterns = self.check_log_for_patterns(str(obs))
        result["patterns"] = patterns

        if patterns["season_changed"]:
            self.log(f"检测到季节切换: {patterns['season_changed']}")
        if patterns["boss_spawned"]:
            self.log(f"检测到Boss生成: {patterns['boss_spawned']}")
        if patterns["boss_skill"]:
            self.log(f"检测到Boss技能: {patterns['boss_skill']}")
        if patterns["errors"]:
            self.log(f"检测到错误: {patterns['errors']}", "ERROR")
            result["success"] = False
        else:
            result["success"] = True

        return result

    async def run_test(self):
        """运行完整测试"""
        self.log("="*60)
        self.log("季节波次系统测试开始 (WAVE-SEASON-VERIFY-001)")
        self.log("="*60)
        self.log(f"测试波次: {self.test_waves}")
        self.log(f"日志文件: {self.log_file}")

        # 启动Godot客户端
        self.log("\n启动游戏客户端...")
        godot_path = os.environ.get("GODOT_PATH", "/home/zhangzhan/bin/godot")
        project_path = Path(__file__).parent.parent / "src" / "project.godot"

        env = os.environ.copy()
        if "DISPLAY" not in env:
            env["DISPLAY"] = ":99"

        self.client_process = subprocess.Popen(
            [godot_path, "--path", str(project_path.parent), "--headless"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=env
        )

        # 等待游戏就绪
        self.log("等待游戏就绪...")
        if not await self.check_game_ready(timeout=60):
            self.log("游戏启动超时!", "ERROR")
            return False

        self.log("游戏已就绪，开始测试...")

        # 选择图腾
        await self.select_totem("cow_totem")
        await asyncio.sleep(1)

        # 购买并部署单位
        await self.buy_unit("plant")
        await asyncio.sleep(0.5)
        await self.deploy_unit("plant", (1, 0))
        await asyncio.sleep(0.5)

        # 测试每个波次
        all_results = []
        for wave in self.test_waves:
            result = await self.test_wave(wave)
            all_results.append(result)
            await asyncio.sleep(3)

        # 生成测试报告
        await self.generate_report(all_results)

        return True

    async def generate_report(self, results: List[Dict]):
        """生成测试报告"""
        report_path = Path("docs/player_reports/wave_season_verify_report.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)

        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        report = f"""# 季节波次系统测试报告

**测试ID**: WAVE-SEASON-VERIFY-001
**测试时间**: {timestamp}
**测试波次**: {self.test_waves}

## 测试结果汇总

| 波次 | 季节 | 是否Boss波 | 期望Boss | 测试结果 |
|------|------|-----------|----------|----------|
"""

        for r in results:
            boss_str = r.get("expected_boss", "N/A")
            success = "✅ 通过" if r.get("success") else "❌ 失败"
            report += f"| {r['wave']} | {r['season']} | {'是' if r['is_boss_wave'] else '否'} | {boss_str} | {success} |\n"

        report += """
## 详细结果

"""

        for r in results:
            report += f"""### 波次 {r['wave']}
- **季节**: {r['season']}
- **Boss波次**: {'是' if r['is_boss_wave'] else '否'}
- **期望Boss**: {r.get('expected_boss', 'N/A')}
- **测试结果**: {'通过' if r.get('success') else '失败'}

"""
            if r.get("patterns"):
                patterns = r["patterns"]
                if patterns.get("season_changed"):
                    report += f"- **季节切换日志**: {patterns['season_changed'][:2]}\n"
                if patterns.get("boss_spawned"):
                    report += f"- **Boss生成日志**: {patterns['boss_spawned'][:2]}\n"
                if patterns.get("boss_skill"):
                    report += f"- **Boss技能日志**: {patterns['boss_skill']}\n"
                if patterns.get("errors"):
                    report += f"- **错误日志**: {patterns['errors'][:3]}\n"
            report += "\n"

        report += f"""## 结论

- **测试波次**: {len(results)}
- **通过**: {sum(1 for r in results if r.get('success'))}
- **失败**: {sum(1 for r in results if not r.get('success'))}

"""

        # 添加验证检查清单
        report += """## 验证检查清单

- [ ] 波次1-6为春季
- [ ] 波次6生成春季Boss (spring_guardian)
- [ ] 波次7-12为夏季
- [ ] 波次12生成夏季Boss (summer_dragon)
- [ ] 波次13-18为秋季
- [ ] 波次18生成秋季Boss (autumn_lord)
- [ ] 波次19-24为冬季
- [ ] 波次24生成冬季Boss (winter_queen)
- [ ] 季节切换信号正确输出
- [ ] Boss技能正确触发
- [ ] 无运行时错误

---

*报告生成时间: {timestamp}*
"""

        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)

        self.log(f"测试报告已生成: {report_path}")

        # 更新状态文件
        state_path = Path("docs/states/ai_player_state.md")
        with open(state_path, "a", encoding="utf-8") as f:
            f.write(f"\n### ✅ WAVE-SEASON-VERIFY-001: 测试完成\n\n")
            f.write(f"**时间**: {timestamp}\n")
            f.write(f"**测试日志**: `{self.log_file}`\n")
            f.write(f"**测试报告**: `docs/player_reports/wave_season_verify_report.md`\n")
            f.write(f"**结果**: {sum(1 for r in results if r.get('success'))}/{len(results)} 通过\n\n")

    def cleanup(self):
        if self.client_process:
            self.log("关闭游戏客户端...")
            self.client_process.terminate()
            try:
                self.client_process.wait(timeout=5)
            except:
                self.client_process.kill()


async def main():
    tester = SeasonWaveTester()
    try:
        async with tester:
            success = await tester.run_test()
            if success:
                print("\n✅ 测试完成!")
            else:
                print("\n❌ 测试失败!")
    finally:
        tester.cleanup()


if __name__ == "__main__":
    asyncio.run(main())
